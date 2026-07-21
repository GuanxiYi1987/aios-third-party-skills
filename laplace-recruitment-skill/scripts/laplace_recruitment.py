import argparse
import json
import mimetypes
import os
import sys
import uuid
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


class ConfigError(RuntimeError):
    pass


class ApiError(RuntimeError):
    pass


OPEN_API_PREFIX = "/open/v1/"
HTTP_COMMANDS = {"get", "post", "patch", "multipart"}
WRITE_COMMANDS = {"post", "patch", "multipart"}
CONFIRMATION_COMMANDS = WRITE_COMMANDS | {"prepare-email-mcp-handoff"}
EMAIL_MCP_LINK_TYPES = {"written_test", "ai_interview"}


def mask_api_key(value):
    if not value:
        return "<missing>"
    if value.startswith("lap_sk_"):
        return "lap_sk_****"
    return "****"


def format_error(message, env=os.environ):
    api_key = env.get("LAPLACE_RECRUITMENT_API_KEY") or ""
    return message.replace(api_key, mask_api_key(api_key)) if api_key else message


# 生产环境包:后端 API 地址已内置,用户无需填写。
# 生产包改这一行(或用 LAPLACE_RECRUITMENT_BASE_URL 环境变量覆盖)。
DEFAULT_BASE_URL = "https://laplace-recruitment-api.laplacelab.cn"


def load_config(env=os.environ):
    base_url = (env.get("LAPLACE_RECRUITMENT_BASE_URL") or DEFAULT_BASE_URL).strip()
    api_key = (env.get("LAPLACE_RECRUITMENT_API_KEY") or "").strip()
    if not api_key:
        raise ConfigError(
            "还差最后一步就能开始:请提供一个 API Key。\n"
            "在招聘系统里打开「开放平台」→「API Key」→ 点「创建 Key」→ 复制生成的、"
            "以 lap_sk_ 开头的那串密钥,发给我即可(生产环境地址已内置,你不用管)。"
        )
    return base_url.rstrip("/"), api_key


def parse_pairs(values):
    result = {}
    for item in values or []:
        if "=" not in item:
            raise ConfigError(f"Expected key=value, got {item!r}")
        key, value = item.split("=", 1)
        result[key] = value
    return result


def normalize_open_path(path):
    value = "/" + path.lstrip("/")
    if not value.startswith(OPEN_API_PREFIX):
        raise ConfigError("Only /open/v1/* paths are allowed")
    return value


def endpoint_matches(method, path, endpoint):
    template = endpoint.get("path") if isinstance(endpoint, dict) else None
    if not template or endpoint.get("method", "").upper() != method.upper():
        return False
    target = normalize_open_path(path).strip("/").split("/")
    template_parts = normalize_open_path(template).strip("/").split("/")
    if len(target) != len(template_parts):
        return False
    return all(
        actual == expected or (expected.startswith("{") and expected.endswith("}"))
        for actual, expected in zip(target, template_parts)
    )


def endpoint_available(method, path, endpoints):
    return any(endpoint_matches(method, path, endpoint) for endpoint in endpoints or [])


def prepare_email_mcp_handoff(
    scenario,
    candidate_name,
    candidate_email,
    job_title,
    company_name,
    link_type,
    link_url,
    link_expires_at=None,
    context=None,
):
    required = {
        "scenario": scenario,
        "candidate_name": candidate_name,
        "candidate_email": candidate_email,
        "job_title": job_title,
        "company_name": company_name,
        "link_type": link_type,
        "link_url": link_url,
        "context": context,
    }
    missing = [name for name, value in required.items() if not str(value or "").strip()]
    if missing:
        raise ConfigError(f"Missing required handoff fields: {', '.join(missing)}")
    if link_type not in EMAIL_MCP_LINK_TYPES:
        allowed = ", ".join(sorted(EMAIL_MCP_LINK_TYPES))
        raise ConfigError(f"link_type must be one of: {allowed}")

    payload = {
        "scenario": scenario,
        "candidateName": candidate_name,
        "candidateEmail": candidate_email,
        "jobTitle": job_title,
        "companyName": company_name,
        "linkType": link_type,
        "linkUrl": link_url,
    }
    if link_expires_at:
        payload["linkExpiresAt"] = link_expires_at
    if context:
        payload["context"] = context
    return payload


class LaplaceRecruitmentClient:
    def __init__(self, base_url, api_key):
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key

    def request(self, method, path, query=None, json_body=None):
        data = None
        headers = self._headers()
        if json_body is not None:
            data = json.dumps(json_body, ensure_ascii=False).encode("utf-8")
            headers["Content-Type"] = "application/json"
        return self._send(method, path, query, data, headers)

    def multipart(self, path, fields=None, files=None, query=None):
        boundary = f"----laplace-{uuid.uuid4().hex}"
        body = self._multipart_body(boundary, fields or {}, files or {})
        headers = self._headers()
        headers["Content-Type"] = f"multipart/form-data; boundary={boundary}"
        return self._send("POST", path, query, body, headers)

    def capabilities(self):
        return self.request("GET", "/open/v1/capabilities")

    def ensure_endpoint_available(self, method, path):
        capabilities = self.capabilities()
        endpoints = capabilities.get("endpoints", []) if isinstance(capabilities, dict) else []
        if not endpoint_available(method, path, endpoints):
            raise ConfigError(f"Endpoint not available for API key: {method.upper()} {normalize_open_path(path)}")

    def _headers(self):
        return {"Authorization": f"Bearer {self.api_key}", "Accept": "application/json"}

    def _url(self, path, query=None):
        suffix = normalize_open_path(path)
        url = self.base_url + suffix
        if query:
            url += "?" + urlencode(query)
        return url

    def _send(self, method, path, query, data, headers):
        request = Request(self._url(path, query), data=data, headers=headers, method=method.upper())
        try:
            with urlopen(request, timeout=30) as response:
                return self._parse_response(response.read())
        except HTTPError as exc:
            message = exc.read().decode("utf-8", errors="replace")
            raise ApiError(f"HTTP {exc.code}: {message}") from exc
        except URLError as exc:
            raise ApiError(str(exc.reason)) from exc

    def _parse_response(self, data):
        text = data.decode("utf-8", errors="replace")
        payload = json.loads(text) if text else {}
        if isinstance(payload, dict) and payload.get("code") == 0 and "data" in payload:
            return payload["data"]
        return payload

    def _multipart_body(self, boundary, fields, files):
        chunks = []
        boundary_bytes = boundary.encode("ascii")
        for name, value in fields.items():
            chunks.extend(
                [
                    b"--" + boundary_bytes,
                    f'Content-Disposition: form-data; name="{name}"'.encode("utf-8"),
                    b"",
                    str(value).encode("utf-8"),
                ]
            )
        for name, filename in files.items():
            path = Path(filename)
            content_type = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
            chunks.extend(
                [
                    b"--" + boundary_bytes,
                    f'Content-Disposition: form-data; name="{name}"; filename="{path.name}"'.encode("utf-8"),
                    f"Content-Type: {content_type}".encode("ascii"),
                    b"",
                    path.read_bytes(),
                ]
            )
        chunks.append(b"--" + boundary_bytes + b"--")
        chunks.append(b"")
        return b"\r\n".join(chunks)


def build_parser():
    parser = argparse.ArgumentParser(description="Call Laplace Recruitment open-platform APIs.")
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("capabilities")
    for name, method in (("get", "GET"), ("post", "POST"), ("patch", "PATCH")):
        command = subparsers.add_parser(name)
        command.set_defaults(method=method)
        command.add_argument("path")
        command.add_argument("--query", action="append", default=[])
        command.add_argument("--json", default=None)
        if name in WRITE_COMMANDS:
            command.add_argument("--confirmed", action="store_true")
    multipart = subparsers.add_parser("multipart")
    multipart.add_argument("path")
    multipart.add_argument("--query", action="append", default=[])
    multipart.add_argument("--field", action="append", default=[])
    multipart.add_argument("--file", action="append", default=[])
    multipart.add_argument("--confirmed", action="store_true")
    handoff = subparsers.add_parser("prepare-email-mcp-handoff")
    handoff.add_argument("--scenario", required=True)
    handoff.add_argument("--candidate-name", required=True)
    handoff.add_argument("--candidate-email", required=True)
    handoff.add_argument("--job-title", required=True)
    handoff.add_argument("--company-name", required=True)
    handoff.add_argument("--link-type", required=True, choices=sorted(EMAIL_MCP_LINK_TYPES))
    handoff.add_argument("--link-url", required=True)
    handoff.add_argument("--link-expires-at", default=None)
    handoff.add_argument("--context", required=True)
    handoff.add_argument("--confirmed", action="store_true")
    return parser


def main(argv=None, env=os.environ):
    args = build_parser().parse_args(argv)
    if args.command in HTTP_COMMANDS:
        normalize_open_path(args.path)
    if args.command in CONFIRMATION_COMMANDS and not args.confirmed:
        raise ConfigError("Write command requires --confirmed after user confirmation")
    if args.command == "prepare-email-mcp-handoff":
        result = prepare_email_mcp_handoff(
            args.scenario,
            args.candidate_name,
            args.candidate_email,
            args.job_title,
            args.company_name,
            args.link_type,
            args.link_url,
            args.link_expires_at,
            args.context,
        )
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0
    base_url, api_key = load_config(env)
    client = LaplaceRecruitmentClient(base_url, api_key)
    if args.command == "capabilities":
        result = client.capabilities()
    elif args.command == "multipart":
        client.ensure_endpoint_available("POST", args.path)
        result = client.multipart(args.path, parse_pairs(args.field), parse_pairs(args.file), parse_pairs(args.query))
    else:
        client.ensure_endpoint_available(args.method, args.path)
        payload = json.loads(args.json) if args.json else None
        result = client.request(args.method, args.path, parse_pairs(args.query), payload)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ConfigError, ApiError, json.JSONDecodeError) as exc:
        print(format_error(str(exc)), file=sys.stderr)
        raise SystemExit(2)
