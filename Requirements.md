# OpenClaw Installer — 需求文档

## REQ-1 应用生命周期

| ID | 需求 | 状态 |
|----|------|------|
| REQ-1.1 | 应用在最后一个窗口关闭时终止 | ✅ |
| REQ-1.2 | 窗口固定 680×720，深色模式，隐藏标题栏 | ✅ |
| REQ-1.3 | InstallerViewModel 作为 `@StateObject` 创建，通过 `@EnvironmentObject` 注入 | ✅ |
| REQ-1.4 | 启动时自动运行 `detectSystem()` 系统检测 | ✅ |

## REQ-2 欢迎步骤

| ID | 需求 | 状态 |
|----|------|------|
| REQ-2.1 | 通过 `uname -m` 检测系统架构（ARM64/x86_64） | ✅ |
| REQ-2.2 | 通过 `which openclaw` 检测已安装的 OpenClaw | ✅ |
| REQ-2.3 | 根据二进制路径判断安装方式（npm/pnpm/bun/git） | ✅ |
| REQ-2.4 | 检查已有配置（`~/.openclaw/openclaw.json`）和工作区 | ✅ |
| REQ-2.5 | 支持卸载功能，可选备份（时间戳命名 `~/.openclaw-backup-*`） | ✅ |
| REQ-2.6 | 卸载清理：Gateway 服务、配置目录、CLI 二进制、Shell RC 文件、macOS App Bundle | ✅ |
| REQ-2.7 | 支持备份并重装流程（加载已有配置，跳转安装方式选择） | ✅ |

## REQ-3 安装方式选择

| ID | 需求 | 状态 |
|----|------|------|
| REQ-3.1 | 提供 npm（推荐）和 git（源码）两种安装方式 | ✅ |
| REQ-3.2 | 每种方式包含标题、描述和图标 | ✅ |

## REQ-4 依赖检查

| ID | 需求 | 状态 |
|----|------|------|
| REQ-4.1 | 核心依赖：Homebrew、Node.js v22+、Git | ✅ |
| REQ-4.2 | npm 模式额外检查 npm；git 模式额外检查 pnpm | ✅ |
| REQ-4.3 | 每个依赖通过 `which` + 版本提取进行检测 | ✅ |
| REQ-4.4 | Node.js 版本验证：主版本号必须 >= 22 | ✅ |
| REQ-4.5 | 单个依赖自动安装（Homebrew 官方脚本、Node via brew、Git via brew、pnpm via npm） | ✅ |
| REQ-4.6 | "安装全部缺失"功能按序安装，首个失败即停止 | ✅ |
| REQ-4.7 | `allDepsReady` 由所有依赖安装状态计算得出 | ✅ |

## REQ-5 安装执行

| ID | 需求 | 状态 |
|----|------|------|
| REQ-5.1 | npm 安装：`npm install -g openclaw@latest` 带流式输出 | ✅ |
| REQ-5.2 | npm 失败重试：重新配置 npm prefix 到 `~/.npm-global` 后重试 | ✅ |
| REQ-5.3 | npm 安装后：确保 CLI bin link 存在 | ✅ |
| REQ-5.4 | git 安装：克隆/拉取、`pnpm install`、`pnpm ui:build`（可选）、`pnpm build`、创建 wrapper script | ✅ |
| REQ-5.5 | 进度模拟：指数衰减趋近上限值 | ✅ |
| REQ-5.6 | 支持取消安装（`Task.isCancelled`） | ✅ |
| REQ-5.7 | Shell 配置：向 `.zshrc` 和 `.bashrc` 添加 PATH 条目 | ✅ |
| REQ-5.8 | 安装后验证：`which openclaw`、`openclaw --version` | ✅ |
| REQ-5.9 | 安装后：生成 Shell 补全脚本、创建 Agent 目录 | ✅ |

## REQ-6 配置向导（12 子步骤）

### REQ-6.1 服务商选择
| ID | 需求 | 状态 |
|----|------|------|
| REQ-6.1.1 | 支持 40+ LLM 服务商，分为 5 组（热门/国际/国内/本地部署/其它） | ✅ |
| REQ-6.1.2 | 所有服务商 ID 唯一 | ✅ |
| REQ-6.1.3 | 自定义服务商需提供 baseURL 和 modelId | ✅ |

### REQ-6.2 认证配置
| ID | 需求 | 状态 |
|----|------|------|
| REQ-6.2.1 | 支持 4 种认证方式：API Key、OAuth、Setup Token、Device Flow | ✅ |
| REQ-6.2.2 | OAuth/Device Flow 通过 CLI 流式命令执行 | ✅ |
| REQ-6.2.3 | OAuth 前如需启用插件（`requiredPlugin`），先执行 `openclaw plugins enable` | ✅ |
| REQ-6.2.4 | 切换服务商时重置认证状态 | ✅ |

### REQ-6.3 模型选择
| ID | 需求 | 状态 |
|----|------|------|
| REQ-6.3.1 | 从服务商的模型列表中选择 | ✅ |
| REQ-6.3.2 | 本地服务商支持自定义 modelId | ✅ |

### REQ-6.4 工作区
| ID | 需求 | 状态 |
|----|------|------|
| REQ-6.4.1 | 默认路径 `~/.openclaw/workspace` | ✅ |
| REQ-6.4.2 | 初始化工作区目录和 Bootstrap 文件 | ✅ |
| REQ-6.4.3 | 工作区执行 `git init` | ✅ |

### REQ-6.5 Gateway 配置
| ID | 需求 | 状态 |
|----|------|------|
| REQ-6.5.1 | 端口配置（默认 18789） | ✅ |
| REQ-6.5.2 | 绑定模式：Loopback/LAN/Auto/Custom | ✅ |
| REQ-6.5.3 | 认证模式：Token（推荐）/密码/无认证 | ✅ |
| REQ-6.5.4 | Token 生成：UUID 格式，32 位小写十六进制 | ✅ |
| REQ-6.5.5 | Tailscale 开关和退出重置选项 | ✅ |

### REQ-6.6 频道配置
| ID | 需求 | 状态 |
|----|------|------|
| REQ-6.6.1 | 支持 22 种频道类型，分为核心频道和扩展频道 | ✅ |
| REQ-6.6.2 | 每个频道有对应的配置字段（凭证输入） | ✅ |
| REQ-6.6.3 | 无频道选中时跳过频道配置子步骤 | ✅ |
| REQ-6.6.4 | 部分频道提供设置提示（如 WhatsApp 扫码） | ✅ |

### REQ-6.7 网络搜索
| ID | 需求 | 状态 |
|----|------|------|
| REQ-6.7.1 | 支持 5 个搜索供应商（Brave、Perplexity、Gemini、Grok、Kimi） | ✅ |
| REQ-6.7.2 | 每个供应商有对应的环境变量和 API Key | ✅ |

### REQ-6.8 Hooks
| ID | 需求 | 状态 |
|----|------|------|
| REQ-6.8.1 | 4 个内置 Hook（session-memory、command-logger、boot-md、bootstrap-extra-files） | ✅ |
| REQ-6.8.2 | 默认启用 session-memory 和 boot-md | ✅ |

### REQ-6.9 Skills
| ID | 需求 | 状态 |
|----|------|------|
| REQ-6.9.1 | 14 个热门 Skill，支持多种安装方式（brew/node/uv/go/无需安装） | ✅ |
| REQ-6.9.2 | 安装 Skill 依赖时显示进度日志 | ✅ |
| REQ-6.9.3 | 部分 Skill 需要环境变量（如 NOTION_API_KEY） | ✅ |

### REQ-6.10 守护进程
| ID | 需求 | 状态 |
|----|------|------|
| REQ-6.10.1 | 通过 `openclaw gateway install` 安装守护进程 | ✅ |
| REQ-6.10.2 | 安装后健康检查（5 次重试，2 秒间隔） | ✅ |
| REQ-6.10.3 | Post-startup doctor 检查 | ✅ |

### REQ-6.11 Shell 补全
| ID | 需求 | 状态 |
|----|------|------|
| REQ-6.11.1 | 通过 `openclaw completion --write-state` 和 `--install` 安装 | ✅ |

### REQ-6.12 孵化 Bot
| ID | 需求 | 状态 |
|----|------|------|
| REQ-6.12.1 | 三种模式：TUI（推荐）、Web UI、稍后 | ✅ |
| REQ-6.12.2 | TUI 通过 AppleScript 打开终端 | ✅ |
| REQ-6.12.3 | Web UI 在浏览器打开 Dashboard | ✅ |

### REQ-6.13 配置文件生成
| ID | 需求 | 状态 |
|----|------|------|
| REQ-6.13.1 | 生成 JSON 配置写入 `~/.openclaw/openclaw.json` | ✅ |
| REQ-6.13.2 | 生成 auth-profiles.json 到 `~/.openclaw/agents/main/agent/` | ✅ |
| REQ-6.13.3 | 生成 models.json 到同目录 | ✅ |
| REQ-6.13.4 | 配置包含 wizard 元数据（时间戳、版本） | ✅ |

## REQ-7 完成步骤

| ID | 需求 | 状态 |
|----|------|------|
| REQ-7.1 | 执行孵化动作（TUI/Web UI/稍后） | ✅ |
| REQ-7.2 | Dashboard 打开功能（解析 `openclaw dashboard` 输出 URL） | ✅ |

## REQ-8 配置编辑器

| ID | 需求 | 状态 |
|----|------|------|
| REQ-8.1 | 独立窗口编辑 `~/.openclaw/openclaw.json` | ✅ |
| REQ-8.2 | JSON 解析为类型化 ConfigValue 结构 | ✅ |

## REQ-9 Doctor 诊断

| ID | 需求 | 状态 |
|----|------|------|
| REQ-9.1 | 运行 `openclaw doctor` 流式诊断输出 | ✅ |
| REQ-9.2 | 运行 `openclaw doctor --fix --non-interactive` 自动修复 | ✅ |

## REQ-10 Shell 执行器

| ID | 需求 | 状态 |
|----|------|------|
| REQ-10.1 | 构建完整 PATH（Homebrew、nvm、nodenv、volta、cargo 等） | ✅ |
| REQ-10.2 | nvm 通配符解析：选择最高版本 | ✅ |
| REQ-10.3 | PATH 去重并保持顺序 | ✅ |
| REQ-10.4 | 通过 `/bin/zsh -l -c` 执行命令 | ✅ |
| REQ-10.5 | 支持额外环境变量合并 | ✅ |
| REQ-10.6 | 支持流式输出（`readabilityHandler`） | ✅ |
