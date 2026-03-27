import SwiftUI

// MARK: - Gateway Shared Content

/// Shared Gateway configuration UI used by both the onboarding wizard and the config editor.
struct GatewayConfigContent: View {
    @Binding var bindMode: String
    @Binding var customBindHost: String
    @Binding var port: String
    @Binding var authMode: String
    @Binding var token: String
    @Binding var password: String
    @Binding var tailscaleEnabled: Bool
    @Binding var tailscaleResetOnExit: Bool
    var onGenerateToken: (() -> Void)? = nil

    @State private var showToken = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Bind mode
            ConfigRadioGroup(
                label: "绑定地址",
                options: GatewayBindMode.allCases.map { mode in
                    (value: mode.rawValue, title: mode.title, subtitle: mode.subtitle)
                },
                selection: $bindMode
            )

            if bindMode == "custom" {
                VStack(alignment: .leading, spacing: 6) {
                    ConfigLabel(text: "自定义绑定地址")
                    ConfigTextField(placeholder: "192.168.1.100", text: $customBindHost, mono: true)
                        .frame(width: 200)
                }
            }

            // Port
            VStack(alignment: .leading, spacing: 6) {
                ConfigLabel(text: "端口")
                ConfigTextField(placeholder: "18789", text: $port, mono: true)
                    .frame(width: 140)
                Text("默认 ws://127.0.0.1:18789")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.3))
            }

            // Auth mode
            ConfigSegment(
                label: "认证方式",
                options: GatewayAuthMode.allCases.map { ($0.rawValue, $0.title) },
                selection: $authMode
            )

            // Token field
            if authMode == "token" {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        ConfigLabel(text: "Gateway Token")
                        Spacer()
                        if let generate = onGenerateToken {
                            Button(action: generate) {
                                Text("重新生成")
                                    .font(.system(size: 11))
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: 0) {
                        if showToken {
                            TextField("", text: $token)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                        } else {
                            Text(String(repeating: "\u{2022}", count: min(token.count, 32)))
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.5))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button(action: { showToken.toggle() }) {
                            Image(systemName: showToken ? "eye.slash" : "eye")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                        .help(showToken ? "隐藏" : "显示")
                        .padding(.trailing, 4)
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            // Password field
            if authMode == "password" {
                VStack(alignment: .leading, spacing: 6) {
                    ConfigLabel(text: "Gateway 密码")
                    SecureField("", text: $password)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white)
                        .darkPlaceholder("设置 Gateway 访问密码", show: password.isEmpty)
                        .padding(10)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            // Security hint
            HStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 12))
                    .foregroundColor(.yellow.opacity(0.7))
                Text("即使在 loopback 上也建议开启 Token 认证，确保本地 WebSocket 客户端必须认证。")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.yellow.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.yellow.opacity(0.08), lineWidth: 1)
                    )
            )

            // Tailscale
            Divider().background(Color.white.opacity(0.06))

            VStack(alignment: .leading, spacing: 8) {
                ConfigLabel(text: "Tailscale")
                ConfigToggleRow(
                    title: "启用 Tailscale",
                    subtitle: "通过 Tailscale 网络暴露 Gateway，实现远程安全访问",
                    isOn: $tailscaleEnabled
                )

                if tailscaleEnabled {
                    ConfigToggleRow(
                        title: "退出时重置",
                        subtitle: "Gateway 停止时自动撤销 Tailscale Serve",
                        isOn: $tailscaleResetOnExit
                    )

                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11))
                            .foregroundColor(.blue.opacity(0.7))
                        Text("需要在本机已安装并登录 Tailscale。启用后 Gateway 将通过 tailscale serve 暴露。")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.4))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue.opacity(0.08), lineWidth: 1)
                            )
                    )
                }
            }
        }
    }
}

// MARK: - Web Search Shared Content

/// Shared Web Search configuration UI.
struct WebSearchConfigContent: View {
    @Binding var provider: String
    /// Optional API key binding — shown inline when provided (onboarding mode).
    var apiKeyBinding: Binding<String>? = nil

    @State private var showKey = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Provider selection
            ConfigRadioGroup(
                label: "搜索服务商",
                options: [
                    (value: "", title: "无 / 暂不配置", subtitle: "不使用网络搜索")
                ] + WebSearchProvider.all.map { p in
                    (value: p.id, title: p.title, subtitle: "环境变量: \(p.envKey)")
                },
                selection: $provider
            )

            // Provider-specific info or API key
            if !provider.isEmpty,
               let p = WebSearchProvider.all.first(where: { $0.id == provider }) {
                if let keyBinding = apiKeyBinding {
                    // Inline API key input (onboarding)
                    VStack(alignment: .leading, spacing: 6) {
                        ConfigLabel(text: "\(p.title) API Key")
                        HStack(spacing: 8) {
                            Group {
                                if showKey {
                                    TextField("", text: keyBinding)
                                } else {
                                    SecureField("", text: keyBinding)
                                }
                            }
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.white)
                            .darkPlaceholder(p.placeholder, show: keyBinding.wrappedValue.isEmpty)
                            .padding(10)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            Button(action: { showKey.toggle() }) {
                                Image(systemName: showKey ? "eye.slash" : "eye")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.4))
                                    .frame(width: 34, height: 34)
                                    .background(Color.white.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .help(showKey ? "隐藏" : "显示")
                        }
                        Text("API Key 可选 — 也可通过环境变量 \(p.envKey) 设置")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.3))
                    }
                } else {
                    // Info hint (config editor)
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11))
                            .foregroundColor(.blue.opacity(0.7))
                        Text("API Key 通过环境变量 \(p.envKey) 配置，请在 env section 中设置。")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.4))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue.opacity(0.08), lineWidth: 1)
                            )
                    )
                }
            }
        }
    }
}

// MARK: - Hooks Shared Content

/// Shared Hooks configuration UI.
struct HooksConfigContent: View {
    /// Closure returning a Binding<Bool> for a given hook id.
    var isEnabledBinding: (String) -> Binding<Bool>
    /// Whether to show as card-style toggles (onboarding) or compact rows (config editor).
    var cardStyle: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: cardStyle ? 0 : 12) {
            ForEach(BundledHook.all) { hook in
                if cardStyle {
                    hookCard(hook: hook)
                } else {
                    hookRow(hook: hook)
                }
            }
        }
    }

    @ViewBuilder
    private func hookCard(hook: BundledHook) -> some View {
        let binding = isEnabledBinding(hook.id)
        Button(action: { binding.wrappedValue.toggle() }) {
            HStack(spacing: 12) {
                Image(systemName: hook.icon)
                    .font(.system(size: 14))
                    .foregroundColor(binding.wrappedValue ? .accentColor : .white.opacity(0.3))
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(hook.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                    Text(hook.description)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                }

                Spacer()

                Image(systemName: binding.wrappedValue ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16))
                    .foregroundColor(binding.wrappedValue ? .accentColor : .white.opacity(0.25))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(binding.wrappedValue ? 0.06 : 0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(binding.wrappedValue ? Color.accentColor.opacity(0.3) : Color.white.opacity(0.05), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func hookRow(hook: BundledHook) -> some View {
        let binding = isEnabledBinding(hook.id)
        HStack(spacing: 10) {
            Image(systemName: hook.icon)
                .font(.system(size: 13))
                .foregroundColor(.accentColor.opacity(0.7))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(hook.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                Text(hook.description)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }

            Spacer()

            Toggle("", isOn: binding)
                .toggleStyle(.switch)
                .labelsHidden()
                .tint(.accentColor)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Skills Shared Content

/// Shared Skills configuration UI — skill selection list with optional install buttons.
struct SkillsConfigContent: View {
    @Binding var selectedSkills: Set<String>
    @Binding var nodeManager: String
    /// Optional: environment variable values for skills requiring API keys.
    var envVarsBinding: ((String) -> Binding<String>)? = nil
    /// Closure to install dependencies for selected skills.
    var onInstallDeps: (([BundledSkill]) async -> Void)? = nil
    @Binding var installing: Bool
    @Binding var installLog: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Node manager
            ConfigSegment(
                label: "包管理器",
                options: [("npm", "npm"), ("pnpm", "pnpm"), ("bun", "bun")],
                selection: $nodeManager
            )

            // Skill selection list
            VStack(alignment: .leading, spacing: 4) {
                Text("选择要安装的 Skills")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.bottom, 4)

                ForEach(BundledSkill.popular) { skill in
                    let isSelected = selectedSkills.contains(skill.id)
                    Button(action: {
                        if isSelected {
                            selectedSkills.remove(skill.id)
                        } else {
                            selectedSkills.insert(skill.id)
                        }
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 14))
                                .foregroundColor(isSelected ? .accentColor : .white.opacity(0.2))

                            Text(skill.emoji)
                                .font(.system(size: 14))

                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 6) {
                                    Text(skill.title)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white)

                                    if skill.installKind != .none && !skill.installLabel.isEmpty {
                                        Text(skill.installKind.rawValue)
                                            .font(.system(size: 9, weight: .semibold))
                                            .foregroundColor(.white.opacity(0.4))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1)
                                            .background(Color.white.opacity(0.08))
                                            .clipShape(RoundedRectangle(cornerRadius: 3))
                                    }

                                    if skill.primaryEnv != nil {
                                        Text("API Key")
                                            .font(.system(size: 9, weight: .semibold))
                                            .foregroundColor(.orange.opacity(0.7))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1)
                                            .background(Color.orange.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 3))
                                    }
                                }
                                Text(skill.description)
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.35))
                            }

                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Env var configuration for selected skills
            if let envBinding = envVarsBinding {
                let envSkills = BundledSkill.popular.filter { selectedSkills.contains($0.id) && $0.primaryEnv != nil }
                if !envSkills.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("API Keys 配置")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))

                        ForEach(envSkills) { skill in
                            if let envKey = skill.primaryEnv {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 4) {
                                        Text(skill.emoji)
                                            .font(.system(size: 11))
                                        Text("\(skill.title) — \(envKey)")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                    SecureField("", text: envBinding(envKey))
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(.white)
                                        .darkPlaceholder("可选，稍后通过 openclaw configure 配置", show: envBinding(envKey).wrappedValue.isEmpty)
                                        .padding(8)
                                        .background(Color.white.opacity(0.06))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.orange.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.orange.opacity(0.1), lineWidth: 1)
                            )
                    )
                }
            }

            // Install dependencies button
            let installableSkills = BundledSkill.popular.filter { selectedSkills.contains($0.id) && $0.installKind != .none && !$0.installLabel.isEmpty }
            if !installableSkills.isEmpty, let onInstall = onInstallDeps {
                VStack(alignment: .leading, spacing: 8) {
                    Button(action: {
                        Task { await onInstall(installableSkills) }
                    }) {
                        HStack(spacing: 6) {
                            if installing {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .progressViewStyle(.circular)
                            } else {
                                Image(systemName: "arrow.down.circle")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            Text(installing ? "安装中..." : "安装依赖 (\(installableSkills.count) 项)")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(height: 36)
                        .padding(.horizontal, 16)
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(installing)

                    // Install log
                    if !installLog.isEmpty {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(Array(installLog.enumerated()), id: \.offset) { _, line in
                                    Text(line)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(
                                            line.hasPrefix("==>") ? .accentColor :
                                            line.hasPrefix("✓") ? .green :
                                            line.hasPrefix("✗") ? .red :
                                            .white.opacity(0.5)
                                        )
                                        .textSelection(.enabled)
                                }
                            }
                            .padding(8)
                        }
                        .frame(maxHeight: 100)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.3))
                        )
                    }
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                    .foregroundColor(.accentColor.opacity(0.7))
                Text("可通过 openclaw plugins install <name> 安装更多 Skills")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.35))
            }
        }
    }
}

// MARK: - Add Agent Shared Content

/// Shared Agent creation form used by both the onboarding wizard and the config editor.
struct AddAgentContent: View {
    @Binding var agentName: String
    @Binding var agentModel: String
    @Binding var agentWorkspace: String
    var onCancel: () -> Void
    var onCreate: () -> Void

    private var isValid: Bool {
        !agentName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("新建 Agent")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 6) {
                Text("Agent ID")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                TextField("", text: $agentName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white)
                    .darkPlaceholder("my-agent", show: agentName.isEmpty)
                    .padding(8)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("模型（可选）")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))

                HStack(spacing: 8) {
                    Menu {
                        ForEach(ModelProvider.ProviderGroup.allCases, id: \.self) { group in
                            let providers = ModelProvider.providers(in: group)
                            if !providers.isEmpty {
                                Section(group.rawValue) {
                                    ForEach(providers, id: \.id) { provider in
                                        if !provider.models.isEmpty {
                                            Menu(provider.title) {
                                                ForEach(provider.models, id: \.self) { m in
                                                    Button(m) { agentModel = m }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "cpu")
                                .font(.system(size: 10))
                            Text("选择")
                                .font(.system(size: 11, weight: .medium))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8))
                        }
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                }

                TextField("", text: $agentModel)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white)
                    .darkPlaceholder("留空则使用全局默认模型", show: agentModel.isEmpty)
                    .padding(8)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("工作区路径（可选）")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                TextField("", text: $agentWorkspace)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white)
                    .darkPlaceholder("~/.openclaw/workspace-<id>", show: agentWorkspace.isEmpty)
                    .padding(8)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            HStack {
                Spacer()
                Button("取消", action: onCancel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .buttonStyle(.plain)

                Button(action: onCreate) {
                    Text("创建")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(isValid ? Color.accentColor : Color.accentColor.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(!isValid)
            }
        }
    }
}
