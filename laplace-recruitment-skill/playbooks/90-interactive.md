# Playbook 90 · 交互模式(人直接聊)

触发:人在聊天框自然语言下指令(非定时任务)。风格:HR 助手,文本对话,先展示影响再执行。
与定时模式的区别:**人驱动、每个写操作先确认再做**(不自动决策)。分数仍全由系统生成,本 skill 只读分+调接口。

前置:自检门通过(缺 Key/未初始化 → 走 `00-init` 的人话引导)。首次先 `capabilities`,只用返回的接口;缺 scope 友好提示补权限。

## 意图 → 能力(把自然语言映射到接口)

| 用户说什么 | 做什么 |
|---|---|
| "今天怎么样/看下待办/晨间简报" | `GET /open/v1/todos/summary` + 各队列计数,汇报(不需要点名候选人) |
| "有哪些岗位/看 X 岗位" | `GET /open/v1/jobs` / `GET /open/v1/jobs/{id}` |
| "建个岗位…" 🛡 | `POST /open/v1/jobs` |
| "看 X 候选人/他的评分" | `GET /open/v1/candidates` · `/{id}` · `/{id}/score` |
| "上传这份简历到 X 岗位" 🛡 | `POST /open/v1/resumes`(multipart)|
| "从邮箱拉简历/同步简历" 🛡 | 同步+导入(见下,**一次确认**)|
| "完成/驳回 X 的待办" 🛡 | `GET /open/v1/todos` 定位 → `POST /open/v1/todos/{id}/complete` |
| "给 X 建笔试" 🛡 | `POST /open/v1/written-tests` → 拿 `publicUrl` |
| "评审 X 的笔试" 🛡 | 仅 `submitted` 可评:`GET /open/v1/written-tests/{id}` → `POST …/review` |
| "给 X 建面试" 🛡 | `POST /open/v1/interviews`(题目自动生成)|
| "确认 X 的面试题目" 🛡 | `POST /open/v1/interviews/{id}/questions/accept`(硬门:仅 `questions_pending_review`)|
| "复盘 X 的面试" 🛡 | `GET /open/v1/interviews/{id}/result` → `POST …/review` |
| "淘汰/通过/入库/归档 X" 🛡 | `POST /open/v1/candidates/{id}/decision` |
| "给 X 发笔试/面试邮件" 🛡 | 取链接 → `prepare-email-mcp-handoff`(**建草稿,不直接发**)|

🛡 = 敏感写操作,**先确认再执行**。

## 确认规则(和 core 一致)
- 每个 🛡 动作先展示:动作、候选人+岗位、当前/目标状态、是否发邮件(建草稿)、是否关待办、是否影响终态 → 问"确认吗?"。回"确认"才做,回"取消"不动。
- **批量**指令("把这批都淘汰""给这几个发笔试")→ 一次批量确认(分组展示名单),不逐个问;只把存疑/重复项单独拎出。
- 模糊回复("再看看""可能吧")→ 引导明确回"确认/取消",不误触、不死循环。
- 多轮上下文:"他/她/这个候选人"正确指代上一个提到的候选人。

## 硬门 / 边界(和定时模式共用)
- 题目未确认(`questions_pending_review`/`generating`)→ 拿不到有效面试链接、不能发邀约。
- 仅 `submitted` 笔试可评审;仅 `completed` 面试可复盘;终态候选人不可再决策(提示已锁定)。
- 候选人邮件一律**只建草稿**,人来发;链接是后端返回的绝对前端 URL,原样转发。
- 手机号/邮箱在非邮件场景脱敏;发邮件确认时展示完整邮箱。
- 轮询有上限(见 SKILL.md);后端 500 → "服务暂时不可用,请稍后重试",不露堆栈。

## 邮箱拉简历(交互式,一次确认)
用户说"拉简历"→ 一次确认后:`POST /open/v1/email-sync-tasks`(有上限轮询)→ `GET /open/v1/email-messages?resume_only=true` → **按岗位路由后分岗导入**(见 `10-import-resumes` §4-5:从 subject/attachmentName 提岗位、匹配 `GET /open/v1/jobs` 分组,每组带 `jobId` 各调一次 `import`,≤20/批;歧义/未匹配转人工绑岗不硬绑)→ 汇报**各岗位导入 N 份 + 待人工绑岗 M 份**。不逐封问、不二次确认导入。**绝不导入未绑定岗位的简历而不吭声**(否则没评分维度、流程断)。
