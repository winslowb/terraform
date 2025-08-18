# AWS WorkMail Domain & User Bootstrap

This project automates the setup of an [Amazon WorkMail](https://aws.amazon.com/workmail/) organization with a custom domain using Route53, SES, and WorkMail APIs.  
It creates and verifies the domain, configures required DNS records, and ensures a mailbox for a given user is created and ready.

---

## Features

- Registers a mail domain in an existing WorkMail organization
- Fetches recommended DNS records from WorkMail and applies them in Route53
- Configures SES verification records
- Ensures the specified user exists with a mailbox in WorkMail
- Idempotent — can be re-run without duplicating records or users

---

## Prerequisites

- AWS CLI installed and configured with credentials (`aws configure`)
- IAM user/role with permissions:
  - `workmail:*`
  - `ses:*`
  - `route53:*`
- An existing WorkMail Organization ID (e.g. `m-4ce1cc771a784e259ebd073595b9d07a`)
- The domain (`example.com`) hosted in Route53

---

## Usage
```bash
python3 workmail.py

[init] region=us-east-1 domain=$DOMAIN
[route53] zone_id=Z09149511A5D3PHV3MYAQ
[workmail] using org: m-4ce1cc771a784e259ebd073595b9d07a
[workmail] register_mail_domain requested for $DOMAIN
[workmail] recommended DNS records from get_mail_domain: 8
[route53] upsert MX $DOMAIN -> /change/C03548783MLUGOTYWU1BK
[route53] upsert TXT $DOMAIN -> /change/C05203092REE8EI5I42NL
[route53] upsert CNAME autodiscover.$DOMAIN -> /change/C05153061C7TD9UULKYZC
[ses] identity token: AiKfWO5+lgB+0V0e1JrRWa4BTiOOi62sbnv4GFnlL0s=
[route53] upsert TXT _amazonses.$DOMAIN -> /change/C04671658L8SNNAPT2PM
[route53] upsert CNAME iwdfovkgeyngc3erplhtcc72hkjrwoio._domainkey.$DOMAIN -> /change/C03265523R8R5V27JEYJN
[workmail] user bill exists -> 43da20c7-9706-4203-b75a-d91d0ed3a42e
[workmail] mailbox already registered for bill@$DOMAIN

All set. DNS may take a few minutes. bill@$DOMAIN will be ready once verification is Active/Verified.

## Set pw
aws workmail reset-password \
  --organization-id m-4ce1cc771a784e259ebd073595b9d07a \
  --user-id 43da20c7-9706-4203-b75a-d91d0ed3a42e \
  --password 'StrongPasswordHere123!'

