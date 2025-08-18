# lambda_sources/handlers.py
# Python 3.12 runtime, no external deps required.
import os, json, base64, time, hmac, hashlib, logging, urllib.request, urllib.error, urllib.parse
from datetime import datetime, timezone
import boto3
from botocore.exceptions import ClientError

log = logging.getLogger()
log.setLevel(logging.INFO)

# --- ENV ---
OPENAI_SECRET_NAME = os.getenv("OPENAI_SECRET_NAME", "chet/openai/api_key")
DATA_BUCKET         = os.getenv("DATA_BUCKET")
BACKUP_BUCKET       = os.getenv("BACKUP_BUCKET")
META_TABLE          = os.getenv("META_TABLE")
PROMPTS_TABLE       = os.getenv("PROMPTS_TABLE")
KMS_KEY_ID          = os.getenv("KMS_KEY_ID")

# --- AWS clients (reused across invocations) ---
sm   = boto3.client("secretsmanager")
s3   = boto3.client("s3")
ddb  = boto3.client("dynamodb")

# cache the OpenAI API key for this warm runtime
_cached_openai_key = None

def _ok(body: dict, status=200, headers=None):
    h = {"content-type": "application/json", "access-control-allow-origin": "*"}
    if headers:
        h.update(headers)
    return {"statusCode": status, "headers": h, "body": json.dumps(body)}

def _bad(msg: str, status=400):
    return _ok({"ok": False, "error": msg}, status=status)

def _get_openai_api_key():
    global _cached_openai_key
    if _cached_openai_key:
        return _cached_openai_key
    try:
        resp = sm.get_secret_value(SecretId=OPENAI_SECRET_NAME)
        secret = resp.get("SecretString") or base64.b64decode(resp["SecretBinary"]).decode()
        key = json.loads(secret)["api_key"]
        _cached_openai_key = key
        return key
    except Exception as e:
        log.exception("Fetching OpenAI secret failed")
        raise

def _http(url: str, method="POST", headers=None, data=None, timeout=20):
    req = urllib.request.Request(url, method=method)
    if headers:
        for k, v in headers.items(): req.add_header(k, v)
    payload = None
    if data is not None:
        payload = json.dumps(data).encode("utf-8")
        if "content-type" not in {k.lower(): v for k, v in (headers or {}).items()}:
            req.add_header("content-type", "application/json")
    try:
        with urllib.request.urlopen(req, payload, timeout=timeout) as r:
            return json.loads(r.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "ignore")
        log.error("HTTP %s %s failed: %s %s", method, url, e.code, body)
        raise

# =========================
# 1) /auth/ephemeral (rt_handler): mint ephemeral Realtime token
# =========================
def rt_handler(event, context):
    """
    Request body (optional):
      { "model": "gpt-4o-realtime-preview", "voice": "verse", "expires_in": 3600 }
    Returns:
      { ok: true, client_secret: { value: "<ephemeral>", expires_at: "..."} }
    """
    try:
        body = json.loads(event.get("body") or "{}")
    except Exception:
        return _bad("Invalid JSON")

    model      = body.get("model", "gpt-4o-realtime-preview")
    voice      = body.get("voice", "verse")
    expires_in = int(body.get("expires_in", 600))  # short-lived for browsers

    api_key = _get_openai_api_key()
    # OpenAI Realtime Sessions: POST /v1/realtime/sessions with Bearer API key
    # Response includes `client_secret.value` (the ephemeral token).
    url = "https://api.openai.com/v1/realtime/sessions"
    payload = {
        "model": model,
        "voice": voice,
        "expires_in": expires_in
    }

    res = _http(
        url,
        method="POST",
        headers={"authorization": f"Bearer {api_key}"},
        data=payload
    )
    # Pass through only what browser needs
    client_secret = res.get("client_secret") or {}
    out = {
        "ok": True,
        "client_secret": {
            "value": client_secret.get("value"),
            "expires_at": client_secret.get("expires_at")
        }
    }
    return _ok(out)

# =========================
# 2) /ai/* (ai_handler): generate tasks/notes, auto-tag, summarize
# =========================
# OpenAI Responses API w/ Structured Outputs (JSON Schema)
OPENAI_CHAT_URL = "https://api.openai.com/v1/chat/completions"   # compatible with schema format
DEFAULT_MODEL    = "gpt-4o-mini"

TASK_SCHEMA = {
    "name": "task_batch",
    "schema": {
        "type": "object",
        "additionalProperties": False,
        "properties": {
            "tasks": {
                "type": "array",
                "items": {
                    "type": "object",
                    "additionalProperties": False,
                    "properties": {
                        "title": {"type": "string"},
                        "notes": {"type": "string"},
                        "due": {"type": "string", "description": "ISO8601 date or datetime when explicit; else omit"},
                        "priority": {"type": "string", "enum": ["low","normal","high"]},
                        "tags": {"type": "array", "items": {"type": "string"}, "maxItems": 5}
                    },
                    "required": ["title"]
                }
            }
        },
        "required": ["tasks"]
    }
}

TAGS_SCHEMA = {
    "name": "tags",
    "schema": {
        "type":"object",
        "additionalProperties": False,
        "properties":{
            "tags":{"type":"array","items":{"type":"string"},"maxItems":8}
        },
        "required":["tags"]
    }
}

NOTE_SCHEMA = {
    "name": "note",
    "schema": {
        "type": "object",
        "additionalProperties": False,
        "properties": {
            "title": {"type": "string"},
            "body": {"type": "string"},
            "tags": {"type":"array","items":{"type":"string"},"maxItems":8}
        },
        "required": ["body"]
    }
}

def _openai_structured(prompt: str, schema: dict, system: str):
    api_key = _get_openai_api_key()
    payload = {
        "model": DEFAULT_MODEL,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": prompt},
        ],
        "response_format": {
            "type": "json_schema",
            "json_schema": {
                # move strict INTO json_schema (fixes 400)
                "strict": True,
                **schema,  # expects keys: name, schema
            },
        },
        "temperature": 0.2,
    }
    res = _http(
        OPENAI_CHAT_URL,
        method="POST",
        headers={"authorization": f"Bearer {api_key}"},
        data=payload,
    )
    content = res["choices"][0]["message"]["content"]
    return json.loads(content)

def ai_handler(event, context):
    """
    Routes:
      POST /ai/generate_tasks   { text: "..." }
      POST /ai/generate_note    { text: "..." }
      POST /ai/auto_tags        { text: "..." }
      POST /ai/summarize        { text: "..." }  -> returns { summary: "..." }
    """
    route = (event.get("rawPath") or "").lower()
    try:
        body = json.loads(event.get("body") or "{}")
    except Exception:
        return _bad("Invalid JSON")

    text = body.get("text","").strip()
    if not text:
        return _bad("Field 'text' is required")

    if route.endswith("/generate_tasks"):
        system = (
            "You are Chet, a precise task generator. "
            "Extract atomic to-dos from the user's text. Only infer due dates when explicit in text. "
            "Use existing tags when obvious; keep tags few (<=5)."
        )
        out = _openai_structured(text, TASK_SCHEMA, system)
        return _ok({"ok": True, **out})

    if route.endswith("/generate_note"):
        system = (
            "You are Chet, a concise note creator. Produce one note with optional title and compact tags. "
            "Preserve key details verbatim where appropriate."
        )
        out = _openai_structured(text, NOTE_SCHEMA, system)
        return _ok({"ok": True, **out})

    if route.endswith("/auto_tags"):
        system = (
            "You are Chet, a tag extractor. Return 1-8 short, reusable tags. "
            "Prefer existing tag vocab if obvious; avoid duplicates or synonyms."
        )
        out = _openai_structured(text, TAGS_SCHEMA, system)
        return _ok({"ok": True, **out})

    if route.endswith("/summarize"):
        api_key = _get_openai_api_key()
        payload = {
            "model": DEFAULT_MODEL,
            "messages": [
                {"role":"system","content":"Summarize succinctly for a to-do/notes app user."},
                {"role":"user","content":text}
            ],
            "temperature": 0.3
        }
        res = _http(
            OPENAI_CHAT_URL,
            method="POST",
            headers={"authorization": f"Bearer {api_key}"},
            data=payload
        )
        summary = res["choices"][0]["message"]["content"]
        return _ok({"ok": True, "summary": summary})

    return _bad("Unknown /ai route", 404)

# =========================
# 3) /sync/* (sync_handler): presigned URLs + basic metadata index
# =========================
# Strategy: client keeps local-first DB; periodically uploads encrypted snapshots (JSON blobs).
# Endpoints:
#   POST /sync/upload_url   { key: "user-<uid>/snapshots/<ts>.json" , content_type:"application/json" }
#   POST /sync/download_url { key: "user-<uid>/snapshots/<file>.json" }
#   POST /sync/list         { prefix: "user-<uid>/snapshots/" }
def sync_handler(event, context):
    try:
        body = json.loads(event.get("body") or "{}")
    except Exception:
        return _bad("Invalid JSON")

    raw_path = (event.get("rawPath") or "").lower()
    if not DATA_BUCKET:
        return _bad("DATA_BUCKET not configured", 500)

    if raw_path.endswith("/upload_url"):
        key = body.get("key")
        ctype = body.get("content_type", "application/json")
        if not key:
            return _bad("key required")
        try:
            url = s3.generate_presigned_url(
                ClientMethod="put_object",
                Params={
                    "Bucket": DATA_BUCKET,
                    "Key": key,
                    "ContentType": ctype,
                    "ServerSideEncryption": "aws:kms",
                    "SSEKMSKeyId": KMS_KEY_ID
                },
                ExpiresIn=3600
            )
            return _ok({"ok": True, "url": url, "key": key})
        except Exception as e:
            log.exception("presign put failed")
            return _bad(str(e), 500)

    if raw_path.endswith("/download_url"):
        key = body.get("key")
        if not key:
            return _bad("key required")
        try:
            url = s3.generate_presigned_url(
                ClientMethod="get_object",
                Params={"Bucket": DATA_BUCKET, "Key": key},
                ExpiresIn=3600
            )
            return _ok({"ok": True, "url": url, "key": key})
        except Exception as e:
            log.exception("presign get failed")
            return _bad(str(e), 500)

    if raw_path.endswith("/list"):
        prefix = body.get("prefix", "")
        try:
            objs = []
            paginator = s3.get_paginator("list_objects_v2")
            for page in paginator.paginate(Bucket=DATA_BUCKET, Prefix=prefix):
                for item in page.get("Contents", []):
                    objs.append({
                        "key": item["Key"],
                        "size": item["Size"],
                        "etag": item["ETag"].strip('"'),
                        "last_modified": item["LastModified"].astimezone(timezone.utc).isoformat()
                    })
            return _ok({"ok": True, "objects": objs})
        except Exception as e:
            log.exception("list failed")
            return _bad(str(e), 500)

    return _bad("Unknown /sync route", 404)

# =========================
# 4) EventBridge -> daily-backup (backup_handler): copy DATA -> BACKUP
# =========================
def backup_handler(event, context):
    if not (DATA_BUCKET and BACKUP_BUCKET):
        return _bad("DATA_BUCKET or BACKUP_BUCKET not set", 500)

    copied = 0
    try:
        paginator = s3.get_paginator("list_object_versions")
        for page in paginator.paginate(Bucket=DATA_BUCKET):
            versions = page.get("Versions", [])
            for v in versions:
                key = v["Key"]
                vid = v["VersionId"]
                # copy each version into BACKUP, preserving version id in the key name
                dst_key = f"backup/{key}?versionId={vid}"
                s3.copy_object(
                    Bucket=BACKUP_BUCKET,
                    Key=dst_key,
                    CopySource={"Bucket": DATA_BUCKET, "Key": key, "VersionId": vid},
                    ServerSideEncryption="aws:kms",
                    SSEKMSKeyId=KMS_KEY_ID
                )
                copied += 1
    except ClientError as e:
        log.exception("Backup failed")
        return _bad(str(e), 500)

    return _ok({"ok": True, "copied": copied})
