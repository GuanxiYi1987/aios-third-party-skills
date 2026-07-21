# CHANGELOG · laplace-recruitment-skill

遵循 [semver](https://semver.org)。发版：bump version → 追这里 → 改 `meta.yaml` 的 `updated_at`（上线填 `launched_at`）→ 打 tag `laplace-recruitment-skill/vX.Y.Z`。

## v0.0.4 — 2026-07-05（邮箱导入按岗位路由 · #740 兜底)
- **修 #740 兜底**:导入前按岗位路由(`10-import` §4-5 + `90-interactive`)——从邮件 subject/attachmentName 提岗位名、匹配 `GET /open/v1/jobs`、按 jobId 分组、每组带 `jobId` 各调一次 `import`(≤20/批);歧义/未匹配**转人工绑岗不硬绑**(错绑=评分维度用错,比不绑更糟)。解决多岗位共用邮箱导入后候选人全"未绑定"、无评分维度、流程断的问题。后端 `suggestedJobId`(#740/#747)上线后删本地匹配逻辑。
- 顺带修正 `10-import` 头部频率笔误 → 10/14/20。

## v0.0.3 — 2026-07-03（定时批量 · 自检/初始化 · 笔记本)
- 运行范式改为**定时批量 AI-HR**:每次运行抽干当前积压直到无事可做,不再逐个候选人处理(省 token/快)。人只在①初始化②人才库/结果交接两端守门,中间按 `NOTES.md` 策略自动跑。
- **拆分结构**:业务流程从大一统拆成独立 playbook(`playbooks/00-init`…`60-digest-sla`),各定时任务只加载自己那份;`scripts/laplace_recruitment.py` 保留为共享 HTTP 原子层。
- **自检门**:每次冷启只读 `NOTES.md` 的 `init_flag`+`initialized_skill_version`(不打 API);缺失/版本不符 → 进 `00-init`;中途遇未配置错误 → 转人工(后验兜底)。
- **笔记本**:新增 `NOTES.template.md`(只存业务策略),实例 `NOTES.md` 归用户;**版本迁移只增不改,绝不覆盖用户偏好**;链接/过期/分数实时查后端,不落笔记本。
- **决策策略**:分数全由系统生成,skill 只读分+路由。唯一自动终态=初筛<阈值淘汰;≥阈值到"备草稿"为止;笔试/面试结果只汇报、人工定夺;候选人邮件一律只建草稿不发。
- **排期**:导入每 30 分,screen/written-test/interview/conclude/digest-sla 每日 09:00;实际 cron+工单投递由 FDE 自动化 skill 接管。
- **收敛为 4 个自动化任务**:只保留 导入(每天 10/14/20)+ 初筛(每天 11/15/21)+ 结论(09:00)+ 简报-SLA(09:05);**笔试/面试改为人工操作**(去掉定时任务,由 HR 交互/小程序发起,playbook 30/40 保留)。初筛 ≥ 阈值只放行+汇报"待人工发笔试/面试",不再自动建笔试/面试。导入时间覆盖早/午/晚(晚 20 点接住下班后投递高峰)。
- **时区/assign**:时区按用户当地(默认北京 UTC+8),沙箱时间不可信→init 必问时区;每个定时任务必须 assign 给招聘 agent 执行。
- **双模式**:v0.0.3 补回**交互模式**(`playbooks/90-interactive.md`)——人可直接聊、逐步确认(等价 core 的对话能力),与定时批量模式并存;SKILL.md 顶部加模式路由(人聊=交互/确认每步,runner 触发=定时/自动批量)。回归确认:原子层与 core 逐字节一致,活环境全能力冒烟通过。
- **修死循环**:所有"等任务完成"的轮询(邮件同步/简历导入批次/面试题生成)加**硬上限**(~5秒×最多12次≈1分钟),到点未完成即停并汇报"进行中,下轮再取"后退出;`pending` 且 `startedAt` 空(worker 未消费)判环境问题报人工——不再无限轮/越睡越久。
- **上手体验**:测试包内置生产环境地址(`scripts DEFAULT_BASE_URL`),用户**只需一个 API Key**;缺 Key 时用人话引导"去 开放平台→API Key→创建→复制 lap_sk_ 那串",不再甩环境变量/技术名词。

## v0.0.2 — 2026-07-03（测试迭代 · 弱 agent 稳定性）
- `SKILL.md` 结构性重写：从"一条 S0→S6 大流程"改为**按日常场景/队列拆解**——晨间简报(digest)入口 + 6 个场景 playbook(简历初筛/笔试下发/笔试评审/面试筹备邀约/面试复盘/终态决策),每步给死接口与分支,降低弱 agent 乱序/漏步。
- **邮箱拉简历收敛为单次确认 + 自动导入**(对齐 PRD §7,去掉"二次问确认导入"),补**批量确认**规范(一次确认 N 条,只拎异常项)。
- 补**已知操作约束**清单:`page_size≤100`、`interviewUrl` 仅在详情、可评审状态前置、错误文案。
- 明确 **prod/test 分环境配置**;链接由后端返回绝对前端 URL(配合后端 #653 修复),skill 只转发不再自拼 host。
- owner 周海洋。

## v0.0.1 — 2026-07-03（归档 · 测试阶段，计划周五=今日上线）
- 首版归档（core）。封装 Laplace 招聘开放平台 `/open/v1/*` API：职位/候选人/简历同步导入/评分/待办/笔试/AI面试/邮件(handoff/draft/send)/候选人决策。
- HTTP wrapper：`scripts/laplace_recruitment.py`（capabilities / get / post …）。
- 守门：只调开放接口、API key 从 env 读且 mask。
- owner 周海洋。测试通过上线后 status→已上线。
