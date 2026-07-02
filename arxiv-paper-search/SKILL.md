---
name: arxiv-paper-search
type: capability
description: arXiv 论文检索（官方 API）：按关键词/分类检索论文、按 id 取详情，返回结构化 JSON（标题/作者/摘要/链接/分类/日期）。科研类 Agent 检索文献时使用。只读摘要元数据，不下载 PDF 原文。
version: 1.0.0
author: Guanxi Yi (third-party)
---

# arXiv 论文检索（arxiv-paper-search）

> 数据源 = **arXiv 官方 API**（`https://export.arxiv.org/api/query`，Atom 1.0/XML），本 skill 的脚本负责调用与解析，输出 JSON。
> 定位 = 纯检索工具（capability）：不含业务逻辑（每日扫描上限、推荐算法、确认流程等属于调用方的 extension/skill，不在这里）。

## 依赖与网络

- **零第三方依赖**：python3 标准库直跑，无需 pip install。
- 网络：直连 `export.arxiv.org`；环境不通时设 `HTTPS_PROXY` 环境变量即可（urllib 自动识别），代码无需改动。
- 安装自检（装完跑一次）：`python3 scripts/arxiv_client.py get --ids 1706.03762` 应返回含 "Attention Is All You Need" 的 JSON。

## 用法

### 1. 关键词检索

```bash
python3 scripts/arxiv_client.py search \
  --query "AI agent" \
  --category cs.AI \
  --max 20 \
  --sort submittedDate
```

- `--query`：检索词（arXiv 语法可直接写进去，如 `ti:"multi-agent" AND abs:planning`；纯词组会自动包成 `all:...`）
- `--category`：可选，限定分类（`cs.AI` / `cs.MA` / `cs.CL` …），与 query 用 AND 连接
- `--max`：返回条数（默认 20，上限 100）
- `--start`：分页偏移（默认 0）
- `--sort`：`submittedDate`（默认）/ `relevance` / `lastUpdatedDate`；`--order` `descending`（默认）/ `ascending`

### 2. 按 id 取详情

```bash
python3 scripts/arxiv_client.py get --ids 2501.12345,2502.00001
```

### 输出格式（两个子命令相同，stdout 一个 JSON 对象）

```json
{
  "total": 1234,
  "returned": 20,
  "papers": [
    {
      "id": "2501.12345v2",
      "title": "...",
      "authors": ["A", "B"],
      "summary": "...",
      "published": "2026-01-20T18:00:00Z",
      "updated": "2026-01-22T09:00:00Z",
      "categories": ["cs.AI", "cs.MA"],
      "primary_category": "cs.AI",
      "abs_url": "https://arxiv.org/abs/2501.12345v2",
      "pdf_url": "https://arxiv.org/pdf/2501.12345v2"
    }
  ]
}
```

## 使用纪律（arXiv 官方要求，违者会被封）

1. **请求间隔 ≥ 3 秒**——脚本内置节流，不要绕过脚本并发裸调 API。
2. **单次 max ≤ 100**；要更多用 `--start` 分页，别调大 max。
3. 只取摘要元数据；**PDF 原文下载不在本 skill 职责内**（需要全文时把 `pdf_url` 交给用户或专门流程决定）。
4. 网络异常：脚本自动重试 1 次（间隔 5s）；仍失败则原样报错退出，**调用方不要自行循环重试**。

## 边界

- 本 skill 无状态、无密钥、无写操作。
- 检索策略（查什么词、每天查几篇、怎么排序推荐）由调用方的业务 skill 决定，本 skill 不做判断。
