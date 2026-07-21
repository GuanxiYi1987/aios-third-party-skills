# Laplace 智能招聘 · 开放平台 API skill

> 通过 Laplace 招聘**开放平台 API**（`/open/v1/*`）操作招聘全流程：职位、候选人、简历同步/导入/上传兜底、评分、待办、笔试、AI 面试、邮件（MCP handoff / 直发）、候选人决策。

**主文档**：见 [`SKILL.md`](SKILL.md)（完整命令 + API 说明）。
**用法**：`python scripts/laplace_recruitment.py <capabilities|get|post ...>`，需配 `LAPLACE_RECRUITMENT_BASE_URL` + `LAPLACE_RECRUITMENT_API_KEY`。
**守门**：只调 `/open/v1/*`；API key 从 env 读、只 mask 不明文。

## 归档信息
版本/上线/客户见 [`meta.yaml`](meta.yaml)，历史见 [`CHANGELOG.md`](CHANGELOG.md)。🟡 版本/上线日/owner 待确认。
