# Playbook 50 · 结论 / 人才库交接(每天早上 09:00 当地时间)

目标:把有系统评分结果的笔试/面试,连同完整上下文**汇报给人工定夺**,并给出建议下一步(交接)。**本步不做自动终态决策**——淘汰/推进/录取/入库都由人工确认后执行。

前置:自检门通过。读 `NOTES.md` 的 `handoff_*`(本公司交接话术/默认下一步)。

步骤(处理整批):
1. 收集已出结果的项:
   - 笔试 `submitted`:`GET /open/v1/written-tests?status=submitted`,逐个 `GET /open/v1/written-tests/{id}` 取系统分/答案。
   - 面试 `completed`:`GET /open/v1/interviews?status=completed`,`GET /open/v1/interviews/{id}/result` 取系统分/评语。
2. 为每个候选人生成**交接卡**(用 `NOTES.handoff_note` 模板):姓名 · 岗位 · 阶段 · 系统分 · 关键证据摘要 · 建议下一步(默认 `handoff_default_next_action`,如"安排人工面试")。
3. **不自动写终态**。把交接卡汇总汇报给人工:人工确认后再由人(或经确认的后续动作)执行 `decide_candidate`(pass/reject/talent_pool/archive)。
4. 汇报:待定夺 N 人(逐人交接卡 + 建议动作)。交 FDE 投工单。

分数全程系统生成,本步只读分+组织上下文+交接,绝不自评。
