# Playbook 10 · 邮件简历导入(每天 10:00 / 14:00 / 20:00 当地时间)

目标:把新到的邮件简历批量导入系统、**按岗位路由绑定**,导入后**不管**——系统异步评分,下一轮/后续任务从队列取。轻、省 token。

前置:自检门通过(见 SKILL.md);否则先 `00-init`。**一次性先取岗位清单**:`GET /open/v1/jobs --query page_size=100` → `[{id, positionName}]`(下面路由要用)。

⚠️ **轮询红线**:本 playbook 有两处轮询,都必须**有上限**(见 SKILL.md「轮询必须有上限」)——固定 ~5 秒间隔、最多 ~12 次;到点未完成就**停下汇报"进行中,下轮再取"并退出**,绝不无限等/越睡越久。

步骤:
1. `POST /open/v1/email-sync-tasks --confirmed --query days=1`(常规取近一日新邮件;后端每轮 ≤50 封,已导入的自动去重)。
2. **有上限地**轮询 `GET /open/v1/email-sync-tasks/{task_id}`(~5 秒×最多 12 次)直到 `status` 变 `completed`/`failed`:
   - `completed` → 继续;`failed` → 报 `errorMessage`,退出。
   - 到上限仍 `pending`/`running` → **停**:报"同步任务 {id} 仍进行中,本轮不阻塞,下轮再取",退出。
   - 若 `pending` 且 `startedAt` 为空(worker 没消费)→ 判环境/后端问题,报人工,别自旋。
3. `GET /open/v1/email-messages?resume_only=true` 拿识别出的简历来源。每条记下 `subject` / `attachmentName` / `resumeSourceIds`(待导入的来源 ID)。同步窗口 `hasMore=true`/有 `nextBeforeUid` 时常规轮询取 1 轮即可(大回溯见 `00-init`)。

### ★ 4. 岗位路由(#740 兜底,后端 `suggestedJobId` 上线前**必做**)
> 导入前必须把每份简历路由到正确岗位——**否则候选人"未绑定岗位"、没有 matchDimensions 无法评分、初筛及后续全断。** 只比短字符串,不读简历全文,token 便宜。

对每条简历消息:
1. **提岗位串**:从 `subject`(BOSS:"…应聘 &lt;岗位&gt; | 城市薪资【平台】")或 `attachmentName`("【&lt;岗位&gt;_城市_薪资】…")里抠出岗位名。
2. **匹配前置的岗位清单**(规范化后比):去掉修饰词(如"（AI 方向 / Vibe Coding 优先）""高级""实习""城市/薪资/平台"),比**核心词**(如"全栈工程师"→系统"全栈高级工程师")。
   - **命中唯一** → 记 `sourceId → jobId`(高置信,入分组)。
   - **命中多个(歧义)或一个都不中** → 标「待人工」(**不猜、不硬绑**——错绑=评分维度用错岗位,比不绑更糟)。

### 5. 分岗导入(按 jobId 分组,每组各一次)
- 每个 jobId 分组:`POST /open/v1/email-resume-sources/import --confirmed --json '{"sourceIds":[≤20],"jobId":<该组jobId>}'`(超 20 拆批,不静默丢)。
- **「待人工」的**:导入为**未绑定**(不传 jobId)或本轮先不导入;在汇报里**逐条列出**「待人工绑岗:&lt;邮件标题/候选人&gt; → 疑似 &lt;岗位&gt;? / 无法判断」,让人一键补绑(补绑后才进评分流程)。

### 6. 收尾
- **有上限地**轮询 `GET /open/v1/resume-import-batches/{batch_id}`(~5 秒×最多 12 次);到点未完成 → 报"导入进行中"退出,不无限等。
- **到此为止**:不评分(系统做)、不逐个决策。汇报:**各岗位导入 N 份**、待人工绑岗 M 份(逐条列建议岗位)、跳过重复 Z 份、失败 W 份(附原因)。交 FDE 投工单。

不缓存简历正文/附件。异常(500/网络)→ 记录并汇报,不崩。**后端 `suggestedJobId`(#740/#747)上线后,第 4 步直接用后端建议岗位,删除本地匹配逻辑。**
