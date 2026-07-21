# Playbook 60 · 每日简报 + SLA 追单(每天早上 09:05 当地时间)

目标:给一份当日全局简报,并追逾期/滞留项(报给人工,候选人侧动作只备草稿不发)。

前置:自检门通过。读 `NOTES.md` 的 `sla_*`。

步骤:
1. **简报**:`GET /open/v1/todos/summary` + 各队列(`todos?status=open` 按 type 计数)。报:未处理待办、简历待确认、笔试待评/待提交、面试待复盘、在招岗位。
2. **SLA 追单**(全报给人工):
   - 笔试逾期:`written-tests` 中 `dueAt < now` 且未 `submitted` → 列出候选人;如需催,`prepare-email-mcp-handoff` 备**提醒草稿**(不发)。
   - 面试滞留:已 `not_started`/已发出但超 `sla_interview_days` 未完成 → 列出。
   - 简历滞留:`resume_confirm` 待办创建超阈天数仍未处理 → 列出。
3. 汇报:简报 + 逾期清单(笔试/面试/简历各多少、名单、建议动作)+ 已备的提醒草稿数。交 FDE 投工单。

只汇报与备草稿,不自动发信、不自动改终态。计数/状态实时查后端。
