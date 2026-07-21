# Playbook 30 · 笔试(人工/交互触发 · 非定时任务)

> 笔试已改为**人工操作**:不再有定时任务,由 HR 经交互模式或小程序发起。本 playbook 保留,供交互模式("给张三建笔试")或人工按需调用时参照。

目标:给"初筛放行 + 岗位需笔试"的候选人批量建笔试,备好草稿邀约,汇报。笔试非刚需——只对 `needs_written_test: true` 的岗位做。

前置:自检门通过。读 `NOTES.md`(哪些岗位 `needs_written_test: true`)。

步骤(处理整批):
1. 找目标候选人:初筛已放行、岗位需笔试、且尚无笔试(查后端状态判断,别靠笔记本)。
2. 逐个建笔试:`POST /open/v1/written-tests --confirmed --json '{"candidateId":...,"dueDays":<NOTES.sla_written_test_days 或 7>}'`。
   - 若返回 `请先在岗位管理中配置笔试题内容` → 该岗位没配笔试题 → **转人工**:汇报"岗位 X 需在岗位管理配笔试题",跳过该候选人。
3. 拿 `publicUrl`(后端返回的绝对前端链接)+ 候选人邮箱 + `dueAt`。
4. **备草稿(不发)**:`prepare-email-mcp-handoff --confirmed --scenario written_test_issue --link-type written_test --link-url <publicUrl> --candidate-email ... --context ...`。DrayEasy 只建草稿,人来发。
5. 汇报:本批建笔试 N 份(候选人/岗位/链接/截止),已备草稿 N 封待人工发送。交 FDE 投工单。

**链接/过期/分数一律以后端为准,不落 NOTES。** 笔试结果(`submitted`,系统评分)由 `50-conclude` 汇报给人工定夺,本步不评审、不推进。
