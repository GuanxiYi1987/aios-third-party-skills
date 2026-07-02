#!/usr/bin/env python3
"""arXiv 官方 API 客户端：search / get 两个子命令，输出 JSON。

API: https://export.arxiv.org/api/query (Atom 1.0)
官方礼仪：请求间隔 >= 3 秒；单次 max_results 建议 <= 100。
零第三方依赖：仅 python3 标准库。
"""

import argparse
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

API = "https://export.arxiv.org/api/query"
UA = "aios-arxiv-paper-search/1.0 (AgenticOS research agent)"
MAX_RESULTS_CAP = 100
THROTTLE_SECONDS = 3

NS = {
    "atom": "http://www.w3.org/2005/Atom",
    "opensearch": "http://a9.com/-/spec/opensearch/1.1/",
    "arxiv": "http://arxiv.org/schemas/atom",
}

_last_request_at = 0.0


def _throttled_get(params):
    global _last_request_at
    wait = THROTTLE_SECONDS - (time.monotonic() - _last_request_at)
    if wait > 0:
        time.sleep(wait)
    url = API + "?" + urllib.parse.urlencode(params)
    request = urllib.request.Request(url, headers={"User-Agent": UA})
    for attempt in (1, 2):
        try:
            with urllib.request.urlopen(request, timeout=30) as resp:
                _last_request_at = time.monotonic()
                return resp.read().decode("utf-8")
        except Exception:  # noqa: BLE001 - 重试一次后原样上抛
            if attempt == 2:
                raise
            time.sleep(5)


def _text(entry, tag, ns="atom"):
    node = entry.find(f"{ns}:{tag}", NS)
    return node.text.strip() if node is not None and node.text else ""


def _parse_feed(xml_text):
    root = ET.fromstring(xml_text)
    total_node = root.find("opensearch:totalResults", NS)
    total = int(total_node.text) if total_node is not None else 0

    papers = []
    for entry in root.findall("atom:entry", NS):
        abs_url = _text(entry, "id")
        arxiv_id = abs_url.rsplit("/abs/", 1)[-1] if "/abs/" in abs_url else abs_url
        pdf_url = ""
        for link in entry.findall("atom:link", NS):
            if link.get("title") == "pdf" or link.get("type") == "application/pdf":
                pdf_url = link.get("href", "")
        primary = entry.find("arxiv:primary_category", NS)
        papers.append({
            "id": arxiv_id,
            "title": " ".join(_text(entry, "title").split()),
            "authors": [
                _text(author, "name")
                for author in entry.findall("atom:author", NS)
            ],
            "summary": " ".join(_text(entry, "summary").split()),
            "published": _text(entry, "published"),
            "updated": _text(entry, "updated"),
            "categories": [c.get("term", "") for c in entry.findall("atom:category", NS)],
            "primary_category": primary.get("term", "") if primary is not None else "",
            "abs_url": abs_url,
            "pdf_url": pdf_url or (abs_url.replace("/abs/", "/pdf/") if "/abs/" in abs_url else ""),
        })
    return {"total": total, "returned": len(papers), "papers": papers}


def cmd_search(args):
    query = args.query.strip()
    if not any(f"{field}:" in query for field in ("all", "ti", "abs", "au", "cat", "co", "jr", "rn", "id")):
        query = f'all:"{query}"' if " " in query else f"all:{query}"
    if args.category:
        query = f"({query}) AND cat:{args.category}"
    params = {
        "search_query": query,
        "start": args.start,
        "max_results": min(args.max, MAX_RESULTS_CAP),
        "sortBy": args.sort,
        "sortOrder": args.order,
    }
    return _parse_feed(_throttled_get(params))


def cmd_get(args):
    ids = [i.strip() for i in args.ids.split(",") if i.strip()]
    params = {"id_list": ",".join(ids), "max_results": len(ids)}
    return _parse_feed(_throttled_get(params))


def main():
    parser = argparse.ArgumentParser(description="arXiv official API client")
    sub = parser.add_subparsers(dest="command", required=True)

    p_search = sub.add_parser("search", help="keyword search")
    p_search.add_argument("--query", required=True)
    p_search.add_argument("--category", default="")
    p_search.add_argument("--start", type=int, default=0)
    p_search.add_argument("--max", type=int, default=20)
    p_search.add_argument("--sort", default="submittedDate",
                          choices=["submittedDate", "relevance", "lastUpdatedDate"])
    p_search.add_argument("--order", default="descending",
                          choices=["descending", "ascending"])
    p_search.set_defaults(func=cmd_search)

    p_get = sub.add_parser("get", help="fetch papers by arXiv id list")
    p_get.add_argument("--ids", required=True, help="comma-separated arXiv ids")
    p_get.set_defaults(func=cmd_get)

    args = parser.parse_args()
    try:
        result = args.func(args)
    except Exception as exc:  # noqa: BLE001
        print(json.dumps({"error": str(exc)}, ensure_ascii=False), file=sys.stderr)
        sys.exit(1)
    json.dump(result, sys.stdout, ensure_ascii=False, indent=2)
    print()


if __name__ == "__main__":
    main()
