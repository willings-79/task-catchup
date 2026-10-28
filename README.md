# task-catchup — 定时任务补跑补丁

让 agent 创建的定时任务"错过不丢"：错过时间点（关机/休眠/程序没开）后，下次登录或唤醒时**自动补跑**。
核心语义：**调度时间 = 最早可执行时间，不是唯一时间点**。

> Windows 用计划任务 `StartWhenAvailable`；Linux 用 systemd timer `Persistent=true` 或 anacron。
> 补跑为合并语义：错过多天也只补跑一次（补最近一次），不会连跑 N 份。

## 新用户 5 分钟上手（即插即用）

**推荐路径：下载 → 解压 → 跑一下 install.ps1 → 完事。**

```powershell
# 在解压出的目录里执行：
powershell -ExecutionPolicy Bypass -File install.ps1
```

它会自动：把技能装进本机检测到的 agent 技能目录（ZCode / Claude Code / Codex / 通用 `~/.agents/skills`）、把防丢规则写进各家的全局指令（带标记，`-Undo` 一键卸载），并列出你机器上没开补跑的存量任务（加 `-ApplyExisting` 顺带修好）。装完**新开会话**，对任意 agent 说「帮我建个每天 9 点的定时任务」即可。

**桌面版用户（WorkBuddy / ZCode / DSH 桌面端）更省事的姿势**：直接对桌面版 agent 说「帮我运行解压目录里的 install.ps1」——桌面版 agent 能替你执行全部步骤，不用自己开终端。

**ZCode 用户还有第二条路（纯市场，不跑脚本）**：插件市场 → Discover → **+** → 添加 GitHub 仓库 `willings-79/task-catchup` → 安装（ZCode 支持把 GitHub 仓库直接作为市场源）。

主推四家（**WorkBuddy（wb）、ZCode、DSH、Codex**）的详细接法见下文各自小节；Claude Code、Cursor 等其他 agent 见「其他 agent」。

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

各家 AI agent（WorkBuddy / ZCode / DSH / Codex / Claude Code …）写的定时任务，几乎都用 `schtasks /create` 或裸 cron——这两种方式**都没有补跑**，机器不在那个点开着，任务就静默丢了。本插件给 agent 打补丁：凡是建定时任务，自动带上补跑语义。

## 安装

### WorkBuddy（wb · 腾讯 CodeBuddy 团队的桌面 Agent）

三种方式，按顺序试：

1. **技能导入**：WorkBuddy 支持自定义 Skills（见其文档"创建自己的 Skills"实践案例）——把 `task-catchup/skills/task-catchup` 整个文件夹作为自定义技能导入。SKILL.md 遵循开放技能格式，会在你提到定时任务时自动生效
2. **规则粘贴**：把下面 Codex 一节的那段规则粘进 WorkBuddy 的记忆 / 自定义指令
3. **直接差遣（永远可用）**：任何能在你电脑上执行命令的 agent 都可以这么用——

   > 从 https://github.com/willings-79/task-catchup/releases 下载 zip 并解压，先运行里面的 Enable-TaskCatchup.ps1，列出没开补跑的任务给我看，我确认后再加 -Apply 真正写入

   建新任务则直接说需求，并补一句「用 Windows 计划任务，必须启用错过补跑（StartWhenAvailable）」。

⚠️ WorkBuddy 自带的"自动化"定时功能同样只在 WorkBuddy 运行时触发——需要补跑保证的任务请落到 Windows 计划任务。

### ZCode

1. 下载仓库 ZIP（Code → Download ZIP）解压，或 `git clone` 本仓库
2. **插件市场 → 添加 → 添加插件市场** → 粘贴解压/克隆出的目录 → 添加
3. **个人 → task-catchup 市场 → "定时任务补跑补丁" → 安装**
4. 验收：新建任务说"帮我建个每天 9 点的定时任务"，预期建出的任务 `StartWhenAvailable=True`

### DSH（DeepSeek Harness）

本地优先的 AI 工作台（CLI / Web UI / TUI），自带插件与 Skills 体系：

1. **技能导入**：DSH 有 Skills 市场与插件机制——把 `task-catchup/skills/task-catchup` 导入其技能体系（SKILL.md 为开放技能格式）
2. **规则粘贴**：把下面 Codex 一节的规则加进 DSH 的全局指令 / 系统提示配置（参考其插件与配置文档）
3. **直接差遣**：DSH 本身就是命令行工具，让它直接执行脚本最省事（同 WorkBuddy 第 3 条）

### Codex

Codex 已官方支持 Skills，两种方式任选：

- **技能导入**：把 `task-catchup/skills/task-catchup` 放进 Codex 的技能目录
- **规则粘贴**：把下面这段粘进全局指令文件 `~/.codex/AGENTS.md`：

> 创建定时任务规则：Windows 计划任务必须启用"错过补跑"——PowerShell 用 `New-ScheduledTaskSettingsSet -StartWhenAvailable`；`schtasks` 必须走 `/XML` 且包含 `<StartWhenAvailable>true</StartWhenAvailable>`。Linux 用 systemd timer `Persistent=true` 或 anacron，不用裸 cron。调度时间=最早执行时间，错过（关机/休眠）后在下次开机/唤醒时立即补跑一次。

### 其他 agent（Claude Code、Cursor、Gemini CLI、GitHub Copilot 等）

- **Claude Code**：`/plugin marketplace add willings-79/task-catchup` 后 `/plugin install task-catchup@task-catchup`；或手动把 `task-catchup/skills/task-catchup` 复制到 `~/.claude/skills/task-catchup`
- **Cursor / GitHub Copilot / Gemini CLI 等**：已支持开放技能（Agent Skills）格式，把 `task-catchup/skills/task-catchup` 文件夹放进各自的技能目录即可
- **任何能在你电脑上执行命令的 agent**：用上面 WorkBuddy 第 3 条的"直接差遣"话术，或把 Codex 那段规则粘进它的指令/记忆

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

## 各家市场状态

| Agent | 市场直达 | 现状 |
|---|---|---|
| ZCode | ✅ 插件市场 Discover → **+** → GitHub 仓库 `willings-79/task-catchup` | 官方支持 GitHub 市场源，仓库根即市场清单 |
| Claude Code | ✅ `/plugin marketplace add willings-79/task-catchup` | `.claude-plugin/marketplace.json` 已就位 |
| Codex | 技能目录 / `~/.codex/AGENTS.md` 规则 | 官方 Skills 已支持；其市场收录按官方流程另走 |
| DSH | Skills 市场 | 收录按其《插件开发指南》流程申请；当前用 install.ps1 即插即用 |
| WorkBuddy | Skills 市场 | 收录按其"创建自己的 Skills"流程申请；当前用 install.ps1 即插即用 |

## 补跑时间窗（常见问题）

- **默认补一天**：只补 **24 小时内**错过的任务（防止陈旧任务开机突袭），同一错过只执行一次（守卫自动记录状态）
- **可以自定**：建任务时加 `-MaxDelayHours N`——N 小时内的错过才补（`-MaxDelayHours 48` = 两天内）；`-MaxDelayHours 0` = 不限时长、总是补最近一次
- 对话里直接说「超过一天的就不补了」（默认即是）或「不限时间，能补就补」（用 0）

## 说明与边界

- Windows 脚本部分需 PowerShell 5.1+（Win10/11 自带）；给系统级任务改设置可能要管理员权限
- Linux 部分为规则指引（systemd/anacron），脚本仅覆盖 Windows
- 应用内定时（各 agent 对话里建的 automation、WorkBuddy 的"自动化"等）只在宿主程序运行时触发，无补跑语义；需要补跑保证的任务请落到 OS 调度器
- Claude Code 安装路径按其插件生态约定提供，未在全部版本上实测

## License

MIT
