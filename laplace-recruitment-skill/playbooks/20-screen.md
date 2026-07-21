# Playbook 20 · 初筛决策(每天 11:00 / 15:00 / 21:00 当地时间)

目标:抽干"简历待确认"队列。**分数是系统给的**,本步只按阈值:淘汰 / 放行。**笔试/面试已改人工,本步不创建任何下一步**,只放行并汇报交给 HR。

前置:自检门通过。读 `NOTES.md` 的 `resume_pass_threshold`(默认 60)。

步骤(处理**整个队列**,翻页到空):
1. `GET /open/v1/todos?status=open&type=resume_confirm&page_size=100`(逐页)。每条带 `candidate.matchScore` 与岗位。
2. 逐候选人按分处理:
   - **score < 阈值 → 自动淘汰**:`POST /open/v1/candidates/{id}/decision --confirmed --json '{"decision":"reject","reason":"初筛<阈值(系统分 {score})"}'`。(唯一自动终态动作。)
   - **score ≥ 阈值 → 放行**:完成其简历待确认待办(`POST /open/v1/todos/{todo_id}/complete --confirmed`),汇报为"通过初筛,待 HR 人工发笔试/面试"。**本步不建笔试、不建面试。**
3. 汇报:淘汰 N 人(名单+分)、通过初筛 M 人(名单+分+岗位,标注"待人工发笔试/面试")。交 FDE 投工单。

边界:候选人分数未就绪(系统还没评完)→ 本轮跳过,留待下轮。终态候选人(已 reject 等)跳过。
