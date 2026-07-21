# Laplace 招聘 · 业务笔记(实例配置模板)

> 这是**模板**。`00-init` 会据此生成用户实例文件 `NOTES.md`。
> ⚠️ **skill 升级或重跑 init 只会「补齐新增项」,绝不覆盖 `NOTES.md` 里已填的值。** 用户自定义永远保留。
> 只存**后端存不了的业务策略/配置**;笔试/面试链接、过期、分数等实时查后端(唯一真相源),不落这里。

```yaml
# ── 初始化状态(由 init 维护,勿手改)──────────────
init_flag: false
initialized_skill_version: ""      # init 成功后写入当前 skill 版本
last_init_at: ""

# ── 初筛策略(用户可改)──────────────────────────
resume_pass_threshold: 60          # 初筛分 < 此值 → 自动淘汰;≥ 此值 → 备好下一步草稿+汇报

# ── 各岗位流程策略(init 询问用户;新岗位由 init 增量补问)──
# needs_written_test: 该岗位是否要笔试(笔试非刚需)
jobs:
  # - id: 11
  #   name: "全栈工程师-六月"
  #   needs_written_test: false     # true 时该岗位须在「岗位管理」配好笔试题内容

# ── 邮件导入(用户可改)──────────────────────────
init_backfill_days: 7              # init 时用户选:回溯导入多少天的邮件
init_backfill_max_emails: 300      # 初始化回溯上限(硬顶)
import_interval_minutes: 30        # 常规导入频率

# ── 排期意图:每个都是独立定时任务+独立汇报工单,勿合并 ──
# ⚠️ 时区:沙箱时间不可信 → init 必须问用户时区;默认北京时间(UTC+8)。
# ⚠️ 每个定时任务都必须 assign 给招聘 agent(本智能体)执行——只有它有 skill 和 API Key 上下文。
# cron 以下按【用户当地时间(默认北京)】表达;实际 tz 锚定与 cron 挂载由 FDE 自动化 skill 负责。
# 各任务独立幂等;顺序错位下轮自动补。
timezone: "Asia/Shanghai"              # init 向用户确认(沙箱 tz 不可信)
# 只建 4 个自动化定时任务:导入 + 初筛(两个核心)+ 结论 + 简报-SLA。
# 笔试/面试 = 人工操作(交互模式或小程序发起),不建定时任务;能力仍保留(playbooks 30/40 供人工/交互用)。
schedule:
  import_resumes: "0 10,14,20 * * *"   # playbook 10 · 每天 10/14/20 点(覆盖早/午/晚投递)
  screen:         "0 11,15,21 * * *"   # playbook 20 · 每天 11/15/21 点(导入+1h,给系统评分留时间)
  conclude:       "0 9 * * *"          # playbook 50 · 每天早上 09:00
  digest_sla:     "5 9 * * *"          # playbook 60 · 每天早上 09:05

# ── SLA(用户可改)追逾期用 ──────────────────────
sla_written_test_days: 7
sla_interview_days: 7

# ── 人才库/结论交接话术(用户可改)按本公司 HR 流程填 ──
handoff_default_next_action: "安排人工面试"
handoff_note: |
  按本公司招聘流程,达标候选人交接人工后续。请补充你司的下一步动作说明。
```
