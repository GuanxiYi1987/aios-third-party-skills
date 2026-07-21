# Playbook 40 · AI 面试(人工/交互触发 · 非定时任务)

> AI 面试已改为**人工操作**:不再有定时任务,由 HR 经交互模式或小程序发起。本 playbook 保留,供交互模式("给涂麒建面试""确认题目")或人工按需调用时参照。

目标:给该进面试的候选人批量建面试并生成题目;题目**由人工确认**(硬门);题目确认后再备邀约草稿。

前置:自检门通过。谁该进面试:初筛放行且岗位 `needs_written_test: false`,或笔试已通过(人工推进后)且尚无面试。

步骤(处理整批,分两类):
1. **新建面试**(目标候选人尚无进行中面试):
   - `POST /open/v1/interviews --confirmed --json '{"candidateId":...}'`。撞到 `active_ai_interview_exists`(409)→ 已有,跳过(幂等)。
   - 系统自动生成题目:`questions_generating` → `questions_pending_review`。**不阻塞死等生成**:检查一次即可,若仍 `questions_generating` → 报"题目生成中,下轮再看",不无限轮(见 SKILL.md 轮询上限)。
   - **不自动确认题目**(硬门:题目须人工确认)。题目就绪(`questions_pending_review`)则汇报"候选人 X 面试题已生成,待人工确认"(附题目摘要,可 `GET /open/v1/interviews/{id}` 取)。
2. **已确认题目的面试备草稿**:扫状态 `not_started` 的面试(= 人工已 `questions/accept`),`GET /open/v1/interviews/{id}` 取 `interviewUrl`(绝对前端链接,仅详情有)+ 候选人邮箱。
   - `prepare-email-mcp-handoff --confirmed --scenario ai_interview_invite --link-type ai_interview --link-url <interviewUrl> ...` → **建草稿(不发)**,人来发。
3. 汇报:新建面试 N(待人工确认题目)、已确认→备邀约草稿 M。交 FDE 投工单。

**硬门**:题目未确认(状态 `questions_pending_review`/`questions_generating`)绝不备邀约、绝不发。面试结果(`completed`,系统评分)由 `50-conclude` 处理。
