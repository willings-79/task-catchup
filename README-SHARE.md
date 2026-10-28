# task-catchup — 定时任务补跑补丁 v0.3.1

让 agent 创建的定时任务"错过不丢"：错过时间点（关机/休眠/程序没开）后，下次登录或唤醒时**自动补跑**。
核心语义：**调度时间 = 最早可执行时间，不是唯一时间点**。Windows 用计划任务 `StartWhenAvailable`，Linux 用 systemd timer `Persistent=true` 或 anacron。

> 默认补跑窗口为**一天（24 小时）**，可自定；错过多天也只补跑一次（补最近一次），不会连跑 N 份。

## 即插即用（推荐，桌面版用户首选）

解压本包后，在解压目录里执行一次：

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
```

它自动完成：技能装进 ZCode / Claude Code / Codex / 通用 `~/.agents/skills` 目录、防丢规则写入各家全局指令（带标记，`-Undo` 一键卸载）、列出没开补跑的存量任务（`-ApplyExisting` 顺带修好）。

**桌面版用户更省事的姿势**：直接对桌面版 agent（WorkBuddy / ZCode / DSH 桌面端等）说——

> 帮我运行解压目录里的 install.ps1

桌面版 agent 能替你执行全部步骤，装完**新开会话**即生效。

装好后对 agent 说人话即可：「帮我建个每天 9 点的定时任务」「检查我的定时任务有没有开补跑」「把没开的都补上」。验收：任务计划程序 → 任务属性 → 设置 → "错过计划开始后尽快启动"已勾选。

## 各家接入

### ZCode（桌面版）

- **纯市场**：插件市场 → Discover → **+** → 添加 GitHub 仓库 `willings-79/task-catchup` → 安装
- **本地包**：插件市场 → 添加 → 添加插件市场 → 粘贴解压目录 → 个人 → task-catchup-market → 安装
- install.ps1 也会把技能装进 `~/.zcode/skills`（用户级，自动发现）

### WorkBuddy（wb · 桌面版）

桌面端"技能"功能导入自定义技能（见其文档"创建自己的 Skills"）：把 `task-catchup/skills/task-catchup` 导入；或对它说"帮我运行解压目录里的 install.ps1"。⚠️ WorkBuddy 自带的"自动化"定时无补跑语义，需要补跑保证的任务让它们落到 Windows 计划任务。

### DSH（DeepSeek Harness · 桌面端/CLI）

自带 Skills 市场与插件体系：导入 `task-catchup/skills/task-catchup`；或把规则粘进其全局指令；CLI 形态直接跑脚本最省事。

### Codex（桌面版 / IDE / CLI）

桌面版最省事：直接对 Codex 说「帮我运行解压目录里的 install.ps1」。已官方支持 Skills：把 `task-catchup/skills/task-catchup` 放进其技能目录；或把下面规则粘进 `~/.codex/AGENTS.md`：

> 创建定时任务规则：Windows 计划任务必须启用"错过补跑"——PowerShell 用 `New-ScheduledTaskSettingsSet -StartWhenAvailable`（配合电池策略参数）；schtasks 必须走 /XML 且含 `<StartWhenAvailable>true</StartWhenAvailable>`。默认补跑窗口一天（-MaxDelayHours 可改）。Linux 用 systemd timer Persistent=true 或 anacron。调度时间=最早执行时间。

### Claude Code / Cursor / Gemini CLI / Copilot 等其他 agent

支持开放技能格式的，把 `task-catchup/skills/task-catchup` 复制进各自技能目录（Claude Code 也可 `/plugin marketplace add willings-79/task-catchup`）；都能执行命令的，用 install.ps1 或直接差遣。

## 补跑时间窗（默认一天，可自定）

- **默认**：只补 **24 小时内**错过的任务（防止陈旧任务开机突袭），同一错过只执行一次（守卫自动记录状态）
- **自定**：建任务时加 `-MaxDelayHours N`（N 小时；`-MaxDelayHours 48` = 两天内）；`-MaxDelayHours 0` = 不限时长、总是补最近一次
- **对话里说**：「超过一天的就不补了」（默认即是）、「不限时间，能补就补」（用 0）

## 直接用脚本（任何能跑 PowerShell 的 agent / 人）

脚本位于 `task-catchup/skills/task-catchup/scripts/`，需 PowerShell 5.1+（Win10/11 自带）：

```powershell
# 新建带补跑的任务（触发器可选 -Daily / -Weekly+-WeeklyAt / -Hourly / -AtLogon / -AtStartup，-Wake 附带睡眠唤醒；
# 默认补跑窗口 24 小时：-MaxDelayHours N 自定，0=不限；仅 -Daily/-Weekly 支持窗口，守卫自动防重复，参数原样传给子进程）
powershell -NoProfile -ExecutionPolicy Bypass -File New-CatchupTask.ps1 -Name "日报" -Run "powershell.exe" -Arguments "-File C:\jobs\report.ps1" -Daily "09:00"

# 批量给存量任务开启补跑（默认 dry-run 只列出，加 -Apply 才写入；只处理非 \Microsoft\ 任务）
powershell -NoProfile -ExecutionPolicy Bypass -File Enable-TaskCatchup.ps1            # 先看会改哪些
powershell -NoProfile -ExecutionPolicy Bypass -File Enable-TaskCatchup.ps1 -Apply     # 确认后写入
```

## 注意

- Windows 脚本部分需管理员权限的场景：给**别人创建的**系统级任务改设置时可能要管理员；给自己（当前用户）的任务通常不需要；`-AtStartup`（boot 触发器）必须管理员
- Linux 部分为规则指引（systemd/anacron），脚本仅覆盖 Windows
- 应用内定时（各 agent 对话里建的 automation、WorkBuddy 的"自动化"等）只在宿主程序运行时触发，无补跑语义；需要补跑保证的任务请落到 OS 调度器
- DSH 与 WorkBuddy 官方市场的收录按各自流程另行申请；当前用 install.ps1 即插即用
