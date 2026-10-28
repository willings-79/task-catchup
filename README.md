# task-catchup — 定时任务补跑补丁

让 agent 创建的定时任务"错过不丢"：错过时间点（关机/休眠/程序没开）后，下次登录或唤醒时**自动补跑**。
核心语义：**调度时间 = 最早可执行时间，不是唯一时间点**。

> Windows 用计划任务 `StartWhenAvailable`；Linux 用 systemd timer `Persistent=true` 或 anacron。
> 补跑为合并语义：错过多天也只补跑一次（补最近一次），不会连跑 N 份。

## 新用户 5 分钟上手

**第 1 步 · 安装**（三选一，详见下文各平台小节）：
- ZCode：插件市场 → 添加 → 添加插件市场 → 粘贴本仓库解压/克隆出的目录 → 个人 → 安装
- Claude Code：`/plugin marketplace add willings-79/task-catchup`
- 其他 agent：把 `task-catchup/skills/task-catchup` 文件夹放进它的技能目录（若有技能系统），或用下文"规则粘贴"方式

**第 2 步 · 直接说人话**。装好后对 agent 说：

- 「帮我建个每天早上 9 点的日报定时任务」→ 它会建出带补跑的任务
- 「检查我的定时任务有没有开补跑」→ 列出没开的存量任务
- 「把没开补跑的任务都补上」→ 先列清单给你确认，再批量写入

**第 3 步 · 验收**：打开"任务计划程序"，看新建任务的属性 → 设置页 → "错过计划开始后尽快启动"已勾选即生效。

**不用任何 agent？** 纯 PowerShell 也行（先看清单、加 `-Apply` 才写入）：

```powershell
powershell -ExecutionPolicy Bypass -File task-catchup\skills\task-catchup\scripts\Enable-TaskCatchup.ps1
powershell -ExecutionPolicy Bypass -File task-catchup\skills\task-catchup\scripts\Enable-TaskCatchup.ps1 -Apply
```

## 为什么需要它

各家 AI agent（ZCode / Codex / Claude Code …）写的定时任务，几乎都用 `schtasks /create` 或裸 cron——这两种方式**都没有补跑**，机器不在那个点开着，任务就静默丢了。本插件给 agent 打补丁：凡是建定时任务，自动带上补跑语义。

## 安装

### ZCode
1. 下载仓库 ZIP（Code → Download ZIP）解压，或 `git clone` 本仓库
2. **插件市场 → 添加 → 添加插件市场** → 粘贴解压/克隆出的目录 → 添加
3. **个人 → task-catchup 市场 → "定时任务补跑补丁" → 安装**
4. 验收：新建任务说"帮我建个每天 9 点的定时任务"，预期建出的任务 `StartWhenAvailable=True`

### Claude Code
```
/plugin marketplace add willings-79/task-catchup
/plugin install task-catchup@task-catchup
```
或手动：把 `task-catchup/skills/task-catchup` 复制到 `~/.claude/skills/task-catchup`。

### Codex / 其他 agent（无技能系统）
把下面规则粘进全局指令文件（Codex: `~/.codex/AGENTS.md`；Claude Code: `~/.claude/CLAUDE.md`）：

> 创建定时任务规则：Windows 计划任务必须启用"错过补跑"——PowerShell 用 `New-ScheduledTaskSettingsSet -StartWhenAvailable`；`schtasks` 必须走 `/XML` 且包含 `<StartWhenAvailable>true</StartWhenAvailable>`。Linux 用 systemd timer `Persistent=true` 或 anacron，不用裸 cron。调度时间=最早执行时间，错过（关机/休眠）后在下次开机/唤醒时立即补跑一次。

### WorkBuddy（腾讯 CodeBuddy 团队的桌面 Agent）

三种方式，按顺序试：

1. **技能导入**：WorkBuddy 支持自定义 Skills（见其文档"创建自己的 Skills"实践案例）——把 `task-catchup/skills/task-catchup` 整个文件夹作为自定义技能导入。SKILL.md 遵循开放技能格式，会在你提到定时任务时自动生效
2. **规则粘贴**：把上面 Codex 一节的那段规则粘进 WorkBuddy 的记忆 / 自定义指令
3. **直接差遣（永远可用）**：任何能在你电脑上执行命令的 agent 都可以这么用——

   > 从 https://github.com/willings-79/task-catchup/releases 下载 zip 并解压，先运行里面的 Enable-TaskCatchup.ps1，列出没开补跑的任务给我看，我确认后再加 -Apply 真正写入

   建新任务则直接说需求，并补一句「用 Windows 计划任务，必须启用错过补跑（StartWhenAvailable）」。

⚠️ WorkBuddy 自带的"自动化"定时功能同样只在 WorkBuddy 运行时触发——需要补跑保证的任务请落到 Windows 计划任务。

### 直接用脚本（任何能跑 PowerShell 的环境）
脚本在 `task-catchup/skills/task-catchup/scripts/`，需 PowerShell 5.1+：

```powershell
# 新建带补跑的任务（触发器可选 -Daily / -Weekly+-WeeklyAt / -Hourly / -AtLogon / -AtStartup，-Wake 附带睡眠唤醒；
# 可选 -MaxDelayHours N 限定补跑窗口：错过超过 N 小时不再补，防止陈旧任务开机突袭；不传=总是补跑；
#   仅支持 -Daily/-Weekly，守卫自动防重复执行，参数原样传递不受 PS 二次解析影响）
powershell -NoProfile -ExecutionPolicy Bypass -File New-CatchupTask.ps1 -Name "日报" -Run "powershell.exe" -Arguments "-File C:\jobs\report.ps1" -Daily "09:00"

# 批量给存量任务开启补跑（默认 dry-run 只列出，加 -Apply 才写入；只处理非 \Microsoft\ 任务）
powershell -NoProfile -ExecutionPolicy Bypass -File Enable-TaskCatchup.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File Enable-TaskCatchup.ps1 -Apply
```

## 说明与边界

- Windows 脚本部分需 PowerShell 5.1+（Win10/11 自带）；给系统级任务改设置可能要管理员权限
- Linux 部分为规则指引（systemd/anacron），脚本仅覆盖 Windows
- 应用内定时（各 agent 对话里建的 automation、WorkBuddy 的"自动化"等）只在宿主程序运行时触发，无补跑语义；需要补跑保证的任务请落到 OS 调度器
- Claude Code 安装路径按其插件生态约定提供，未在全部版本上实测

## License

MIT
