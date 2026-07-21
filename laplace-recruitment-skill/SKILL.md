---
name: laplace-recruitment-skill
description: "Use when operating Laplace Recruitment through its open-platform API as a scheduled, batch AI-HR: self-check/init, 30-min email resume import, daily screening/written-test/interview/conclusion/digest, todo-queue draining, email MCP draft handoff, and candidate decisions. Scores are system-generated; this skill only moves data and orchestrates. Requires LAPLACE_RECRUITMENT_BASE_URL and LAPLACE_RECRUITMENT_API_KEY."
---

# Laplace Recruitment Skill

Operate Laplace Recruitment via `/open/v1/*` APIs only. Never call internal `/api/v1/*`, manage API keys, touch the DB, or bypass scopes.

## What this skill is (read first)

This skill runs in **two modes** over the same atomic APIs — route to the right one first:
- **① Interactive** — a human is chatting (ad-hoc natural-language requests like "看下今天的待办""淘汰张三""给王欣瑞发起面试"). Human drives; **confirm each sensitive write before doing it**. Playbook: `playbooks/90-interactive.md`.
- **② Scheduled** — the FDE runner fires ONE specific task on cron (e.g. "run import-resumes"). **Autonomous**: drain that task's entire backlog per the policy in `NOTES.md`, then report. Playbooks: `10`–`60`.

**How to tell:** if the turn is a human's free-form message → Interactive. If it's a runner firing a named task/playbook → Scheduled. When unsure, treat as Interactive (confirm before acting).

Shared truths (both modes):
- **Scores are 100% system-generated.** This skill never judges/scores; it reads the system score and routes. It only moves data in/out and orchestrates.
- **Candidate emails are draft-only** (DrayEasy): prepare drafts via the email MCP; a human sends. Never auto-send candidate mail.
- Candidate-facing links (`interviewUrl`/`publicUrl`) are returned by the backend as **absolute frontend URLs** — forward as-is.
- Autonomy differs by mode: **Scheduled** = humans gate only ① init and ② result/talent-pool hand-off, the middle runs per `NOTES.md`; **Interactive** = the human drives and confirms every write.

## Configuration（生产环境包）

本包**已内置生产环境地址**,用户**只需要提供一个 API Key**。
- `LAPLACE_RECRUITMENT_API_KEY`(必填):开放平台的 `lap_sk_` 密钥。
- `LAPLACE_RECRUITMENT_BASE_URL`(选填):默认已指向生产环境,一般无需设置(生产包会内置生产地址)。

**向用户要 Key 时,说人话,别甩环境变量或技术名词。** 就这样引导:
> "开始前我需要一个 API Key。请打开招聘系统 →「开放平台」→「API Key」→ 点「创建 Key」→ 把生成的、以 `lap_sk_` 开头的那串复制发给我就行。(生产环境地址已内置,你不用填。)"

拿到后设置到环境、只以 `lap_sk_****` 形式回显、绝不写入文件或打印全文。

## HTTP wrapper

`scripts/laplace_recruitment.py` is the shared atomic API client. Write commands need `--confirmed`.
```
python scripts/laplace_recruitment.py capabilities
python scripts/laplace_recruitment.py get /open/v1/todos/summary
python scripts/laplace_recruitment.py post /open/v1/candidates/123/decision --confirmed --json '{"decision":"reject","reason":"..."}'
```

## Self-check gate (every run, before any task)

Cheap, no API calls: **read `NOTES.md`**.
1. If `NOTES.md` missing, or `init_flag` false, or `initialized_skill_version` ≠ this skill version → run `playbooks/00-init.md` first (guided init / additive migration), then continue.
2. Otherwise proceed directly to the requested task. Do **not** re-verify everything each run — trust the flag.
3. **Post-hoc safety net:** if any task hits a "not configured" error mid-run (e.g. a job lacks written-test content), don't crash — record it and hand that item to the human via the report.

Then `capabilities` to confirm scopes; enable only returned endpoints; if a needed scope is missing, tell the user to add it (don't try the call).

## Playbooks

Interactive mode → `playbooks/90-interactive.md`. Scheduled mode → load the one task's playbook and run it to completion over the whole backlog:

| Task | Mode / Cadence | Playbook |
|---|---|---|
| Interactive (human chat) | 交互 · on demand | `playbooks/90-interactive.md` |
| Self-check + guided init | 触发式 · gate fail / version bump | `playbooks/00-init.md` |
| Import resumes from email | **定时 · 每天 10:00 / 14:00 / 20:00** | `playbooks/10-import-resumes.md` |
| Resume screening decisions | **定时 · 每天 11:00 / 15:00 / 21:00** | `playbooks/20-screen.md` |
| Conclusion / result hand-off | 定时 · 每天 09:00 | `playbooks/50-conclude.md` |
| Daily digest + SLA chase | 定时 · 每天 09:05 | `playbooks/60-digest-sla.md` |
| Written test | **人工/交互 · 非定时任务** | `playbooks/30-written-test.md` |
| Interview | **人工/交互 · 非定时任务** | `playbooks/40-interview.md` |

**只建 4 个自动化定时任务**:导入 + 初筛(两个核心)+ 结论 + 简报-SLA。**笔试/面试改为人工操作**(HR 经交互模式或小程序发起),不建定时任务,但 playbook 30/40 保留供人工/交互调用。各定时任务独立、幂等、只读当前后端状态,各自产出独立汇报/工单,绝不合并。
**排期两条硬规矩(初始化时落实):**
1. **时区 = 用户当地时间(默认北京 UTC+8)。沙箱时间不可信**,init 必须问用户时区,cron 锚定明确时区(导入 10/14/20、初筛 11/15/21、结论+简报 09:00 起,全按当地时间)。
2. **每个定时任务都必须 assign 给招聘 agent(本智能体)**——只有它带着本 skill + API Key 才能执行。
实际 cron 挂载 + tz 锚定 + 工单投递由 FDE 自动化 skill 负责;本 skill 只定义任务并各自产出结构化汇报。被问"要不要合并日任务",答案永远是**不合并**。

## Decision policy — Scheduled mode (who acts)

(Interactive mode: the human decides everything; the AI confirms each write and executes. See `90-interactive.md`.)

| Stage | Actor | Rule |
|---|---|---|
| 初筛 score < threshold | **AI auto** | `decide_candidate` → reject, reason = 低于阈值 |
| 初筛 score ≥ threshold | **AI auto (仅放行+汇报)** | 标记通过初筛,**汇报"通过初筛,待 HR 人工发笔试/面试"**;**不自动建笔试/面试**(笔试/面试已改人工) |
| 笔试/面试发起 | **人工** | HR 经交互模式或小程序发起(playbook 30/40 供其调用),skill 不自动做 |
| 笔试 / 面试**结果**(系统评分) | **结论任务汇报,人工定夺** | 报系统分+上下文 → 人工确认 淘汰/推进/录取 |
| 人才库 / 最终结论 | **汇报+交接** | 结论+全上下文+建议下一步(取 `NOTES.md`);人工接手 |

唯一自动终态动作 = 初筛 < 阈值淘汰。放行后的笔试/面试及一切下游都由人工发起/定夺。

## Notebook (`NOTES.md`) rules

- `NOTES.md` is the **user's instance config** (generated from `NOTES.template.md` at init). It holds **policy only**: thresholds, per-job written-test on/off, backfill window, SLA days, hand-off script.
- **Never store backend-derivable state** (links, expiry, scores, statuses) in it — re-query the backend, the source of truth, to avoid drift.
- **Never overwrite user values.** Version bumps do additive migration only (see `00-init`).

## Guardrails / gotchas

- **轮询必须有上限,绝不无限轮(死循环红线)。** 任何"等任务完成"的轮询(邮件同步 `email-sync-tasks`、简历导入批次 `resume-import-batches`、面试题生成 `questions_generating`):**固定间隔 ~5 秒、最多 ~12 次(≈1 分钟)**;到点仍是 `pending`/`running`/生成中 → **停止轮询,汇报"任务进行中(id X),本轮不阻塞,结果留待下一轮/稍后",然后退出**。不要越睡越久、不要一直等。若任务长时间 `pending` 且 `startedAt` 为空(worker 未消费)→ 判为后端/环境问题,汇报给人工,别自旋。
- `page_size` max 100. `interviewUrl` only on interview **detail**, not list.
- Reviewable states: written test `submitted`; interview review `completed`; accept questions from `questions_pending_review`.
- Duplicate guards are expected (e.g. `active_ai_interview_exists` 409) — treat as "already done", skip, don't retry blindly.
- Backend 500 → "服务暂时不可用,请稍后重试" (no stack trace). Never cache resume bodies/attachments. Mask PII in non-email contexts.
