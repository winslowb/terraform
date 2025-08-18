#!/usr/bin/env python3
"""
Provision Amazon WorkMail for $DOMAIN on an existing WorkMail org:
- Discover Route 53 public hosted zone by name
- Register mail domain to WorkMail (register_mail_domain)
- Create Route 53 records: MX, SPF (TXT), Autodiscover (CNAME)
- Verify SES identity + DKIM (3 CNAMEs)
- Create WorkMail user 'bill' and enable mailbox bill@$DOMAIN

Region: us-east-1
"""

import time
import sys
import random
from typing import Callable, Iterable

import boto3
from botocore.exceptions import ClientError

# ----------------------------
# Configuration
# ----------------------------
REGION = "us-east-1"
DOMAIN = "$DOMAIN"
HOSTED_ZONE_NAME = "$DOMAIN."           # will be normalized
WORKMAIL_ORG_ALIAS = "winslow"             # <-- your org alias
WORKMAIL_ORG_ID = None                     # set to e.g. "m-xxxx" to skip alias lookup

USER_NAME = "bill"
USER_DISPLAY = "Bill"
USER_PASSWORD = "SuperSecretPassw0rd!"     # must meet WorkMail policy

SPF_VALUE = "v=spf1 include:amazonses.com ~all"
AUTODISCOVER_TARGET = "autodiscover.mail.us-east-1.awsapps.com"  # region-specific

# ----------------------------
# Session/Clients
# ----------------------------
session = boto3.Session(region_name=REGION)
route53 = session.client("route53")
workmail = session.client("workmail")
ses = session.client("ses")  # SES classic for identity + DKIM


# ----------------------------
# Helpers
# ----------------------------
def backoff(fn: Callable, *args, retries: int = 7, base: float = 0.6, **kwargs):
    """Simple jittered exponential backoff wrapper."""
    for attempt in range(retries):
        try:
            return fn(*args, **kwargs)
        except ClientError as e:
            if attempt == retries - 1:
                raise
            time.sleep(base * (2 ** attempt) + random.uniform(0, 0.3))


def ensure_trailing_dot(name: str) -> str:
    return name if name.endswith(".") else f"{name}."


def ensure_txt_quotes(value: str) -> str:
    v = value.strip()
    return v if (v.startswith('"') and v.endswith('"')) else f"\"{v}\""


def find_zone_id_by_name(zone_name: str) -> str:
    """Find a public hosted zone by exact name."""
    name = ensure_trailing_dot(zone_name)
    resp = backoff(route53.list_hosted_zones_by_name, DNSName=name, MaxItems="1")
    zones = resp.get("HostedZones", [])
    if not zones or zones[0]["Name"] != name or zones[0]["Config"]["PrivateZone"]:
        raise RuntimeError(f"Public hosted zone not found for '{name}'")
    return zones[0]["Id"].split("/")[-1]


def upsert_record(zone_id: str, name: str, rtype: str, values: Iterable[str], ttl: int = 300) -> str:
    """UPSERT a simple RRSet (MX/TXT/CNAME). Values must be fully-formed strings."""
    if isinstance(values, str):
        values = [values]
    rr = [{"Value": v} for v in values]
    batch = {
        "Comment": f"UPSERT {rtype} {name}",
        "Changes": [{
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": ensure_trailing_dot(name),
                "Type": rtype,
                "TTL": ttl,
                "ResourceRecords": rr
            }
        }]
    }
    resp = backoff(route53.change_resource_record_sets, HostedZoneId=zone_id, ChangeBatch=batch)
    change_id = resp["ChangeInfo"]["Id"]
    print(f"[route53] upsert {rtype} {name} -> {change_id}")
    return change_id


def wait_change_insync(change_id: str):
    while True:
        st = backoff(route53.get_change, Id=change_id)["ChangeInfo"]["Status"]
        if st == "INSYNC":
            return
        time.sleep(2)


def find_workmail_org_id() -> str:
    if WORKMAIL_ORG_ID:
        return WORKMAIL_ORG_ID
    paginator = workmail.get_paginator("list_organizations")
    for page in paginator.paginate():
        for org in page.get("OrganizationSummaries", []):
            if org.get("Alias") == WORKMAIL_ORG_ALIAS:
                return org["OrganizationId"]
    raise RuntimeError(f"WorkMail org alias '{WORKMAIL_ORG_ALIAS}' not found in {REGION}")


def mail_domain_exists(org_id: str, domain: str) -> bool:
    """Manual pagination for list_mail_domains (no paginator exposed in boto3)."""
    next_token = None
    while True:
        kwargs = {"OrganizationId": org_id}
        if next_token:
            kwargs["NextToken"] = next_token
        resp = backoff(workmail.list_mail_domains, **kwargs)
        for d in resp.get("MailDomains", []):
            if d.get("DomainName") == domain:
                return True
        next_token = resp.get("NextToken")
        if not next_token:
            return False


def ensure_mail_domain_in_workmail(org_id: str, domain: str):
    """
    Idempotently register domain to WorkMail.
    Uses register_mail_domain; inspects with get_mail_domain/list_mail_domains.
    """
    if not mail_domain_exists(org_id, domain):
        backoff(workmail.register_mail_domain, OrganizationId=org_id, DomainName=domain)
        print(f"[workmail] register_mail_domain requested for {domain}")
    else:
        print(f"[workmail] domain {domain} already present in org {org_id}")

    # Optional: show recommended DNS records if available
    try:
        details = backoff(workmail.get_mail_domain, OrganizationId=org_id, DomainName=domain)
        recs = details.get("Records", [])
        print(f"[workmail] recommended DNS records from get_mail_domain: {len(recs)}")
    except ClientError as e:
        print(f"[workmail] get_mail_domain not available yet: {e.response.get('Error', {}).get('Message','')}")


def ensure_r53_basics(zone_id: str, domain: str):
    # MX (region-specific inbound)
    mx_val = f"10 inbound-smtp.{REGION}.amazonaws.com."
    wait_change_insync(upsert_record(zone_id, domain, "MX", mx_val))

    # SPF TXT
    wait_change_insync(upsert_record(zone_id, domain, "TXT", ensure_txt_quotes(SPF_VALUE)))

    # Autodiscover CNAME
    wait_change_insync(upsert_record(zone_id, f"autodiscover.{domain}", "CNAME", ensure_trailing_dot(AUTODISCOVER_TARGET)))


def ensure_ses_identity_and_dkim(zone_id: str, domain: str):
    # SES Identity TXT
    token = None
    try:
        vr = ses.verify_domain_identity(Domain=domain)
        token = vr.get("VerificationToken")
        print(f"[ses] identity token: {token}")
    except ClientError as e:
        code = e.response.get("Error", {}).get("Code")
        if code in ("AlreadyVerified", "AlreadyVerifiedException"):
            print("[ses] domain already verified; skipping identity TXT")
        else:
            raise

    if token:
        wait_change_insync(upsert_record(zone_id, f"_amazonses.{domain}", "TXT", ensure_txt_quotes(token)))

    # DKIM (3 tokens)
    dk = ses.verify_domain_dkim(Domain=domain)
    tokens = dk.get("DkimTokens", [])
    if not tokens:
        print("[ses] no DKIM tokens returned (domain may already have DKIM).")
    for t in tokens:
        name = f"{t}._domainkey.{domain}"
        target = f"{t}.dkim.amazonses.com."
        wait_change_insync(upsert_record(zone_id, name, "CNAME", target))


def ensure_workmail_user_and_mailbox(org_id: str, localpart: str, display: str, password: str, domain: str):
    # Find or create user
    user_id = None
    paginator = workmail.get_paginator("list_users")
    for page in paginator.paginate(OrganizationId=org_id):
        for u in page.get("Users", []):
            if u.get("Name") == localpart:
                user_id = u["Id"]
                break
        if user_id:
            break

    if not user_id:
        try:
            cu = backoff(
                workmail.create_user,
                OrganizationId=org_id,
                Name=localpart,
                DisplayName=display,
                Password=password
            )
            user_id = cu["UserId"]
            print(f"[workmail] created user {localpart} -> {user_id}")
        except ClientError as e:
            msg = e.response.get("Error", {}).get("Message", "")
            raise RuntimeError(f"Failed to create WorkMail user — {msg}") from e
    else:
        print(f"[workmail] user {localpart} exists -> {user_id}")

    # Enable mailbox / primary email
    email = f"{localpart}@{domain}"
    try:
        backoff(workmail.register_to_work_mail, OrganizationId=org_id, EntityId=user_id, Email=email)
        print(f"[workmail] mailbox enabled for {email}")
    except ClientError as e:
        code = e.response.get("Error", {}).get("Code")
        if code == "EntityAlreadyRegisteredException":
            print(f"[workmail] mailbox already registered for {email}")
        else:
            raise


def main():
    print(f"[init] region={REGION} domain={DOMAIN}")
    zone_id = find_zone_id_by_name(HOSTED_ZONE_NAME)
    print(f"[route53] zone_id={zone_id}")

    org_id = find_workmail_org_id()
    print(f"[workmail] using org: {org_id}")

    ensure_mail_domain_in_workmail(org_id, DOMAIN)
    ensure_r53_basics(zone_id, DOMAIN)
    ensure_ses_identity_and_dkim(zone_id, DOMAIN)
    ensure_workmail_user_and_mailbox(org_id, USER_NAME, USER_DISPLAY, USER_PASSWORD, DOMAIN)

    print("\nAll set. DNS may take a few minutes. bill@$DOMAIN will be ready once verification is Active/Verified.")


if __name__ == "__main__":
    try:
        main()
    except ClientError as e:
        code = e.response.get("Error", {}).get("Code")
        msg = e.response.get("Error", {}).get("Message")
        print(f"AWS error: {code}: {msg}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Unhandled error: {e}", file=sys.stderr)
        sys.exit(1)
