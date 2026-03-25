import Foundation
import SwiftUI

enum InstallStep: Int, CaseIterable {
    case welcome = 0
    case methodSelection
    case dependencyCheck
    case installing
    case configuring
    case completion
}

enum InstallMethod: String, CaseIterable {
    case npm = "npm"
    case git = "git"

    var title: String {
        switch self {
        case .npm: return "NPM (推荐)"
        case .git: return "Git 源码"
        }
    }

    var description: String {
        switch self {
        case .npm: return "通过 npm 全局安装，简单快速，适合大多数用户"
        case .git: return "从 GitHub 克隆源码并本地编译，适合开发者"
        }
    }

    var icon: String {
        switch self {
        case .npm: return "shippingbox.fill"
        case .git: return "chevron.left.forwardslash.chevron.right"
        }
    }
}

struct DependencyStatus: Identifiable {
    let id = UUID()
    let name: String
    let command: String
    var isInstalled: Bool
    var version: String?
    var isChecking: Bool = false
    var isInstalling: Bool = false

    var icon: String {
        if isChecking || isInstalling { return "arrow.triangle.2.circlepath" }
        return isInstalled ? "checkmark.circle.fill" : "xmark.circle.fill"
    }

    var statusColor: Color {
        if isChecking || isInstalling { return .orange }
        return isInstalled ? .green : .red
    }
}

struct ExistingInstall {
    let version: String
    let path: String
    let method: String   // "npm", "pnpm", "bun", or "git"
    let hasConfig: Bool
    let hasWorkspace: Bool
}

// MARK: - Doctor Report

struct DoctorReportItem: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
    let category: DoctorReportCategory
}

enum DoctorReportCategory {
    case passed, warning, error, info
}

/// A section parsed from clack-style doctor output (◇ header + │ body lines).
struct DoctorSection {
    let title: String
    let bodyLines: [String]
}

struct DoctorReport {
    let sections: [DoctorSection]
    let passed: [DoctorReportItem]
    let warnings: [DoctorReportItem]
    let errors: [DoctorReportItem]
    let infos: [DoctorReportItem]

    var totalChecks: Int { passed.count + warnings.count + errors.count }
    var isHealthy: Bool { errors.isEmpty && warnings.isEmpty }

    private static let ansiPattern = try! NSRegularExpression(pattern: "\\x1B\\[[0-9;]*[A-Za-z]|\\[\\?25[lh]\\]")

    private static func stripAnsi(_ raw: String) -> String {
        let range = NSRange(raw.startIndex..., in: raw)
        return ansiPattern.stringByReplacingMatches(in: raw, range: range, withTemplate: "")
    }

    /// Parse raw `openclaw doctor` output lines into a structured report.
    /// The output uses clack UI format:
    ///   ◇ Section Title          — section header
    ///   │  content line           — body within a section
    ///   ├  ...                    — continuation
    ///   └  ...                    — section end
    ///   ◆  prompt?                — interactive prompt
    ///   - item                    — list bullet inside │ blocks
    static func parse(lines: [String]) -> DoctorReport {
        // 1. Split into sections by ◇/◆ headers
        var sections = [DoctorSection]()
        var currentTitle = ""
        var currentBody = [String]()

        for raw in lines {
            let line = stripAnsi(raw).trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            // New section header: ◇ or ◆
            if line.hasPrefix("◇") || line.hasPrefix("◆") || line.hasPrefix("◈") {
                // Save previous section
                if !currentTitle.isEmpty || !currentBody.isEmpty {
                    sections.append(DoctorSection(title: currentTitle, bodyLines: currentBody))
                }
                currentTitle = line
                    .replacingOccurrences(of: "◇", with: "")
                    .replacingOccurrences(of: "◆", with: "")
                    .replacingOccurrences(of: "◈", with: "")
                    .trimmingCharacters(in: .whitespaces)
                currentBody = []
                continue
            }

            // Body lines: strip leading │├└┌ and whitespace
            if line.hasPrefix("│") || line.hasPrefix("├") || line.hasPrefix("└") || line.hasPrefix("┌") {
                let content = String(line.drop(while: { "│├└┌ ".contains($0) }))
                    .trimmingCharacters(in: .whitespaces)
                if !content.isEmpty {
                    currentBody.append(content)
                }
                continue
            }

            // Other lines (no box-drawing prefix) — treat as body of current section
            if line.count > 2 {
                currentBody.append(line)
            }
        }
        // Save last section
        if !currentTitle.isEmpty || !currentBody.isEmpty {
            sections.append(DoctorSection(title: currentTitle, bodyLines: currentBody))
        }

        // 2. Classify sections into categories
        var passed = [DoctorReportItem]()
        var warnings = [DoctorReportItem]()
        var errors = [DoctorReportItem]()
        var infos = [DoctorReportItem]()

        for section in sections {
            let titleLower = section.title.lowercased()
            let bodyText = section.bodyLines.joined(separator: "\n")

            // Determine section category by title keywords
            if titleLower.contains("error") || titleLower.contains("critical") || titleLower.contains("fail") {
                let item = DoctorReportItem(
                    icon: "xmark.circle.fill",
                    text: section.title + (bodyText.isEmpty ? "" : "\n" + bodyText),
                    category: .error
                )
                errors.append(item)
            } else if titleLower.contains("warn") {
                let item = DoctorReportItem(
                    icon: "exclamationmark.triangle.fill",
                    text: section.title + (bodyText.isEmpty ? "" : "\n" + bodyText),
                    category: .warning
                )
                warnings.append(item)
            } else if titleLower.contains("✓") || titleLower.contains("pass") || titleLower.contains("ok") || titleLower.contains("success") {
                let item = DoctorReportItem(
                    icon: "checkmark.circle.fill",
                    text: section.title,
                    category: .passed
                )
                passed.append(item)
            } else if !section.title.isEmpty {
                // Check body for clues
                let bodyLower = bodyText.lowercased()
                if bodyLower.contains("error") || bodyLower.contains("fail") || bodyLower.contains("not found") || bodyLower.contains("missing") {
                    errors.append(DoctorReportItem(
                        icon: "xmark.circle.fill",
                        text: section.title + (bodyText.isEmpty ? "" : "\n" + bodyText),
                        category: .error
                    ))
                } else if bodyLower.contains("warn") || bodyLower.contains("first-time setup") || bodyLower.contains("blocked") {
                    warnings.append(DoctorReportItem(
                        icon: "exclamationmark.triangle.fill",
                        text: section.title + (bodyText.isEmpty ? "" : "\n" + bodyText),
                        category: .warning
                    ))
                } else {
                    infos.append(DoctorReportItem(
                        icon: "info.circle",
                        text: section.title + (bodyText.isEmpty ? "" : "\n" + bodyText),
                        category: .info
                    ))
                }
            }
        }

        // If nothing was classified as passed/warning/error, extract per-line items from body
        if passed.isEmpty && warnings.isEmpty && errors.isEmpty && !infos.isEmpty {
            // Re-scan all body lines for ✓/✗ markers that might appear inline
            var rePassed = [DoctorReportItem]()
            for section in sections {
                for bodyLine in section.bodyLines {
                    let lower = bodyLine.lowercased()
                    if bodyLine.contains("✓") || bodyLine.contains("✔") {
                        rePassed.append(DoctorReportItem(icon: "checkmark.circle.fill", text: bodyLine, category: .passed))
                    } else if bodyLine.contains("✗") || bodyLine.contains("✘") || lower.contains("error") {
                        errors.append(DoctorReportItem(icon: "xmark.circle.fill", text: bodyLine, category: .error))
                    }
                }
            }
            if !rePassed.isEmpty { passed = rePassed }
        }

        return DoctorReport(sections: sections, passed: passed, warnings: warnings, errors: errors, infos: infos)
    }
}

// MARK: - NPM Mirror

struct NpmMirror: Identifiable, Hashable {
    let id: String
    let name: String
    let url: String

    static let official = NpmMirror(id: "official", name: "npm 官方", url: "https://registry.npmjs.org")
    static let tencent = NpmMirror(id: "tencent", name: "腾讯云", url: "https://mirrors.cloud.tencent.com/npm/")
    static let all: [NpmMirror] = [
        .official,
        NpmMirror(id: "taobao", name: "淘宝镜像", url: "http://registry.npmmirror.com"),
        NpmMirror(id: "aliyun", name: "阿里云", url: "https://npm.aliyun.com"),
        .tencent,
        NpmMirror(id: "huawei", name: "华为云", url: "https://mirrors.huaweicloud.com/repository/npm/"),
        NpmMirror(id: "netease", name: "网易", url: "https://mirrors.163.com/npm/"),
        NpmMirror(id: "ustc", name: "中科大", url: "http://mirrors.ustc.edu.cn/"),
        NpmMirror(id: "tsinghua", name: "清华", url: "https://mirrors.tuna.tsinghua.edu.cn/"),
    ]

    /// Match a registry URL to a known mirror, or return nil
    static func from(url: String) -> NpmMirror? {
        let trimmed = url.trimmingCharacters(in: CharacterSet(charactersIn: "/ \n"))
        return all.first { mirror in
            trimmed == mirror.url.trimmingCharacters(in: CharacterSet(charactersIn: "/ \n"))
        }
    }
}

// MARK: - Onboard Wizard Step

enum OnboardStep: Int, CaseIterable {
    case providerSelect = 0
    case modelConfig
    case workspace
    case gateway
    case channels
    case channelConfig
    case webSearch
    case hooks
    case daemonFinish       // daemon install + health check
    case skills             // after daemon, matching CLI order
    case shellCompletion
    case hatchBot

    var title: String {
        switch self {
        case .providerSelect: return "选择服务商"
        case .modelConfig: return "模型配置"
        case .workspace: return "工作区"
        case .gateway: return "Gateway"
        case .channels: return "选择频道"
        case .channelConfig: return "频道配置"
        case .webSearch: return "网络搜索"
        case .hooks: return "Hooks"
        case .daemonFinish: return "服务启动"
        case .skills: return "Skills"
        case .shellCompletion: return "Shell 补全"
        case .hatchBot: return "孵化 Bot"
        }
    }

    var icon: String {
        switch self {
        case .providerSelect: return "brain.head.profile"
        case .modelConfig: return "cpu"
        case .workspace: return "folder.fill"
        case .gateway: return "network"
        case .channels: return "bubble.left.and.bubble.right.fill"
        case .channelConfig: return "key.fill"
        case .webSearch: return "magnifyingglass"
        case .hooks: return "arrow.triangle.branch"
        case .daemonFinish: return "gearshape.2.fill"
        case .skills: return "puzzlepiece.fill"
        case .shellCompletion: return "terminal"
        case .hatchBot: return "bird.fill"
        }
    }
}

// MARK: - Auth Choice

enum AuthType: String, Hashable {
    case apiKey = "api-key"
    case oauth = "oauth"
    case token = "token"
    case deviceFlow = "device-flow"
}

struct AuthChoice: Identifiable, Hashable {
    let id: String          // unique key, e.g. "minimax-global-oauth"
    let label: String       // display label
    let type: AuthType
    let icon: String
    let hint: String        // short description
    let authURL: String     // URL to open for API key console page
    let placeholder: String // placeholder for key/token input
    let cliProvider: String // CLI provider id for `openclaw models auth login --provider`
    let cliMethod: String   // CLI method id for `openclaw models auth login --method`
    let requiredPlugin: String // plugin id to enable before auth (e.g. "minimax-portal-auth")

    static func apiKey(id: String = "api-key", label: String = "API Key", placeholder: String = "API Key", authURL: String = "") -> AuthChoice {
        AuthChoice(id: id, label: label, type: .apiKey, icon: "key.fill", hint: "直接输入 API Key", authURL: authURL, placeholder: placeholder, cliProvider: "", cliMethod: "", requiredPlugin: "")
    }

    static func oauth(id: String, label: String, cliProvider: String, cliMethod: String, hint: String = "通过浏览器授权登录", requiredPlugin: String = "") -> AuthChoice {
        AuthChoice(id: id, label: label, type: .oauth, icon: "globe", hint: hint, authURL: "", placeholder: "", cliProvider: cliProvider, cliMethod: cliMethod, requiredPlugin: requiredPlugin)
    }

    static func token(id: String = "token", label: String = "Setup Token") -> AuthChoice {
        AuthChoice(id: id, label: label, type: .token, icon: "ticket.fill", hint: "粘贴 claude setup-token 生成的令牌", authURL: "", placeholder: "粘贴 token...", cliProvider: "", cliMethod: "", requiredPlugin: "")
    }

    static func device(id: String, label: String, cliProvider: String, cliMethod: String, hint: String = "在浏览器中完成设备授权", requiredPlugin: String = "") -> AuthChoice {
        AuthChoice(id: id, label: label, type: .deviceFlow, icon: "iphone.and.arrow.forward", hint: hint, authURL: "", placeholder: "", cliProvider: cliProvider, cliMethod: cliMethod, requiredPlugin: requiredPlugin)
    }
}

// MARK: - Model Provider

struct ModelProvider: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let placeholder: String
    let group: ProviderGroup
    let needsBaseURL: Bool
    let needsModelId: Bool
    let defaultModel: String
    let models: [String]
    let authChoices: [AuthChoice]

    init(id: String, title: String, description: String, icon: String, placeholder: String, group: ProviderGroup, needsBaseURL: Bool, needsModelId: Bool, defaultModel: String, models: [String] = [], authChoices: [AuthChoice]) {
        self.id = id; self.title = title; self.description = description; self.icon = icon
        self.placeholder = placeholder; self.group = group; self.needsBaseURL = needsBaseURL
        self.needsModelId = needsModelId; self.defaultModel = defaultModel
        self.models = models; self.authChoices = authChoices
    }

    enum ProviderGroup: String, CaseIterable {
        case popular = "热门"
        case global = "国际"
        case china = "国内"
        case local = "本地部署"
        case other = "其它"
    }

    static let all: [ModelProvider] = [
        // Popular
        ModelProvider(id: "anthropic", title: "Anthropic", description: "Claude 系列模型", icon: "sparkles", placeholder: "sk-ant-...", group: .popular, needsBaseURL: false, needsModelId: false, defaultModel: "anthropic/claude-sonnet-4-5-20250514", models: [
            "anthropic/claude-opus-4-6",
            "anthropic/claude-sonnet-4-6",
            "anthropic/claude-sonnet-4-5-20250514",
            "anthropic/claude-haiku-4-5-20251001",
        ], authChoices: [
            .apiKey(placeholder: "sk-ant-...", authURL: "https://console.anthropic.com/settings/keys"),
            .token(),
        ]),
        ModelProvider(id: "openai", title: "OpenAI", description: "GPT-4o / Codex 等模型", icon: "brain.head.profile", placeholder: "sk-...", group: .popular, needsBaseURL: false, needsModelId: false, defaultModel: "openai/gpt-4o", models: [
            "openai/gpt-4o",
            "openai/gpt-4o-mini",
            "openai/o3",
            "openai/o3-mini",
            "openai/o4-mini",
            "openai/gpt-4.1",
            "openai/gpt-4.1-mini",
        ], authChoices: [
            .apiKey(placeholder: "sk-...", authURL: "https://platform.openai.com/api-keys"),
        ]),
        ModelProvider(id: "gemini", title: "Google Gemini", description: "Gemini 系列模型", icon: "globe", placeholder: "API Key", group: .popular, needsBaseURL: false, needsModelId: false, defaultModel: "gemini/gemini-2.5-pro", models: [
            "gemini/gemini-2.5-pro",
            "gemini/gemini-2.5-flash",
            "gemini/gemini-2.0-flash",
        ], authChoices: [
            .apiKey(label: "Gemini API Key", placeholder: "API Key", authURL: "https://aistudio.google.com/apikey"),
            .oauth(id: "google-gemini-cli", label: "Gemini CLI OAuth", cliProvider: "google-gemini-cli", cliMethod: "oauth", hint: "通过 Google 账号 OAuth 登录", requiredPlugin: "google-gemini-cli-auth"),
        ]),
        ModelProvider(id: "openrouter", title: "OpenRouter", description: "多模型聚合路由", icon: "arrow.triangle.branch", placeholder: "sk-or-...", group: .popular, needsBaseURL: false, needsModelId: false, defaultModel: "openrouter/anthropic/claude-sonnet-4-5", authChoices: [
            .apiKey(placeholder: "sk-or-..."),
        ]),

        // Global
        ModelProvider(id: "mistral", title: "Mistral", description: "Mistral AI 模型", icon: "wind", placeholder: "API Key", group: .global, needsBaseURL: false, needsModelId: false, defaultModel: "mistral/mistral-large-latest", models: [
            "mistral/mistral-large-latest",
            "mistral/codestral-latest",
            "mistral/mistral-small-latest",
        ], authChoices: [.apiKey()]),
        ModelProvider(id: "xai", title: "xAI (Grok)", description: "Grok 系列模型", icon: "bolt.fill", placeholder: "API Key", group: .global, needsBaseURL: false, needsModelId: false, defaultModel: "xai/grok-3", models: [
            "xai/grok-3",
            "xai/grok-3-mini",
        ], authChoices: [.apiKey()]),
        ModelProvider(id: "together", title: "Together AI", description: "开源模型托管", icon: "square.stack.3d.up", placeholder: "API Key", group: .global, needsBaseURL: false, needsModelId: false, defaultModel: "", authChoices: [.apiKey()]),
        ModelProvider(id: "huggingface", title: "Hugging Face", description: "HF Inference API", icon: "face.smiling", placeholder: "hf_...", group: .global, needsBaseURL: false, needsModelId: false, defaultModel: "", authChoices: [.apiKey(placeholder: "hf_...")]),
        ModelProvider(id: "venice", title: "Venice AI", description: "隐私优先 AI 平台", icon: "lock.fill", placeholder: "API Key", group: .global, needsBaseURL: false, needsModelId: false, defaultModel: "", authChoices: [.apiKey()]),
        ModelProvider(id: "kilocode", title: "Kilo Gateway", description: "Kilo 代码网关", icon: "chevron.left.forwardslash.chevron.right", placeholder: "API Key", group: .global, needsBaseURL: false, needsModelId: false, defaultModel: "", authChoices: [.apiKey()]),
        ModelProvider(id: "litellm", title: "LiteLLM", description: "LLM 代理网关", icon: "arrow.left.arrow.right", placeholder: "API Key", group: .global, needsBaseURL: false, needsModelId: false, defaultModel: "", authChoices: [.apiKey()]),
        ModelProvider(id: "cloudflare", title: "Cloudflare AI Gateway", description: "Cloudflare AI 网关", icon: "cloud.fill", placeholder: "API Key", group: .global, needsBaseURL: false, needsModelId: false, defaultModel: "", authChoices: [.apiKey()]),
        ModelProvider(id: "ai-gateway", title: "Vercel AI Gateway", description: "Vercel AI 网关", icon: "triangle.fill", placeholder: "API Key", group: .global, needsBaseURL: false, needsModelId: false, defaultModel: "", authChoices: [.apiKey()]),
        ModelProvider(id: "synthetic", title: "Synthetic", description: "Synthetic API", icon: "waveform", placeholder: "API Key", group: .global, needsBaseURL: false, needsModelId: false, defaultModel: "", authChoices: [.apiKey()]),
        ModelProvider(id: "github-copilot", title: "GitHub Copilot", description: "通过 Copilot 代理", icon: "chevron.left.forwardslash.chevron.right", placeholder: "", group: .global, needsBaseURL: false, needsModelId: false, defaultModel: "", authChoices: [
            .device(id: "github-copilot", label: "GitHub 设备授权", cliProvider: "copilot-proxy", cliMethod: "device", hint: "需要有效的 GitHub Copilot 订阅", requiredPlugin: "copilot-proxy"),
        ]),
        ModelProvider(id: "chutes", title: "Chutes", description: "Chutes AI 平台", icon: "bolt.horizontal.fill", placeholder: "", group: .global, needsBaseURL: false, needsModelId: false, defaultModel: "", authChoices: [
            .apiKey(id: "chutes-api", label: "Chutes API Key", placeholder: "API Key", authURL: "https://chutes.ai/app/api-keys"),
        ]),

        // China
        ModelProvider(id: "moonshot", title: "Moonshot (月之暗面)", description: "Kimi 系列模型", icon: "moon.fill", placeholder: "API Key", group: .china, needsBaseURL: false, needsModelId: false, defaultModel: "moonshot/moonshot-v1-auto", authChoices: [.apiKey()]),
        ModelProvider(id: "kimi-code", title: "Kimi Coding", description: "Kimi 编程专用", icon: "moon.stars.fill", placeholder: "API Key", group: .china, needsBaseURL: false, needsModelId: false, defaultModel: "kimi-code/kimi-coder", authChoices: [.apiKey()]),
        ModelProvider(id: "qianfan", title: "百度千帆", description: "文心一言等模型", icon: "cloud.sun.fill", placeholder: "API Key", group: .china, needsBaseURL: false, needsModelId: false, defaultModel: "", authChoices: [.apiKey()]),
        ModelProvider(id: "modelstudio-cn", title: "阿里云百炼 (国内)", description: "通义千问等模型", icon: "cpu", placeholder: "API Key", group: .china, needsBaseURL: false, needsModelId: false, defaultModel: "modelstudio-cn/qwen-max", authChoices: [.apiKey()]),
        ModelProvider(id: "modelstudio", title: "阿里云百炼 (国际)", description: "Alibaba Model Studio", icon: "cpu", placeholder: "API Key", group: .china, needsBaseURL: false, needsModelId: false, defaultModel: "modelstudio/qwen-max", authChoices: [.apiKey()]),
        ModelProvider(id: "volcengine", title: "火山引擎", description: "豆包等模型", icon: "flame.fill", placeholder: "API Key", group: .china, needsBaseURL: false, needsModelId: false, defaultModel: "", authChoices: [.apiKey()]),
        ModelProvider(id: "byteplus", title: "BytePlus", description: "字节跳动国际版", icon: "flame", placeholder: "API Key", group: .china, needsBaseURL: false, needsModelId: false, defaultModel: "", authChoices: [.apiKey()]),
        ModelProvider(id: "zai", title: "Z.AI", description: "Z.AI 平台", icon: "z.circle.fill", placeholder: "API Key", group: .china, needsBaseURL: false, needsModelId: false, defaultModel: "zai/glm-5", authChoices: [.apiKey()]),
        ModelProvider(id: "xiaomi", title: "小米", description: "小米大模型", icon: "antenna.radiowaves.left.and.right", placeholder: "API Key", group: .china, needsBaseURL: false, needsModelId: false, defaultModel: "", authChoices: [.apiKey()]),
        ModelProvider(id: "minimax", title: "MiniMax", description: "MiniMax 海螺 AI", icon: "m.circle.fill", placeholder: "API Key", group: .china, needsBaseURL: false, needsModelId: false, defaultModel: "minimax-portal/MiniMax-M2.5", models: [
            "minimax-portal/MiniMax-M2.5",
            "minimax-portal/MiniMax-M2.5-highspeed",
            "minimax-portal/MiniMax-M2.5-Lightning",
        ], authChoices: [
            .oauth(id: "minimax-global-oauth", label: "Global — OAuth (minimax.io)", cliProvider: "minimax-portal", cliMethod: "oauth", hint: "Global 端点 — 通过浏览器 OAuth 授权", requiredPlugin: "minimax-portal-auth"),
            .apiKey(id: "minimax-global-api", label: "Global — API Key (minimax.io)", placeholder: "sk-api-... / sk-cp-...", authURL: "https://www.minimax.io/platform/api/key-management"),
            .oauth(id: "minimax-cn-oauth", label: "CN — OAuth (minimaxi.com)", cliProvider: "minimax-portal", cliMethod: "oauth-cn", hint: "CN 端点 — 通过浏览器 OAuth 授权", requiredPlugin: "minimax-portal-auth"),
            .apiKey(id: "minimax-cn-api", label: "CN — API Key (minimaxi.com)", placeholder: "sk-api-... / sk-cp-...", authURL: "https://www.minimaxi.com/platform/api/key-management"),
        ]),
        ModelProvider(id: "qwen-portal", title: "通义千问 (Portal)", description: "阿里通义千问", icon: "cpu.fill", placeholder: "", group: .china, needsBaseURL: false, needsModelId: false, defaultModel: "qwen-portal/coder-model", authChoices: [
            .device(id: "qwen-portal", label: "设备授权登录", cliProvider: "qwen-portal", cliMethod: "device", hint: "通过通义千问设备授权流程登录", requiredPlugin: "qwen-portal-auth"),
        ]),

        // Local
        ModelProvider(id: "ollama", title: "Ollama", description: "本地运行开源模型", icon: "desktopcomputer", placeholder: "", group: .local, needsBaseURL: false, needsModelId: true, defaultModel: "", authChoices: []),
        ModelProvider(id: "vllm", title: "vLLM", description: "高性能本地推理", icon: "bolt.circle.fill", placeholder: "", group: .local, needsBaseURL: true, needsModelId: true, defaultModel: "", authChoices: []),
        ModelProvider(id: "sglang", title: "SGLang", description: "SGLang 推理框架", icon: "chart.bar.fill", placeholder: "", group: .local, needsBaseURL: true, needsModelId: true, defaultModel: "", authChoices: []),

        // Other
        ModelProvider(id: "opencode-zen", title: "OpenCode (Zen)", description: "OpenCode Zen 目录", icon: "leaf.fill", placeholder: "API Key", group: .other, needsBaseURL: false, needsModelId: false, defaultModel: "", authChoices: [.apiKey()]),
        ModelProvider(id: "opencode-go", title: "OpenCode (Go)", description: "OpenCode Go 目录", icon: "hare.fill", placeholder: "API Key", group: .other, needsBaseURL: false, needsModelId: false, defaultModel: "", authChoices: [.apiKey()]),
        ModelProvider(id: "custom", title: "自定义服务商", description: "兼容 OpenAI/Anthropic API", icon: "server.rack", placeholder: "API Key", group: .other, needsBaseURL: true, needsModelId: true, defaultModel: "", authChoices: [.apiKey()]),
    ]

    static func providers(in group: ProviderGroup) -> [ModelProvider] {
        all.filter { $0.group == group }
    }
}

// MARK: - Gateway Auth

enum GatewayAuthMode: String, CaseIterable {
    case token = "token"
    case password = "password"
    case none = "none"

    var title: String {
        switch self {
        case .token: return "Token（推荐）"
        case .password: return "密码"
        case .none: return "无认证"
        }
    }
}

// MARK: - Gateway Bind Mode

enum GatewayBindMode: String, CaseIterable {
    case loopback = "loopback"
    case lan = "lan"
    case auto = "auto"
    case custom = "custom"

    var title: String {
        switch self {
        case .loopback: return "仅本机 (Loopback)"
        case .lan: return "局域网 (LAN)"
        case .auto: return "自动 (Loopback → LAN)"
        case .custom: return "自定义 IP"
        }
    }

    var subtitle: String {
        switch self {
        case .loopback: return "推荐 — 仅允许本机访问，最安全"
        case .lan: return "允许局域网设备连接，需确保网络安全"
        case .auto: return "优先本机，回退到局域网"
        case .custom: return "绑定到指定 IP 地址"
        }
    }
}

// MARK: - Channel Types

enum ChannelGroup: String, CaseIterable {
    case core = "核心频道"
    case plugin = "扩展频道"
}

enum ChannelType: String, CaseIterable, Identifiable {
    case telegram = "telegram"
    case whatsapp = "whatsapp"
    case discord = "discord"
    case irc = "irc"
    case googlechat = "googlechat"
    case slack = "slack"
    case signal = "signal"
    case imessage = "imessage"
    case line = "line"
    case bluebubbles = "bluebubbles"
    case mattermost = "mattermost"
    case matrix = "matrix"
    case msteams = "msteams"
    case nextcloudTalk = "nextcloud-talk"
    case nostr = "nostr"
    case synologyChat = "synology-chat"
    case tlon = "tlon"
    case twitch = "twitch"
    case zalo = "zalo"
    case zalouser = "zalouser"
    case feishu = "feishu"
    case webchat = "webchat"

    var id: String { rawValue }

    var group: ChannelGroup {
        switch self {
        case .telegram, .whatsapp, .discord, .irc, .googlechat,
             .slack, .signal, .imessage, .line:
            return .core
        default:
            return .plugin
        }
    }

    var title: String {
        switch self {
        case .whatsapp: return "WhatsApp"
        case .telegram: return "Telegram"
        case .discord: return "Discord"
        case .slack: return "Slack"
        case .signal: return "Signal"
        case .imessage: return "iMessage"
        case .googlechat: return "Google Chat"
        case .mattermost: return "Mattermost"
        case .bluebubbles: return "BlueBubbles"
        case .irc: return "IRC"
        case .line: return "LINE"
        case .matrix: return "Matrix"
        case .msteams: return "MS Teams"
        case .nextcloudTalk: return "Nextcloud Talk"
        case .nostr: return "Nostr"
        case .synologyChat: return "Synology Chat"
        case .tlon: return "Tlon"
        case .twitch: return "Twitch"
        case .zalo: return "Zalo"
        case .zalouser: return "Zalo 个人"
        case .feishu: return "飞书"
        case .webchat: return "WebChat"
        }
    }

    var icon: String {
        switch self {
        case .whatsapp: return "phone.bubble.fill"
        case .telegram: return "paperplane.fill"
        case .discord: return "gamecontroller.fill"
        case .slack: return "number"
        case .signal: return "lock.shield.fill"
        case .imessage: return "message.fill"
        case .googlechat: return "bubble.left.and.bubble.right.fill"
        case .mattermost: return "ellipsis.message.fill"
        case .bluebubbles: return "bubble.fill"
        case .irc: return "terminal.fill"
        case .line: return "ellipsis.bubble.fill"
        case .matrix: return "square.grid.3x3.fill"
        case .msteams: return "person.3.fill"
        case .nextcloudTalk: return "cloud.fill"
        case .nostr: return "antenna.radiowaves.left.and.right"
        case .synologyChat: return "server.rack"
        case .tlon: return "globe"
        case .twitch: return "play.tv.fill"
        case .zalo: return "bolt.bubble.fill"
        case .zalouser: return "person.bubble.fill"
        case .feishu: return "bird.fill"
        case .webchat: return "globe"
        }
    }
}

// MARK: - Channel Config Fields

struct ChannelField: Identifiable {
    let id: String       // key name (e.g. "botToken")
    let label: String
    let placeholder: String
    let sensitive: Bool
    let hint: String

    init(_ id: String, label: String, placeholder: String = "", sensitive: Bool = false, hint: String = "") {
        self.id = id; self.label = label; self.placeholder = placeholder; self.sensitive = sensitive; self.hint = hint
    }
}

extension ChannelType {
    /// Required / recommended fields for onboarding each channel.
    var configFields: [ChannelField] {
        switch self {
        case .telegram:
            return [
                ChannelField("botToken", label: "Bot Token", placeholder: "123456:ABC-DEF...", sensitive: true, hint: "从 @BotFather 获取"),
            ]
        case .discord:
            return [
                ChannelField("token", label: "Bot Token", placeholder: "MTA4...", sensitive: true, hint: "从 Discord Developer Portal 获取"),
            ]
        case .whatsapp:
            return [] // QR code pairing, no fields needed in wizard
        case .slack:
            return [
                ChannelField("botToken", label: "Bot Token", placeholder: "xoxb-...", sensitive: true, hint: "Bot User OAuth Token"),
                ChannelField("appToken", label: "App Token", placeholder: "xapp-...", sensitive: true, hint: "Socket Mode 需要；HTTP Mode 留空"),
            ]
        case .signal:
            return [
                ChannelField("account", label: "手机号码", placeholder: "+8613800138000", hint: "E.164 格式"),
            ]
        case .googlechat:
            return [
                ChannelField("serviceAccountFile", label: "Service Account JSON 路径", placeholder: "~/.openclaw/credentials/googlechat.json", hint: "GCP 服务账号密钥文件"),
            ]
        case .mattermost:
            return [
                ChannelField("botToken", label: "Bot Token", sensitive: true, hint: "Mattermost Bot Access Token"),
                ChannelField("baseUrl", label: "服务器 URL", placeholder: "https://chat.example.com", hint: "Mattermost 实例地址"),
            ]
        case .bluebubbles:
            return [
                ChannelField("serverUrl", label: "服务器 URL", placeholder: "http://192.168.1.100:1234", hint: "BlueBubbles REST API 地址"),
                ChannelField("password", label: "API 密码", sensitive: true),
            ]
        case .imessage:
            return [
                ChannelField("cliPath", label: "imsg CLI 路径", placeholder: "/usr/local/bin/imsg", hint: "推荐改用 BlueBubbles"),
                ChannelField("dbPath", label: "Messages DB 路径", placeholder: "~/Library/Messages/chat.db"),
            ]
        case .irc:
            return [
                ChannelField("host", label: "服务器", placeholder: "irc.libera.chat"),
                ChannelField("nick", label: "昵称", placeholder: "openclaw-bot"),
            ]
        case .matrix:
            return [
                ChannelField("homeserver", label: "Homeserver URL", placeholder: "https://matrix.example.org"),
                ChannelField("accessToken", label: "Access Token", sensitive: true),
            ]
        case .msteams:
            return [
                ChannelField("appId", label: "Azure App ID", placeholder: "xxxxxxxx-xxxx-..."),
                ChannelField("appPassword", label: "Client Secret", sensitive: true),
                ChannelField("tenantId", label: "Tenant ID", placeholder: "xxxxxxxx-xxxx-..."),
            ]
        case .line:
            return [
                ChannelField("channelAccessToken", label: "Channel Access Token", sensitive: true),
                ChannelField("channelSecret", label: "Channel Secret", sensitive: true),
            ]
        case .feishu:
            return [
                ChannelField("appId", label: "App ID", placeholder: "cli_xxx"),
                ChannelField("appSecret", label: "App Secret", sensitive: true),
            ]
        case .nostr:
            return [
                ChannelField("privateKey", label: "Private Key", placeholder: "nsec1...", sensitive: true),
            ]
        case .zalo:
            return [
                ChannelField("botToken", label: "Bot Token", placeholder: "12345689:abc-xyz", sensitive: true),
            ]
        case .nextcloudTalk:
            return [
                ChannelField("baseUrl", label: "Nextcloud URL", placeholder: "https://cloud.example.com"),
                ChannelField("botSecret", label: "Bot Secret", sensitive: true),
            ]
        case .synologyChat:
            return [
                ChannelField("token", label: "Outgoing Webhook Token", sensitive: true),
                ChannelField("incomingUrl", label: "Incoming Webhook URL", placeholder: "https://nas.example.com/..."),
            ]
        default:
            return []
        }
    }

    /// Human-readable setup hint shown when there are no inline fields (e.g. WhatsApp).
    var setupHint: String? {
        switch self {
        case .whatsapp: return "安装后运行 openclaw channels login --channel whatsapp 扫描 QR 码完成配对"
        case .zalouser: return "安装后运行 openclaw channels login --channel zalouser 扫码登录"
        case .tlon: return "安装后通过 openclaw configure 配置 Tlon 频道"
        case .twitch: return "安装后通过 openclaw configure 配置 Twitch 频道"
        case .webchat: return "WebChat 无需额外配置，通过 Control UI 直接使用"
        default: return nil
        }
    }
}

// MARK: - Web Search Provider

struct WebSearchProvider: Identifiable {
    let id: String
    let title: String
    let icon: String
    let envKey: String
    let placeholder: String

    static let all: [WebSearchProvider] = [
        WebSearchProvider(id: "brave", title: "Brave Search", icon: "shield.fill", envKey: "BRAVE_SEARCH_API_KEY", placeholder: "BSA..."),
        WebSearchProvider(id: "perplexity", title: "Perplexity", icon: "sparkles", envKey: "PERPLEXITY_API_KEY", placeholder: "pplx-..."),
        WebSearchProvider(id: "gemini", title: "Gemini Grounding", icon: "globe", envKey: "GEMINI_API_KEY", placeholder: "API Key"),
        WebSearchProvider(id: "grok", title: "Grok Search", icon: "bolt.fill", envKey: "GROK_API_KEY", placeholder: "API Key"),
        WebSearchProvider(id: "kimi", title: "Kimi Search", icon: "moon.fill", envKey: "KIMI_API_KEY", placeholder: "API Key"),
    ]
}

// MARK: - Bundled Hooks

struct BundledHook: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String

    static let all: [BundledHook] = [
        BundledHook(id: "session-memory", title: "Session Memory", description: "自动将会话摘要写入 memory/ 目录", icon: "brain"),
        BundledHook(id: "command-logger", title: "Command Logger", description: "记录所有执行的命令到日志文件", icon: "doc.text"),
        BundledHook(id: "boot-md", title: "Boot MD", description: "启动时自动加载 BOOT.md 指令文件", icon: "doc.richtext"),
        BundledHook(id: "bootstrap-extra-files", title: "Bootstrap Extra Files", description: "首次启动时生成额外的工作区文件", icon: "folder.badge.plus"),
    ]
}

// MARK: - Bundled Skills

enum SkillInstallKind: String {
    case brew
    case node
    case uv
    case go
    case none  // no install needed or built-in
}

struct BundledSkill: Identifiable {
    let id: String
    let title: String
    let description: String
    let emoji: String
    let requiredBins: [String]
    let requiredEnv: [String]
    let primaryEnv: String?        // main env var to prompt for
    let installKind: SkillInstallKind
    let installLabel: String       // e.g. "brew install gh"

    static let popular: [BundledSkill] = [
        BundledSkill(id: "github", title: "GitHub", description: "通过 gh CLI 操作 Issues、PR、CI", emoji: "🐙", requiredBins: ["gh"], requiredEnv: [], primaryEnv: nil, installKind: .brew, installLabel: "brew install gh"),
        BundledSkill(id: "slack", title: "Slack", description: "控制 Slack 消息、频道和反应", emoji: "💬", requiredBins: [], requiredEnv: [], primaryEnv: nil, installKind: .none, installLabel: ""),
        BundledSkill(id: "notion", title: "Notion", description: "通过 Notion API 管理页面和数据库", emoji: "📝", requiredBins: [], requiredEnv: ["NOTION_API_KEY"], primaryEnv: "NOTION_API_KEY", installKind: .none, installLabel: ""),
        BundledSkill(id: "obsidian", title: "Obsidian", description: "操作 Obsidian 笔记库", emoji: "💎", requiredBins: ["obsidian-cli"], requiredEnv: [], primaryEnv: nil, installKind: .brew, installLabel: "brew install obsidian-cli"),
        BundledSkill(id: "tmux", title: "tmux", description: "远程控制 tmux 会话", emoji: "🧵", requiredBins: ["tmux"], requiredEnv: [], primaryEnv: nil, installKind: .brew, installLabel: "brew install tmux"),
        BundledSkill(id: "nano-pdf", title: "nano-pdf", description: "自然语言编辑 PDF 文件", emoji: "📄", requiredBins: ["nano-pdf"], requiredEnv: [], primaryEnv: nil, installKind: .uv, installLabel: "uv tool install nano-pdf"),
        BundledSkill(id: "summarize", title: "Summarize", description: "从 URL 或文件中提取摘要和转录", emoji: "🧾", requiredBins: ["summarize"], requiredEnv: [], primaryEnv: nil, installKind: .brew, installLabel: "brew install summarize"),
        BundledSkill(id: "openai-image-gen", title: "OpenAI 图像生成", description: "通过 OpenAI API 批量生成图片", emoji: "🎨", requiredBins: ["python3"], requiredEnv: ["OPENAI_API_KEY"], primaryEnv: "OPENAI_API_KEY", installKind: .none, installLabel: ""),
        BundledSkill(id: "weather", title: "天气", description: "查询天气和预报（无需 API Key）", emoji: "☔", requiredBins: ["curl"], requiredEnv: [], primaryEnv: nil, installKind: .none, installLabel: ""),
        BundledSkill(id: "himalaya", title: "Himalaya", description: "通过 IMAP/SMTP 管理邮件", emoji: "📧", requiredBins: ["himalaya"], requiredEnv: [], primaryEnv: nil, installKind: .brew, installLabel: "brew install himalaya"),
        BundledSkill(id: "trello", title: "Trello", description: "管理 Trello 看板、列表和卡片", emoji: "📋", requiredBins: ["jq"], requiredEnv: ["TRELLO_API_KEY", "TRELLO_TOKEN"], primaryEnv: "TRELLO_API_KEY", installKind: .brew, installLabel: "brew install jq"),
        BundledSkill(id: "session-logs", title: "Session Logs", description: "搜索和分析历史会话日志", emoji: "📜", requiredBins: ["jq", "rg"], requiredEnv: [], primaryEnv: nil, installKind: .brew, installLabel: "brew install jq ripgrep"),
        BundledSkill(id: "coding-agent", title: "Coding Agent", description: "将编程任务委托给 Codex/Claude Code", emoji: "🧩", requiredBins: [], requiredEnv: [], primaryEnv: nil, installKind: .none, installLabel: ""),
        BundledSkill(id: "canvas", title: "Canvas", description: "在连接的设备上显示 HTML 内容", emoji: "🖼️", requiredBins: [], requiredEnv: [], primaryEnv: nil, installKind: .none, installLabel: ""),
    ]
}

// MARK: - Hatch Mode

enum HatchMode: String, CaseIterable {
    case tui = "tui"
    case webUI = "web"
    case later = "later"

    var title: String {
        switch self {
        case .tui: return "在终端中孵化（推荐）"
        case .webUI: return "打开 Web UI"
        case .later: return "稍后再说"
        }
    }

    var subtitle: String {
        switch self {
        case .tui: return "启动 TUI 开始你的第一次对话，触发 Bootstrap 仪式"
        case .webUI: return "在浏览器中打开 Control UI Dashboard"
        case .later: return "跳过首次启动，之后手动运行 openclaw dashboard"
        }
    }

    var icon: String {
        switch self {
        case .tui: return "terminal.fill"
        case .webUI: return "globe"
        case .later: return "clock"
        }
    }
}

// MARK: - ViewModel

@MainActor
class InstallerViewModel: ObservableObject {
    @Published var currentStep: InstallStep = .welcome
    @Published var selectedMethod: InstallMethod = .npm
    @Published var dependencies: [DependencyStatus] = []
    @Published var installLog: [String] = []
    @Published var installProgress: Double = 0
    @Published var isInstalling = false
    @Published var installSucceeded = false
    @Published var installCancelled = false
    @Published var installError: String?
    @Published var systemArch: String = ""
    @Published var isCheckingDeps = false
    @Published var allDepsReady = false
    @Published var selectedNpmMirror: NpmMirror = .tencent

    // MARK: - Existing Install Detection
    @Published var existingInstall: ExistingInstall?
    @Published var isDetecting = false
    @Published var backupConfig = true
    @Published var isUninstalling = false
    @Published var uninstallComplete = false
    @Published var lastBackupPath: String?
    @Published var showConfigEditor = false

    // MARK: - Onboard Wizard State
    @Published var onboardStep: OnboardStep = .providerSelect

    // Step 1: Model & Auth
    @Published var selectedProvider: ModelProvider = ModelProvider.all[0]
    @Published var selectedAuthChoice: AuthChoice = .apiKey()
    @Published var apiKey: String = ""
    @Published var setupToken: String = ""     // Anthropic setup-token
    @Published var oauthInProgress: Bool = false
    @Published var oauthSuccess: Bool = false
    @Published var oauthError: String?
    @Published var oauthLog: [String] = []
    @Published var selectedModel: String = ""   // e.g. "anthropic/claude-sonnet-4-5-20250514"
    @Published var customBaseURL: String = ""
    @Published var customModelId: String = ""

    // Step 2: Workspace
    @Published var workspacePath: String = "~/.openclaw/workspace"

    // Step 3: Gateway
    @Published var gatewayPort: String = "18789"
    @Published var gatewayBindMode: GatewayBindMode = .loopback
    @Published var gatewayCustomBindHost: String = ""
    @Published var gatewayAuthMode: GatewayAuthMode = .token
    @Published var gatewayToken: String = ""
    @Published var gatewayPassword: String = ""

    // Tailscale
    @Published var tailscaleEnabled: Bool = false
    @Published var tailscaleResetOnExit: Bool = false

    // Step 4 & 5: Channels
    @Published var selectedChannels: Set<ChannelType> = []
    /// Per-channel credential values: channelCredentials["telegram"]["botToken"] = "123:ABC"
    @Published var channelCredentials: [String: [String: String]] = [:]

    // Step 6: Web Search
    @Published var selectedWebSearchProvider: String = ""  // empty = skip
    @Published var webSearchApiKey: String = ""

    // Step 7: Skills
    @Published var skillsNodeManager: String = "npm"  // "npm" or "pnpm" or "bun"
    @Published var enableSkills: Bool = true
    @Published var selectedSkills: Set<String> = Set(["github", "weather", "coding-agent", "canvas", "session-logs"])
    @Published var skillEnvVars: [String: String] = [:]  // env var name -> value
    @Published var skillsInstalling: Bool = false
    @Published var skillsInstallLog: [String] = []

    // Step 8: Hooks
    @Published var enabledHooks: Set<String> = Set(["session-memory", "boot-md"])

    // Step 9: Daemon & Finish
    @Published var installDaemon: Bool = true

    // Step 10: Shell Completion
    @Published var installShellCompletion: Bool = true

    // Step 11: Hatch Bot
    @Published var hatchMode: HatchMode = .tui

    // Onboarding execution state
    @Published var isOnboarding = false
    @Published var onboardingComplete = false
    @Published var onboardingError: String?
    @Published var onboardingLog: [String] = []

    // Doctor
    @Published var showDoctor = false
    @Published var doctorRunning = false
    @Published var doctorOutput: [String] = []
    @Published var doctorExitCode: Int32 = 0
    @Published var doctorFixRunning = false
    @Published var doctorFixOutput: [String] = []
    @Published var doctorFixExitCode: Int32 = 0
    @Published var doctorFixDone = false
    @Published var doctorReport: DoctorReport?
    private var doctorHandle: StreamingHandle?
    private var doctorFixHandle: StreamingHandle?

    let shell: ShellExecuting

    init(shell: ShellExecuting = ShellExecutor.shared) {
        self.shell = shell
    }
    private var installTask: Task<Void, Never>?
    private var progressTimer: Task<Void, Never>?

    let taglines = [
        "Automate everything, regret nothing.",
        "Your CLI, your rules.",
        "Ship it before coffee gets cold.",
        "One command to rule them all.",
        "Because copy-paste is not a strategy.",
        "Making terminals feel like home.",
    ]

    var randomTagline: String {
        taglines.randomElement() ?? taglines[0]
    }

    func detectSystem() async {
        isDetecting = true
        let archResult = await shell.run("uname -m")
        systemArch = archResult.output

        // Check for existing installation
        let whichResult = await shell.run("which openclaw 2>/dev/null || echo ''")
        let path = whichResult.output

        if !path.isEmpty {
            let verResult = await shell.run("openclaw --version 2>/dev/null || echo ''")
            let version = verResult.output.isEmpty ? "未知" : verResult.output

            // Determine install method
            var method = "npm"
            if path.contains(".local/bin") {
                method = "git"
            } else if path.contains("pnpm") || path.contains(".pnpm") {
                method = "pnpm"
            } else if path.contains(".bun") {
                method = "bun"
            }

            // Check config exists
            let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
            let configExists = FileManager.default.fileExists(atPath: "\(homeDir)/.openclaw/openclaw.json")
            let workspaceExists = FileManager.default.fileExists(atPath: "\(homeDir)/.openclaw/workspace")

            existingInstall = ExistingInstall(
                version: version,
                path: path,
                method: method,
                hasConfig: configExists,
                hasWorkspace: workspaceExists
            )
        }

        isDetecting = false
    }

    func backupAndReinstall() {
        Task {
            // Load existing config values so the user can review/modify them
            await loadExistingConfig()
            // Go straight to method selection → install → configure (with pre-filled values)
            goToStep(.methodSelection)
        }
    }

    /// Load existing ~/.openclaw/openclaw.json into ViewModel properties
    /// so the configure step shows pre-filled values from the previous install.
    func loadExistingConfig() async {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let configFile = "\(homeDir)/.openclaw/openclaw.json"

        guard FileManager.default.fileExists(atPath: configFile),
              let data = FileManager.default.contents(atPath: configFile),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        await MainActor.run {
            // agents.defaults
            if let agents = json["agents"] as? [String: Any],
               let defaults = agents["defaults"] as? [String: Any] {
                if let workspace = defaults["workspace"] as? String {
                    workspacePath = workspace.replacingOccurrences(of: homeDir, with: "~")
                }
                if let model = defaults["model"] as? [String: Any],
                   let primary = model["primary"] as? String {
                    // Try to match provider by model prefix
                    let matched = ModelProvider.all.first { p in
                        p.models.contains(primary) || primary.hasPrefix(p.id)
                    }
                    if let matched = matched {
                        selectedProvider = matched
                        selectedModel = primary
                    } else {
                        customModelId = primary
                    }
                }
            }

            // gateway
            if let gateway = json["gateway"] as? [String: Any] {
                if let port = gateway["port"] as? Int {
                    gatewayPort = String(port)
                }
                if let bind = gateway["bind"] as? String,
                   let mode = GatewayBindMode(rawValue: bind) {
                    gatewayBindMode = mode
                }
                if let customHost = gateway["customBindHost"] as? String {
                    gatewayCustomBindHost = customHost
                }
                if let auth = gateway["auth"] as? [String: Any] {
                    if let mode = auth["mode"] as? String,
                       let authMode = GatewayAuthMode(rawValue: mode) {
                        gatewayAuthMode = authMode
                    }
                    if let token = auth["token"] as? String {
                        gatewayToken = token
                    }
                    if let password = auth["password"] as? String {
                        gatewayPassword = password
                    }
                }
                if let ts = gateway["tailscale"] as? [String: Any] {
                    if let mode = ts["mode"] as? String {
                        tailscaleEnabled = (mode == "enabled")
                    }
                    if let reset = ts["resetOnExit"] as? Bool {
                        tailscaleResetOnExit = reset
                    }
                }
            }

            // web search
            if let web = json["web"] as? [String: Any],
               let search = web["search"] as? [String: Any],
               let provider = search["provider"] as? String {
                selectedWebSearchProvider = provider
            }

            // channels
            if let channels = json["channels"] as? [String: Any] {
                var loaded: Set<ChannelType> = []
                for (key, _) in channels {
                    if let ct = ChannelType(rawValue: key) {
                        loaded.insert(ct)
                    }
                }
                if !loaded.isEmpty { selectedChannels = loaded }
            }

            // skills
            if let skills = json["skills"] as? [String: Any],
               let install = skills["install"] as? [String: Any] {
                enableSkills = true
                if let nm = install["nodeManager"] as? String {
                    skillsNodeManager = nm
                }
            }

            // hooks
            if let hooks = json["hooks"] as? [String: Any],
               let internal_ = hooks["internal"] as? [String: Any],
               let entries = internal_["entries"] as? [String: Any] {
                enabledHooks = Set(entries.keys)
            }
        }
    }

    func uninstall() async {
        isUninstalling = true
        installLog = []

        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

        if backupConfig, let existing = existingInstall, existing.hasConfig {
            let timestamp = ISO8601DateFormatter().string(from: Date())
                .replacingOccurrences(of: ":", with: "-")
                .replacingOccurrences(of: "T", with: "_")
                .prefix(19)
            let backupDir = "\(homeDir)/.openclaw-backup-\(timestamp)"
            appendLog("==> 备份配置到 \(backupDir)")
            _ = await shell.run("cp -R \(homeDir)/.openclaw \(backupDir)")
            lastBackupPath = backupDir
        }

        // Step 1: Stop and uninstall gateway service (official: openclaw gateway stop/uninstall)
        appendLog("==> 停止守护进程...")
        _ = await shell.run("openclaw gateway stop 2>/dev/null || true")
        _ = await shell.run("openclaw gateway uninstall 2>/dev/null || true")
        // Fallback: manual launchd cleanup in case CLI commands didn't work
        _ = await shell.run("launchctl bootout gui/$(id -u)/ai.openclaw.gateway 2>/dev/null || true")
        _ = await shell.run("rm -f \(homeDir)/Library/LaunchAgents/ai.openclaw.gateway.plist")

        // Step 2: Remove state and configuration directory
        appendLog("==> 清理配置...")
        _ = await shell.run("rm -rf \(homeDir)/.openclaw")
        appendLog("  已删除 ~/.openclaw")

        // Step 3: Uninstall CLI via package manager
        appendLog("==> 卸载 OpenClaw CLI...")
        let method = existingInstall?.method ?? "npm"
        switch method {
        case "git":
            _ = await shell.run("rm -f \(homeDir)/.local/bin/openclaw")
            _ = await shell.run("rm -rf \(homeDir)/openclaw")
            appendLog("  已删除源码目录和 CLI 入口")
        case "pnpm":
            _ = await shell.run("pnpm remove -g openclaw 2>/dev/null || true")
            appendLog("  已通过 pnpm 卸载")
        case "bun":
            _ = await shell.run("bun remove -g openclaw 2>/dev/null || true")
            appendLog("  已通过 bun 卸载")
        default:
            _ = await shell.run("npm rm -g openclaw 2>/dev/null || true")
            appendLog("  已通过 npm 卸载")
        }

        // Step 4: Remove macOS app bundle if present
        if FileManager.default.fileExists(atPath: "/Applications/OpenClaw.app") {
            appendLog("==> 删除 OpenClaw.app...")
            _ = await shell.run("rm -rf /Applications/OpenClaw.app")
            appendLog("  已删除 /Applications/OpenClaw.app")
        }

        // Step 5: Clean shell completion (targeted, avoid removing unrelated lines)
        appendLog("==> 清理 shell 配置...")
        for rc in ["/.zshrc", "/.bashrc"] {
            let file = "\(homeDir)\(rc)"
            _ = await shell.run("sed -i '' '/# Added by OpenClaw/d' \(file) 2>/dev/null || true")
            _ = await shell.run("sed -i '' '/openclaw completion/d' \(file) 2>/dev/null || true")
        }

        appendLog("==> 卸载完成!")
        isUninstalling = false
        uninstallComplete = true
        existingInstall = nil
    }

    func goToStep(_ step: InstallStep) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = step
        }
    }

    func nextStep() {
        if let nextIndex = InstallStep(rawValue: currentStep.rawValue + 1) {
            goToStep(nextIndex)
        }
    }

    func previousStep() {
        if let prevIndex = InstallStep(rawValue: currentStep.rawValue - 1) {
            goToStep(prevIndex)
        }
    }

    // MARK: - Dependency Checking

    func checkDependencies() async {
        isCheckingDeps = true
        allDepsReady = false

        var deps: [DependencyStatus] = [
            DependencyStatus(name: "Homebrew", command: "brew", isInstalled: false, isChecking: true),
            DependencyStatus(name: "Node.js (v22+)", command: "node", isInstalled: false, isChecking: true),
            DependencyStatus(name: "Git", command: "git", isInstalled: false, isChecking: true),
        ]

        if selectedMethod == .npm {
            deps.append(DependencyStatus(name: "npm", command: "npm", isInstalled: false, isChecking: true))
        } else {
            deps.append(DependencyStatus(name: "pnpm", command: "pnpm", isInstalled: false, isChecking: true))
        }

        dependencies = deps

        for i in dependencies.indices {
            dependencies[i].isChecking = true

            let exists = await shell.commandExists(dependencies[i].command)
            dependencies[i].isInstalled = exists

            if exists {
                let versionStr = await shell.getCommandVersion(dependencies[i].command)
                dependencies[i].version = versionStr

                if dependencies[i].command == "node" {
                    if let ver = versionStr, let majorStr = ver.replacingOccurrences(of: "v", with: "").split(separator: ".").first,
                       let major = Int(majorStr), major < 22 {
                        dependencies[i].isInstalled = false
                        dependencies[i].version = "\(ver) (需要 v22+)"
                    }
                }
            }

            dependencies[i].isChecking = false
        }

        allDepsReady = dependencies.allSatisfy { $0.isInstalled }
        isCheckingDeps = false

        // Detect current npm registry and match to a known mirror
        if selectedMethod == .npm {
            let regResult = await shell.run("npm config get registry")
            if regResult.exitCode == 0 {
                let currentURL = regResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
                if let match = NpmMirror.from(url: currentURL) {
                    selectedNpmMirror = match
                }
            }
        }
    }

    func installDependency(at index: Int) async {
        guard index < dependencies.count else { return }
        dependencies[index].isInstalling = true

        let dep = dependencies[index]
        var success = false

        switch dep.command {
        case "brew":
            let result = await shell.run(
                "NONINTERACTIVE=1 /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            )
            success = result.exitCode == 0
            if success {
                _ = await shell.run("eval \"$(/opt/homebrew/bin/brew shellenv)\"")
            }

        case "node":
            let result = await shell.run("brew install node@22 && brew link --overwrite node@22")
            success = result.exitCode == 0

        case "git":
            let result = await shell.run("brew install git")
            success = result.exitCode == 0

        case "npm":
            success = await shell.commandExists("npm")

        case "pnpm":
            let result = await shell.run("npm install -g pnpm@latest")
            success = result.exitCode == 0

        default:
            break
        }

        dependencies[index].isInstalled = success
        dependencies[index].isInstalling = false

        if success {
            let ver = await shell.getCommandVersion(dep.command)
            dependencies[index].version = ver
        }

        allDepsReady = dependencies.allSatisfy { $0.isInstalled }
    }

    func installAllMissing() async {
        for i in dependencies.indices where !dependencies[i].isInstalled {
            await installDependency(at: i)
            if !dependencies[i].isInstalled { break }
        }
    }

    // MARK: - Installation

    func startInstallation() {
        installTask?.cancel()
        installTask = Task {
            await performInstallation()
        }
    }

    private func performInstallation() async {
        isInstalling = true
        installError = nil
        installCancelled = false
        installLog = []
        installProgress = 0

        switch selectedMethod {
        case .npm:
            await installViaNpm()
        case .git:
            await installViaGit()
        }

        isInstalling = false
    }

    func cancelInstallation() {
        stopProgressSimulation()
        installTask?.cancel()
        installTask = nil
        installCancelled = true
        isInstalling = false
        appendLog("==> 安装已被用户取消")
    }

    private func checkCancellation() -> Bool {
        return Task.isCancelled
    }

    private func startProgressSimulation(from start: Double, ceiling: Double) {
        progressTimer?.cancel()
        progressTimer = Task { [weak self] in
            var current = start
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 600_000_000)
                guard !Task.isCancelled, let self else { return }
                let remaining = ceiling - current
                let step = remaining * 0.04
                if step < 0.001 { continue }
                current += step
                self.installProgress = current
            }
        }
    }

    private func stopProgressSimulation() {
        progressTimer?.cancel()
        progressTimer = nil
    }

    private func installViaNpm() async {
        appendLog("==> 开始通过 npm 安装 OpenClaw...")
        installProgress = 0.05

        guard !checkCancellation() else { return }

        appendLog("==> 清理旧安装残留...")
        _ = await shell.run("rm -rf /opt/homebrew/lib/node_modules/.openclaw-* 2>/dev/null; rm -rf /usr/local/lib/node_modules/.openclaw-* 2>/dev/null")

        // Apply npm mirror setting
        appendLog("==> 设置 npm 镜像: \(selectedNpmMirror.name) (\(selectedNpmMirror.url))")
        _ = await shell.run("npm config set registry '\(selectedNpmMirror.url)'")

        appendLog("==> 运行: npm install -g openclaw@latest")
        installProgress = 0.1
        startProgressSimulation(from: 0.1, ceiling: 0.7)

        let exitCode = await shell.runStreaming("npm install -g openclaw@latest") { [weak self] output in
            Task { @MainActor in
                self?.appendLog(output)
            }
        }

        stopProgressSimulation()
        guard !checkCancellation() else { return }

        installProgress = 0.7

        if exitCode != 0 {
            appendLog("==> npm 安装失败，尝试修复...")

            _ = await shell.run("rm -rf /opt/homebrew/lib/node_modules/.openclaw-* 2>/dev/null")
            let fixResult = await shell.run("mkdir -p ~/.npm-global && npm config set prefix '~/.npm-global'")
            if fixResult.exitCode == 0 {
                guard !checkCancellation() else { return }
                appendLog("==> 重新尝试安装...")
                installProgress = 0.35
                startProgressSimulation(from: 0.35, ceiling: 0.7)

                let retryCode = await shell.runStreaming("npm install -g openclaw@latest") { [weak self] output in
                    Task { @MainActor in
                        self?.appendLog(output)
                    }
                }

                stopProgressSimulation()

                if retryCode != 0 {
                    installError = "npm 安装失败，请检查日志获取详细信息"
                    return
                }
            }
        }

        guard !checkCancellation() else { return }

        // Ensure bin link exists (matching install.sh ensure_openclaw_bin_link)
        appendLog("==> 确保 CLI 链接...")
        _ = await shell.run("""
            npm_root="$(npm root -g 2>/dev/null || true)"; \
            npm_bin="$(npm bin -g 2>/dev/null || npm config get prefix 2>/dev/null)/bin"; \
            if [ -d "$npm_root/openclaw" ] && [ ! -x "$npm_bin/openclaw" ]; then \
                mkdir -p "$npm_bin" && ln -sf "$npm_root/openclaw/dist/entry.js" "$npm_bin/openclaw"; \
            fi
            """)

        installProgress = 0.8
        await configureShell()

        guard !checkCancellation() else { return }

        installProgress = 0.9
        await runPostInstall()
        installProgress = 1.0
        installSucceeded = true
        appendLog("==> OpenClaw 安装完成!")
    }

    private func installViaGit() async {
        appendLog("==> 开始通过 Git 安装 OpenClaw...")
        installProgress = 0.05

        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let cloneDir = "\(homeDir)/openclaw"

        guard !checkCancellation() else { return }

        let exists = FileManager.default.fileExists(atPath: cloneDir)
        if exists {
            appendLog("==> 发现已有安装目录，更新中...")
            startProgressSimulation(from: 0.05, ceiling: 0.2)
            let pullCode = await shell.runStreaming("cd \(cloneDir) && git pull") { [weak self] output in
                Task { @MainActor in self?.appendLog(output) }
            }
            stopProgressSimulation()
            if pullCode != 0 { installError = "Git pull 失败"; return }
        } else {
            appendLog("==> 克隆仓库: https://github.com/openclaw/openclaw.git")
            startProgressSimulation(from: 0.05, ceiling: 0.2)
            let cloneCode = await shell.runStreaming("git clone https://github.com/openclaw/openclaw.git \(cloneDir)") { [weak self] output in
                Task { @MainActor in self?.appendLog(output) }
            }
            stopProgressSimulation()
            if cloneCode != 0 { installError = "Git clone 失败"; return }
        }

        guard !checkCancellation() else { return }

        installProgress = 0.2
        appendLog("==> 安装依赖...")
        startProgressSimulation(from: 0.2, ceiling: 0.45)

        let pnpmCode = await shell.runStreaming("cd \(cloneDir) && pnpm install") { [weak self] output in
            Task { @MainActor in self?.appendLog(output) }
        }
        stopProgressSimulation()
        if pnpmCode != 0 { installError = "pnpm install 失败"; return }

        guard !checkCancellation() else { return }

        installProgress = 0.45
        appendLog("==> 构建 UI...")
        startProgressSimulation(from: 0.45, ceiling: 0.6)

        let uiBuildCode = await shell.runStreaming("cd \(cloneDir) && pnpm ui:build") { [weak self] output in
            Task { @MainActor in self?.appendLog(output) }
        }
        stopProgressSimulation()
        if uiBuildCode != 0 { appendLog("==> UI 构建跳过（可选组件）") }

        guard !checkCancellation() else { return }

        installProgress = 0.6
        appendLog("==> 构建项目...")
        startProgressSimulation(from: 0.6, ceiling: 0.8)

        let buildCode = await shell.runStreaming("cd \(cloneDir) && pnpm build") { [weak self] output in
            Task { @MainActor in self?.appendLog(output) }
        }
        stopProgressSimulation()
        if buildCode != 0 { installError = "项目构建失败"; return }

        guard !checkCancellation() else { return }

        installProgress = 0.8
        appendLog("==> 创建 CLI 入口...")
        let binDir = "\(homeDir)/.local/bin"
        _ = await shell.run("mkdir -p \(binDir)")

        let wrapperScript = """
        #!/bin/bash
        exec node \(cloneDir)/dist/cli.js "$@"
        """
        let wrapperPath = "\(binDir)/openclaw"
        try? wrapperScript.write(toFile: wrapperPath, atomically: true, encoding: .utf8)
        _ = await shell.run("chmod +x \(wrapperPath)")

        guard !checkCancellation() else { return }

        installProgress = 0.9
        await configureShell()
        await runPostInstall()
        installProgress = 1.0
        installSucceeded = true
        appendLog("==> OpenClaw 安装完成!")
    }

    private func configureShell() async {
        appendLog("==> 配置 shell 环境...")

        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

        var pathsToAdd: [String] = []

        if selectedMethod == .git {
            pathsToAdd.append("\(homeDir)/.local/bin")
        }

        let npmBinResult = await shell.run("npm config get prefix")
        if npmBinResult.exitCode == 0 {
            let prefix = npmBinResult.output
            let binPath = "\(prefix)/bin"
            pathsToAdd.append(binPath)
        }

        let shellFiles = ["\(homeDir)/.zshrc", "\(homeDir)/.bashrc"]

        for shellFile in shellFiles {
            for pathEntry in pathsToAdd {
                let exportLine = "export PATH=\"\(pathEntry):$PATH\""
                let checkResult = await shell.run("grep -q '\(pathEntry)' \(shellFile) 2>/dev/null")
                if checkResult.exitCode != 0 {
                    _ = await shell.run("echo '\\n# OpenClaw\\n\(exportLine)' >> \(shellFile)")
                    appendLog("  已添加 PATH 到 \(shellFile)")
                }
            }
        }
    }

    private func runPostInstall() async {
        appendLog("==> 验证安装...")

        let whichResult = await shell.run("which openclaw 2>/dev/null || echo ''")
        let clawBin = whichResult.output

        if clawBin.isEmpty {
            appendLog("  openclaw 已安装（重启终端后生效）")
        } else {
            let verResult = await shell.run("openclaw --version 2>/dev/null || echo ''")
            if !verResult.output.isEmpty {
                appendLog("  已安装: \(verResult.output)")
            } else {
                appendLog("  openclaw 已安装到 PATH")
            }
        }

        // Create directory structure matching CLI (openclaw onboard init)
        // Shell completions → ~/.openclaw/completions/ (via CLI --write-state)
        appendLog("==> 生成 Shell 补全脚本...")
        _ = await shell.run("openclaw completion --write-state 2>/dev/null || true")
        appendLog("  补全脚本已生成")

        // Device identity (Ed25519 keypair) is created lazily by the CLI on first gateway start.
        // Do NOT create it manually — the CLI generates proper crypto keys.

        // Agent directory → ~/.openclaw/agents/main/agent/
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let agentDir = "\(homeDir)/.openclaw/agents/main/agent"
        _ = await shell.run("mkdir -p \(agentDir)")
    }

    private func appendLog(_ text: String) {
        let lines = text.components(separatedBy: .newlines)
        for line in lines where !line.isEmpty {
            installLog.append(line)
        }
    }

    // MARK: - Onboard Wizard Navigation

    func enterConfigMode() {
        onboardStep = .providerSelect
        onboardingComplete = false
        onboardingError = nil
        onboardingLog = []
        goToStep(.configuring)
    }

    func openDashboard() {
        Task {
            let result = await shell.run("openclaw dashboard --no-open 2>&1")
            let output = result.output + "\n" + result.errorOutput
            if let range = output.range(of: "http[^ \n]+", options: .regularExpression),
               let url = URL(string: String(output[range])) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func shouldSkipStep(_ step: OnboardStep) -> Bool {
        switch step {
        case .channelConfig:
            return selectedChannels.isEmpty
        default:
            return false
        }
    }

    func nextOnboardStep() {
        var next = onboardStep.rawValue + 1
        while let step = OnboardStep(rawValue: next), shouldSkipStep(step) {
            next += 1
        }
        if let step = OnboardStep(rawValue: next) {
            withAnimation(.easeInOut(duration: 0.25)) {
                onboardStep = step
            }
        }
    }

    func previousOnboardStep() {
        var prev = onboardStep.rawValue - 1
        while let step = OnboardStep(rawValue: prev), shouldSkipStep(step) {
            prev -= 1
        }
        if let step = OnboardStep(rawValue: prev) {
            withAnimation(.easeInOut(duration: 0.25)) {
                onboardStep = step
            }
        }
    }

    /// Returns a binding for a specific channel credential field.
    func channelCredentialBinding(channel: ChannelType, field: String) -> Binding<String> {
        Binding<String>(
            get: { self.channelCredentials[channel.rawValue]?[field] ?? "" },
            set: { newValue in
                if self.channelCredentials[channel.rawValue] == nil {
                    self.channelCredentials[channel.rawValue] = [:]
                }
                self.channelCredentials[channel.rawValue]?[field] = newValue
            }
        )
    }

    func generateGatewayToken() {
        gatewayToken = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(32).lowercased()
    }

    /// Reset auth state when provider changes
    func onProviderChanged() {
        let choices = selectedProvider.authChoices
        selectedAuthChoice = choices.first ?? .apiKey()
        apiKey = ""
        setupToken = ""
        selectedModel = selectedProvider.defaultModel
        oauthInProgress = false
        oauthSuccess = false
        oauthError = nil
        oauthLog = []
    }

    /// Open API key console page in browser
    func openAuthPage() {
        guard !selectedAuthChoice.authURL.isEmpty,
              let url = URL(string: selectedAuthChoice.authURL) else { return }
        NSWorkspace.shared.open(url)
    }

    /// Run CLI OAuth/Device flow for the selected auth choice
    func runOAuthLogin() async {
        let choice = selectedAuthChoice
        guard !choice.cliProvider.isEmpty, !choice.cliMethod.isEmpty else { return }

        await MainActor.run {
            oauthInProgress = true
            oauthSuccess = false
            oauthError = nil
            oauthLog = []
        }

        // Enable required provider plugin if needed
        if !choice.requiredPlugin.isEmpty {
            let enableCmd = "openclaw plugins enable \(choice.requiredPlugin) 2>&1"
            await MainActor.run {
                oauthLog.append("==> openclaw plugins enable \(choice.requiredPlugin)")
            }
            let enableResult = await shell.run(enableCmd)
            await MainActor.run {
                let output = enableResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
                if !output.isEmpty {
                    oauthLog.append(output)
                }
            }
            if enableResult.exitCode != 0 {
                await MainActor.run {
                    oauthError = "插件启用失败 (exit \(enableResult.exitCode))"
                    oauthInProgress = false
                }
                return
            }
        }

        let cmd = "openclaw models auth login --provider \(choice.cliProvider) --method \(choice.cliMethod) --set-default"
        await MainActor.run {
            oauthLog.append("==> \(cmd)")
        }

        // Use streaming so the user can see real-time output (e.g. browser URL)
        let exitCode = await shell.runStreaming(cmd) { [weak self] chunk in
            let lines = chunk.components(separatedBy: "\n").filter { !$0.isEmpty }
            DispatchQueue.main.async {
                self?.oauthLog.append(contentsOf: lines)
            }
        }

        await MainActor.run {
            if exitCode == 0 {
                oauthSuccess = true
                oauthLog.append("==> 授权成功！")
            } else {
                oauthError = "授权失败 (exit \(exitCode))"
                oauthLog.append("==> 授权失败: exit code \(exitCode)")
            }
            oauthInProgress = false
        }
    }

    /// Install selected skill dependencies
    func installSkillDeps() async {
        let skills = BundledSkill.popular.filter { selectedSkills.contains($0.id) && $0.installKind != .none && !$0.installLabel.isEmpty }
        guard !skills.isEmpty else { return }

        await MainActor.run {
            skillsInstalling = true
            skillsInstallLog = []
        }

        for skill in skills {
            await MainActor.run {
                skillsInstallLog.append("==> 安装 \(skill.title) (\(skill.installLabel))...")
            }
            let result = await shell.run(skill.installLabel)
            let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            await MainActor.run {
                if !output.isEmpty {
                    let lines = output.components(separatedBy: "\n").suffix(3)
                    skillsInstallLog.append(contentsOf: lines)
                }
                if result.exitCode == 0 {
                    skillsInstallLog.append("✓ \(skill.title) 安装成功")
                } else {
                    skillsInstallLog.append("✗ \(skill.title) 安装失败 (exit \(result.exitCode))")
                }
            }
        }

        await MainActor.run {
            skillsInstalling = false
        }
    }

    // MARK: - Apply Configuration

    func runOnboarding() async {
        isOnboarding = true
        onboardingError = nil
        onboardingLog = []

        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let configDir = "\(homeDir)/.openclaw"
        let configFile = "\(configDir)/openclaw.json"
        let resolvedWorkspace = workspacePath.replacingOccurrences(of: "~", with: homeDir)

        // Step 1: Create directories
        appendOnboardingLog("==> 创建配置目录...")
        _ = await shell.run("mkdir -p \(configDir) \(resolvedWorkspace)")

        // Step 2: Build and write config file (matching CLI onboard output)
        appendOnboardingLog("==> 写入配置文件...")

        // Resolve model
        let resolvedModel: String
        if selectedProvider.needsModelId {
            resolvedModel = customModelId
        } else if !selectedModel.isEmpty {
            resolvedModel = selectedModel
        } else {
            resolvedModel = selectedProvider.defaultModel
        }

        let authToken = gatewayToken.isEmpty
            ? UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(32).lowercased()
            : gatewayToken

        // Use Dictionary to build JSON matching CLI structure
        var config: [String: Any] = [:]

        // agents.defaults — workspace + model
        var agentDefaults: [String: Any] = [
            "workspace": resolvedWorkspace
        ]
        if !resolvedModel.isEmpty {
            agentDefaults["model"] = ["primary": resolvedModel]
            agentDefaults["models"] = [resolvedModel: [:] as [String: Any]]
        }
        config["agents"] = ["defaults": agentDefaults]

        // gateway — mode, port, bind, auth, tailscale (matching CLI onboard)
        let inferredMode: String
        switch gatewayBindMode {
        case .loopback: inferredMode = "local"
        case .lan, .custom: inferredMode = "network"
        case .auto: inferredMode = "auto"
        }

        var authDict: [String: Any] = ["mode": gatewayAuthMode.rawValue]
        switch gatewayAuthMode {
        case .token:
            authDict["token"] = String(authToken)
        case .password:
            authDict["password"] = gatewayPassword
        case .none:
            break
        }

        var gateway: [String: Any] = [
            "mode": inferredMode,
            "port": Int(gatewayPort) ?? 18789,
            "bind": gatewayBindMode.rawValue,
            "auth": authDict,
            "tailscale": [
                "mode": tailscaleEnabled ? "enabled" : "off",
                "resetOnExit": tailscaleResetOnExit
            ] as [String: Any]
        ]
        if gatewayBindMode == .custom && !gatewayCustomBindHost.isEmpty {
            gateway["customBindHost"] = gatewayCustomBindHost
        }
        config["gateway"] = gateway

        // session
        config["session"] = ["dmScope": "per-channel-peer"]

        // tools
        config["tools"] = ["profile": "coding"]

        // web search
        if !selectedWebSearchProvider.isEmpty {
            config["web"] = ["search": ["provider": selectedWebSearchProvider]]
        }

        // channels
        if !selectedChannels.isEmpty {
            var channelsDict: [String: Any] = [:]
            for ch in selectedChannels {
                var entry: [String: Any] = ["enabled": true]
                let creds = channelCredentials[ch.rawValue] ?? [:]
                for (k, v) in creds where !v.isEmpty {
                    entry[k] = v
                }
                channelsDict[ch.rawValue] = entry
            }
            config["channels"] = channelsDict
        }

        // skills
        if enableSkills {
            config["skills"] = ["install": ["nodeManager": skillsNodeManager]]
        }

        // hooks
        if !enabledHooks.isEmpty {
            var entries: [String: Any] = [:]
            for hookId in enabledHooks {
                entries[hookId] = ["enabled": true]
            }
            config["hooks"] = ["internal": ["entries": entries]]
        }

        // env vars (web search API key, skill env vars)
        var envVars: [String: String] = [:]
        if !selectedWebSearchProvider.isEmpty && !webSearchApiKey.isEmpty {
            if let provider = WebSearchProvider.all.first(where: { $0.id == selectedWebSearchProvider }) {
                envVars[provider.envKey] = webSearchApiKey
            }
        }
        for (k, v) in skillEnvVars where !v.isEmpty {
            envVars[k] = v
        }
        if !envVars.isEmpty {
            config["env"] = envVars
        }

        // wizard metadata
        let isoFormatter = ISO8601DateFormatter()
        let nowISO = isoFormatter.string(from: Date())
        let version = await shell.run("openclaw --version 2>/dev/null || echo ''")
        let versionStr = version.output.trimmingCharacters(in: .whitespacesAndNewlines)
        var wizardMeta: [String: Any] = [
            "lastRunAt": nowISO,
            "lastRunMode": "local",
            "lastRunCommand": "OpenClawInstaller"
        ]
        if !versionStr.isEmpty {
            wizardMeta["lastRunVersion"] = versionStr
        }
        config["wizard"] = wizardMeta

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
            if var jsonString = String(data: jsonData, encoding: .utf8) {
                if !jsonString.hasSuffix("\n") { jsonString += "\n" }
                try jsonString.write(toFile: configFile, atomically: true, encoding: .utf8)
            }
            appendOnboardingLog("  配置已写入 \(configFile)")
        } catch {
            onboardingError = "无法写入配置文件: \(error.localizedDescription)"
            isOnboarding = false
            return
        }

        // Step 3: Store credentials based on auth mode (matching CLI: agents/main/agent/)
        let authProfileDir = "\(configDir)/agents/main/agent"
        _ = await shell.run("mkdir -p \(authProfileDir)")

        // Build auth-profiles.json in CLI format: { version: 1, profiles: { "provider:id": { ... } } }
        var authProfile: [String: Any]? = nil
        var profileId = ""
        let cliProvider = selectedAuthChoice.cliProvider.isEmpty ? selectedProvider.id : selectedAuthChoice.cliProvider

        switch selectedAuthChoice.type {
        case .apiKey:
            if !apiKey.isEmpty {
                appendOnboardingLog("==> 保存 API 密钥...")
                profileId = "\(cliProvider):default"
                authProfile = [
                    "type": "api_key",
                    "provider": cliProvider,
                    "key": apiKey
                ]
                appendOnboardingLog("  API Key 已保存")
            }
        case .token:
            if !setupToken.isEmpty {
                appendOnboardingLog("==> 保存 Setup Token...")
                profileId = "\(cliProvider):default"
                authProfile = [
                    "type": "token",
                    "provider": cliProvider,
                    "token": setupToken
                ]
                appendOnboardingLog("  Setup Token 已保存")
            }
        case .oauth, .deviceFlow:
            if !apiKey.isEmpty {
                appendOnboardingLog("==> 保存凭据...")
                profileId = "\(cliProvider):default"
                authProfile = [
                    "type": "api_key",
                    "provider": cliProvider,
                    "key": apiKey
                ]
                appendOnboardingLog("  凭据已保存")
            } else {
                appendOnboardingLog("==> 跳过认证（稍后通过 openclaw configure 配置）")
            }
        }

        if let profile = authProfile {
            let store: [String: Any] = [
                "version": 1,
                "profiles": [profileId: profile]
            ]
            let authFile = "\(authProfileDir)/auth-profiles.json"
            if let jsonData = try? JSONSerialization.data(withJSONObject: store, options: [.prettyPrinted, .sortedKeys]),
               let jsonStr = String(data: jsonData, encoding: .utf8) {
                try? jsonStr.write(toFile: authFile, atomically: true, encoding: .utf8)
            }
        }

        // Create models.json in agents/main/agent/ (matching CLI onboard)
        if !resolvedModel.isEmpty {
            let modelsJson: [String: Any] = [resolvedModel: [:] as [String: Any]]
            let modelsFile = "\(authProfileDir)/models.json"
            if let data = try? JSONSerialization.data(withJSONObject: modelsJson, options: [.prettyPrinted, .sortedKeys]),
               let str = String(data: data, encoding: .utf8) {
                try? str.write(toFile: modelsFile, atomically: true, encoding: .utf8)
            }
        }

        // ensureWorkspaceAndSessions (matching CLI onboard)
        appendOnboardingLog("==> 初始化工作区...")
        let bootstrapFiles = ["AGENTS.md", "SOUL.md", "TOOLS.md", "IDENTITY.md", "USER.md", "HEARTBEAT.md", "BOOTSTRAP.md"]
        for fileName in bootstrapFiles {
            let filePath = "\(resolvedWorkspace)/\(fileName)"
            if !FileManager.default.fileExists(atPath: filePath) {
                try? "".write(toFile: filePath, atomically: true, encoding: .utf8)
            }
        }
        _ = await shell.run("cd \(resolvedWorkspace) && git init 2>/dev/null || true")
        appendOnboardingLog("  工作区已初始化")

        // Sessions dir (matching CLI: agents/main/sessions/)
        let sessionsDir = "\(configDir)/agents/main/sessions"
        _ = await shell.run("mkdir -p \(sessionsDir)")

        // Doctor --fix: validate and repair freshly written config (matching CLI flow)
        appendOnboardingLog("==> 运行 doctor 检查...")
        let doctorResult = await shell.run("openclaw doctor --fix --non-interactive 2>&1")
        if doctorResult.exitCode == 0 {
            appendOnboardingLog("  配置检查通过 ✓")
        } else {
            // Non-fatal: log warnings but continue
            let lastLines = doctorResult.output
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: "\n")
                .suffix(3)
            for line in lastLines where !line.isEmpty {
                appendOnboardingLog("  doctor: \(line)")
            }
        }

        // Skills deps installation (matching CLI onboard: install selected skill deps)
        if enableSkills && !selectedSkills.isEmpty {
            let installable = BundledSkill.popular.filter { selectedSkills.contains($0.id) && $0.installKind != .none && !$0.installLabel.isEmpty }
            if !installable.isEmpty {
                appendOnboardingLog("==> 安装 Skills 依赖 (\(installable.count) 项)...")
                for skill in installable {
                    let result = await shell.run(skill.installLabel)
                    if result.exitCode == 0 {
                        appendOnboardingLog("  \(skill.title) ✓")
                    } else {
                        appendOnboardingLog("  \(skill.title) ✗ (exit \(result.exitCode))")
                    }
                }
            }
        }

        // Shell completion (matching CLI finalizeOnboardingWizard → setupOnboardingShellCompletion)
        if installShellCompletion {
            appendOnboardingLog("==> 安装 Shell 补全...")
            _ = await shell.run("openclaw completion --write-state 2>/dev/null || true")
            _ = await shell.run("openclaw completion --install --yes 2>/dev/null || true")
            appendOnboardingLog("  Shell 补全已安装")
        }

        // Install & start Gateway daemon (matching CLI: openclaw gateway install)
        if installDaemon {
            appendOnboardingLog("==> 安装 Gateway 守护进程...")

            // Stop any existing service first
            _ = await shell.run("openclaw gateway stop 2>/dev/null || true")

            // Build gateway install command with matching flags
            let port = gatewayPort.isEmpty ? "18789" : gatewayPort
            var installCmd = "openclaw gateway install --force --port \(port)"
            if gatewayAuthMode == .token && !gatewayToken.isEmpty {
                installCmd += " --token \(gatewayToken)"
            }

            let installResult = await shell.run("\(installCmd) 2>&1")
            if installResult.exitCode == 0 {
                appendOnboardingLog("  守护进程已安装 ✓")
            } else {
                // Log failure details
                let lines = installResult.output
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .components(separatedBy: "\n")
                    .suffix(5)
                for line in lines where !line.isEmpty {
                    appendOnboardingLog("  \(line)")
                }
                appendOnboardingLog("  守护进程安装失败，稍后可运行 openclaw gateway install 重试")
            }
        }

        // Version check
        appendOnboardingLog("==> 验证配置...")
        let verResult = await shell.run("openclaw --version 2>/dev/null || echo ''")
        if !verResult.output.isEmpty {
            appendOnboardingLog("  OpenClaw \(verResult.output)")
        }

        if installDaemon {
            // Health check: wait for gateway to be ready
            appendOnboardingLog("==> 健康检查...")
            var gatewayReady = false
            for attempt in 1...5 {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                let healthResult = await shell.run("openclaw health 2>/dev/null || curl -sf http://127.0.0.1:\(gatewayPort)/health 2>/dev/null || echo 'unreachable'")
                if !healthResult.output.contains("unreachable") {
                    appendOnboardingLog("  Gateway 健康检查通过 ✓")
                    gatewayReady = true
                    break
                }
                if attempt < 5 {
                    appendOnboardingLog("  等待 Gateway 启动... (\(attempt)/5)")
                }
            }
            if !gatewayReady {
                appendOnboardingLog("  Gateway 尚未就绪，可稍后运行 openclaw gateway restart")
            }

            // Post-daemon doctor: repair auth/channel/gateway issues (matching CLI update flow)
            appendOnboardingLog("==> 运行 post-startup doctor...")
            let postDoctorResult = await shell.run("openclaw doctor --fix --non-interactive 2>&1")
            if postDoctorResult.exitCode == 0 {
                appendOnboardingLog("  post-startup 检查通过 ✓")
            } else {
                let lastLines = postDoctorResult.output
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .components(separatedBy: "\n")
                    .suffix(3)
                for line in lastLines where !line.isEmpty {
                    appendOnboardingLog("  doctor: \(line)")
                }
            }
        }

        appendOnboardingLog("==> 配置完成!")
        onboardingComplete = true
        isOnboarding = false
    }

    func executeHatch() {
        let port = gatewayPort.isEmpty ? "18789" : gatewayPort
        switch hatchMode {
        case .tui:
            // Open Terminal and run openclaw TUI
            let script = """
            tell application "Terminal"
                activate
                do script "openclaw"
            end tell
            """
            Task {
                _ = await shell.run("osascript -e '\(script)'")
            }
        case .webUI:
            let token = gatewayToken.isEmpty ? "" : "#token=\(gatewayToken)"
            if let url = URL(string: "http://127.0.0.1:\(port)\(token)") {
                NSWorkspace.shared.open(url)
            }
        case .later:
            break
        }
    }

    private func appendOnboardingLog(_ text: String) {
        let lines = text.components(separatedBy: .newlines)
        for line in lines where !line.isEmpty {
            onboardingLog.append(line)
        }
    }

    // MARK: - Doctor

    func runDoctor() {
        doctorOutput = []
        doctorExitCode = 0
        doctorFixDone = false
        doctorFixOutput = []
        doctorRunning = true
        doctorReport = nil

        let handle = StreamingHandle()
        doctorHandle = handle
        let collector = LineCollector()

        Task {
            let exitCode = await shell.runStreamingCancellable("yes n | openclaw doctor --non-interactive 2>&1", handle: handle) { [weak self] chunk in
                collector.append(chunk: chunk)
                Task { @MainActor in
                    let lines = chunk.components(separatedBy: .newlines)
                    for line in lines where !line.isEmpty {
                        self?.doctorOutput.append(line)
                    }
                }
            }
            doctorExitCode = exitCode
            doctorRunning = false
            doctorHandle = nil
            doctorReport = DoctorReport.parse(lines: collector.lines)
        }
    }

    func runDoctorFix() {
        doctorFixOutput = []
        doctorFixExitCode = 0
        doctorFixDone = false
        doctorFixRunning = true

        let handle = StreamingHandle()
        doctorFixHandle = handle

        Task {
            let exitCode = await shell.runStreamingCancellable("yes n | openclaw doctor --fix --non-interactive 2>&1", handle: handle) { [weak self] chunk in
                Task { @MainActor in
                    let lines = chunk.components(separatedBy: .newlines)
                    for line in lines where !line.isEmpty {
                        self?.doctorFixOutput.append(line)
                    }
                }
            }
            doctorFixExitCode = exitCode
            doctorFixRunning = false
            doctorFixDone = true
            doctorFixHandle = nil
        }
    }

    func cancelDoctor() {
        doctorHandle?.cancel()
        doctorFixHandle?.cancel()
        doctorHandle = nil
        doctorFixHandle = nil
        if doctorRunning {
            doctorOutput.append("[诊断已取消]")
            doctorRunning = false
        }
        if doctorFixRunning {
            doctorFixOutput.append("[修复已取消]")
            doctorFixRunning = false
        }
    }
}
