import SwiftUI

// MARK: - Dark-friendly placeholder

extension View {
    func darkPlaceholder(_ text: String, show: Bool) -> some View {
        overlay(alignment: .leading) {
            if show {
                Text(text)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.25))
                    .allowsHitTesting(false)
                    .padding(.leading, 2)
            }
        }
    }
}

// MARK: - Reusable Components

struct ConfigHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
        }
    }
}

struct ConfigLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white.opacity(0.6))
    }
}

struct ConfigTextField: View {
    let placeholder: String
    @Binding var text: String
    var mono: Bool = false

    var body: some View {
        TextField("", text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 13, design: mono ? .monospaced : .default))
            .foregroundColor(.white)
            .darkPlaceholder(placeholder, show: text.isEmpty)
            .padding(10)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ConfigToggleRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
        }
        .toggleStyle(.switch)
        .tint(.accentColor)
    }
}

struct ConfigSegment: View {
    let label: String
    let options: [(String, String)]
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ConfigLabel(text: label)
            HStack(spacing: 6) {
                ForEach(options, id: \.0) { value, display in
                    Button(action: { selection = value }) {
                        Text(display)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(selection == value ? .white : .white.opacity(0.5))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selection == value ? Color.accentColor.opacity(0.5) : Color.white.opacity(0.05))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Config View (Step-by-step Wizard)

struct ConfigView: View {
    @EnvironmentObject var viewModel: InstallerViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Wizard step indicator
            OnboardStepIndicator(currentStep: viewModel.onboardStep)
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 4)

            // Step content
            Group {
                switch viewModel.onboardStep {
                case .providerSelect:
                    ProviderSelectStep()
                case .modelConfig:
                    ModelConfigStep()
                case .workspace:
                    WorkspaceStep()
                case .gateway:
                    GatewayStep()
                case .channels:
                    ChannelsStep()
                case .channelConfig:
                    ChannelConfigStep()
                case .webSearch:
                    WebSearchStep()
                case .hooks:
                    HooksStep()
                case .daemonFinish:
                    DaemonFinishStep()
                case .skills:
                    SkillsStep()
                case .shellCompletion:
                    ShellCompletionStep()
                case .hatchBot:
                    HatchBotStep()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
        }
    }
}

// MARK: - Wizard Step Indicator

struct OnboardStepIndicator: View {
    let currentStep: OnboardStep

    var body: some View {
        HStack(spacing: 0) {
            ForEach(OnboardStep.allCases, id: \.rawValue) { step in
                HStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(step.rawValue <= currentStep.rawValue ? Color.accentColor : Color.white.opacity(0.1))
                            .frame(width: 22, height: 22)

                        if step.rawValue < currentStep.rawValue {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: step.icon)
                                .font(.system(size: 9))
                                .foregroundColor(step.rawValue == currentStep.rawValue ? .white : .white.opacity(0.4))
                        }
                    }

                    if step.rawValue < OnboardStep.allCases.count - 1 {
                        Rectangle()
                            .fill(step.rawValue < currentStep.rawValue ? Color.accentColor : Color.white.opacity(0.1))
                            .frame(height: 1.5)
                    }
                }
            }
        }
    }
}

// MARK: - Step 1: Provider Selection

struct ProviderSelectStep: View {
    @EnvironmentObject var viewModel: InstallerViewModel
    @State private var searchText = ""

    private var filteredProviders: [ModelProvider] {
        if searchText.isEmpty { return ModelProvider.all }
        let query = searchText.lowercased()
        return ModelProvider.all.filter {
            $0.title.lowercased().contains(query) ||
            $0.description.lowercased().contains(query) ||
            $0.id.lowercased().contains(query)
        }
    }

    private var groupedProviders: [(ModelProvider.ProviderGroup, [ModelProvider])] {
        ModelProvider.ProviderGroup.allCases.compactMap { group in
            let providers = filteredProviders.filter { $0.group == group }
            return providers.isEmpty ? nil : (group, providers)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    ConfigHeader(title: "选择服务商", subtitle: "选择 AI 模型服务商，下一步将配置认证和模型")
                        .padding(.top, 12)

                    // Currently selected
                    HStack(spacing: 8) {
                        Image(systemName: viewModel.selectedProvider.icon)
                            .font(.system(size: 14))
                            .foregroundColor(.accentColor)
                        Text("当前: \(viewModel.selectedProvider.title)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        Text("— \(viewModel.selectedProvider.description)")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
                            )
                    )

                    // Search
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.3))
                        TextField("", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .foregroundColor(.white)
                            .darkPlaceholder("搜索服务商...", show: searchText.isEmpty)
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.3))
                            }
                            .buttonStyle(.plain)
                            .help("清除搜索")
                        }
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Provider list
                    ForEach(groupedProviders, id: \.0) { group, providers in
                        Text(group.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.leading, 4)
                            .padding(.top, 4)

                        VStack(spacing: 4) {
                            ForEach(providers) { provider in
                                ProviderRow(
                                    provider: provider,
                                    isSelected: viewModel.selectedProvider.id == provider.id
                                ) {
                                    viewModel.selectedProvider = provider
                                    viewModel.onProviderChanged()
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }

            WizardNavBar(
                canGoBack: false,
                onBack: {},
                onNext: { viewModel.nextOnboardStep() }
            )
        }
    }
}

// MARK: - Step 2: Model Configuration

struct ModelConfigStep: View {
    @EnvironmentObject var viewModel: InstallerViewModel
    @State private var showKey = false
    @State private var showAuthLog = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    ConfigHeader(title: "模型配置", subtitle: "为 \(viewModel.selectedProvider.title) 配置认证和模型")
                        .padding(.top, 12)

                    // Provider badge
                    HStack(spacing: 8) {
                        Image(systemName: viewModel.selectedProvider.icon)
                            .font(.system(size: 16))
                            .foregroundColor(.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.selectedProvider.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                            Text(viewModel.selectedProvider.description)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        Spacer()
                        Button(action: { viewModel.previousOnboardStep() }) {
                            Text("更换")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.accentColor.opacity(0.15), lineWidth: 1)
                            )
                    )

                    // Auth choice selector (only if provider has multiple choices)
                    if viewModel.selectedProvider.authChoices.count > 1 {
                        VStack(alignment: .leading, spacing: 8) {
                            ConfigLabel(text: "认证方式")
                            ForEach(viewModel.selectedProvider.authChoices) { choice in
                                Button(action: { viewModel.selectedAuthChoice = choice }) {
                                    HStack(spacing: 10) {
                                        Circle()
                                            .stroke(viewModel.selectedAuthChoice.id == choice.id ? Color.accentColor : Color.white.opacity(0.2), lineWidth: 1.5)
                                            .frame(width: 14, height: 14)
                                            .overlay(
                                                Circle()
                                                    .fill(viewModel.selectedAuthChoice.id == choice.id ? Color.accentColor : Color.clear)
                                                    .frame(width: 7, height: 7)
                                            )
                                        Image(systemName: choice.icon)
                                            .font(.system(size: 11))
                                            .foregroundColor(viewModel.selectedAuthChoice.id == choice.id ? .accentColor : .white.opacity(0.35))
                                            .frame(width: 16)
                                        Text(choice.label)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.white)
                                        if !choice.hint.isEmpty && choice.type != .apiKey {
                                            Text("— \(choice.hint)")
                                                .font(.system(size: 10))
                                                .foregroundColor(.white.opacity(0.3))
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Auth fields based on selected choice type
                    switch viewModel.selectedAuthChoice.type {
                    case .apiKey:
                        if !viewModel.selectedProvider.authChoices.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                // Open auth URL button if available
                                if !viewModel.selectedAuthChoice.authURL.isEmpty {
                                    Button(action: { viewModel.openAuthPage() }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "safari")
                                                .font(.system(size: 11))
                                            Text("获取 API Key")
                                                .font(.system(size: 12, weight: .medium))
                                            Image(systemName: "arrow.up.right")
                                                .font(.system(size: 9, weight: .semibold))
                                        }
                                        .foregroundColor(.accentColor)
                                    }
                                    .buttonStyle(.plain)
                                }

                                ConfigLabel(text: "API Key")
                                HStack(spacing: 8) {
                                    Group {
                                        if showKey {
                                            TextField("", text: $viewModel.apiKey)
                                        } else {
                                            SecureField("", text: $viewModel.apiKey)
                                        }
                                    }
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(.white)
                                    .darkPlaceholder(viewModel.selectedAuthChoice.placeholder.isEmpty ? viewModel.selectedProvider.placeholder : viewModel.selectedAuthChoice.placeholder, show: viewModel.apiKey.isEmpty)
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
                                Text("可选 — 留空将在首次使用时提示输入")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.3))
                            }
                        }

                    case .token:
                        VStack(alignment: .leading, spacing: 6) {
                            ConfigLabel(text: "Setup Token")
                            HStack(spacing: 8) {
                                Group {
                                    if showKey {
                                        TextField("", text: $viewModel.setupToken)
                                    } else {
                                        SecureField("", text: $viewModel.setupToken)
                                    }
                                }
                                .textFieldStyle(.plain)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(.white)
                                .darkPlaceholder("粘贴 token...", show: viewModel.setupToken.isEmpty)
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

                            HStack(spacing: 8) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 11))
                                    .foregroundColor(.accentColor.opacity(0.7))
                                Text("在另一台已安装 Claude CLI 的机器上运行 claude setup-token 生成令牌，然后粘贴到此处。")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.4))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.accentColor.opacity(0.05))
                            )
                        }

                    case .oauth, .deviceFlow:
                        VStack(alignment: .leading, spacing: 10) {
                            // Hint
                            if !viewModel.selectedAuthChoice.hint.isEmpty {
                                HStack(spacing: 8) {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 11))
                                        .foregroundColor(.accentColor.opacity(0.7))
                                    Text(viewModel.selectedAuthChoice.hint)
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.4))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.accentColor.opacity(0.05))
                                )
                            }

                            // OAuth login button — runs CLI auth flow
                            Button(action: {
                                Task { await viewModel.runOAuthLogin() }
                            }) {
                                HStack(spacing: 8) {
                                    if viewModel.oauthInProgress {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                            .progressViewStyle(.circular)
                                    } else if viewModel.oauthSuccess {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 13))
                                            .foregroundColor(.green)
                                    } else {
                                        Image(systemName: viewModel.selectedAuthChoice.type == .deviceFlow ? "iphone.and.arrow.forward" : "globe")
                                            .font(.system(size: 13))
                                    }
                                    Text(viewModel.oauthInProgress ? "授权中..." : viewModel.oauthSuccess ? "授权成功" : "开始授权")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(height: 40)
                                .padding(.horizontal, 20)
                                .background(viewModel.oauthSuccess ? Color.green.opacity(0.8) : Color.accentColor)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.oauthInProgress)

                            // OAuth error
                            if let error = viewModel.oauthError {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(.red)
                                    Text(error)
                                        .font(.system(size: 12))
                                        .foregroundColor(.red.opacity(0.8))
                                }
                            }

                            // Auth log panel (collapsed by default, auto-expand on error)
                            if !viewModel.oauthLog.isEmpty {
                                DisclosureGroup(
                                    isExpanded: Binding(
                                        get: { showAuthLog || viewModel.oauthError != nil },
                                        set: { showAuthLog = $0 }
                                    )
                                ) {
                                    ZStack(alignment: .topTrailing) {
                                        ScrollView {
                                            VStack(alignment: .leading, spacing: 2) {
                                                ForEach(Array(viewModel.oauthLog.enumerated()), id: \.offset) { _, line in
                                                    Text(line)
                                                        .font(.system(size: 11, design: .monospaced))
                                                        .foregroundColor(line.hasPrefix("==>") ? .accentColor : .white.opacity(0.6))
                                                        .textSelection(.enabled)
                                                }
                                            }
                                            .padding(8)
                                            .padding(.trailing, 24)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .frame(maxHeight: 120)

                                        Button(action: {
                                            NSPasteboard.general.clearContents()
                                            NSPasteboard.general.setString(viewModel.oauthLog.joined(separator: "\n"), forType: .string)
                                        }) {
                                            Image(systemName: "doc.on.doc")
                                                .font(.system(size: 10))
                                                .foregroundColor(.white.opacity(0.4))
                                        }
                                        .buttonStyle(.plain)
                                        .help("复制日志")
                                        .padding(6)
                                    }
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.black.opacity(0.3))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                            )
                                    )
                                } label: {
                                    HStack(spacing: 4) {
                                        Text("授权日志")
                                        Text("(\(viewModel.oauthLog.count) 行)")
                                            .foregroundColor(.white.opacity(0.3))
                                    }
                                }
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                            }

                            // Fallback: manual paste credential (hidden behind disclosure)
                            DisclosureGroup("手动输入凭证") {
                                VStack(alignment: .leading, spacing: 6) {
                                    ConfigLabel(text: "API Key / Token")
                                    HStack(spacing: 8) {
                                        Group {
                                            if showKey {
                                                TextField("", text: $viewModel.apiKey)
                                            } else {
                                                SecureField("", text: $viewModel.apiKey)
                                            }
                                        }
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundColor(.white)
                                        .darkPlaceholder("手动粘贴凭证...", show: viewModel.apiKey.isEmpty)
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
                                    Text("也可稍后通过 openclaw configure 配置")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.3))
                                }
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                        }
                    }

                    // Base URL
                    if viewModel.selectedProvider.needsBaseURL {
                        VStack(alignment: .leading, spacing: 6) {
                            ConfigLabel(text: "Base URL")
                            ConfigTextField(placeholder: "https://api.example.com/v1", text: $viewModel.customBaseURL, mono: true)
                        }
                    }

                    // Model ID (for custom/local providers)
                    if viewModel.selectedProvider.needsModelId {
                        VStack(alignment: .leading, spacing: 6) {
                            ConfigLabel(text: "模型 ID")
                            ConfigTextField(placeholder: "模型名称 (如 llama3:70b)", text: $viewModel.customModelId, mono: true)
                        }
                    }

                    // Default model selection (for standard providers)
                    if !viewModel.selectedProvider.needsModelId {
                        VStack(alignment: .leading, spacing: 6) {
                            ConfigLabel(text: "默认模型")
                            if !viewModel.selectedProvider.models.isEmpty {
                                Menu {
                                    ForEach(viewModel.selectedProvider.models, id: \.self) { model in
                                        Button(action: { viewModel.selectedModel = model }) {
                                            if model == viewModel.selectedModel {
                                                Label(model, systemImage: "checkmark")
                                            } else {
                                                Text(model)
                                            }
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(viewModel.selectedModel.isEmpty ? viewModel.selectedProvider.models.first ?? "" : viewModel.selectedModel)
                                            .font(.system(size: 13, design: .monospaced))
                                            .foregroundColor(.white)
                                        Spacer()
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.system(size: 10))
                                            .foregroundColor(.white.opacity(0.4))
                                    }
                                    .padding(10)
                                    .background(Color.white.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .menuStyle(.borderlessButton)
                                .frame(maxWidth: .infinity)
                            } else {
                                ConfigTextField(
                                    placeholder: viewModel.selectedProvider.defaultModel.isEmpty
                                        ? "\(viewModel.selectedProvider.id)/model-name"
                                        : viewModel.selectedProvider.defaultModel,
                                    text: $viewModel.selectedModel,
                                    mono: true
                                )
                                Text("留空使用服务商默认模型")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.25))
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }

            WizardNavBar(
                canGoBack: true,
                onBack: { viewModel.previousOnboardStep() },
                onNext: { viewModel.nextOnboardStep() }
            )
        }
    }
}

// MARK: - Step 2: Workspace

struct WorkspaceStep: View {
    @EnvironmentObject var viewModel: InstallerViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    ConfigHeader(title: "工作区", subtitle: "Agent 文件和会话数据的存储位置")
                        .padding(.top, 12)

                    VStack(alignment: .leading, spacing: 6) {
                        ConfigLabel(text: "工作区路径")
                        ConfigTextField(placeholder: "~/.openclaw/workspace", text: $viewModel.workspacePath, mono: true)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.accentColor.opacity(0.7))
                        Text("工作区将包含 Agent 文件、会话数据和 Bootstrap 文件。首次启动时会自动初始化。")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.45))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.accentColor.opacity(0.1), lineWidth: 1)
                            )
                    )

                    Button(action: {
                        viewModel.workspacePath = "~/.openclaw/workspace"
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 11))
                            Text("重置为默认路径")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
            }

            WizardNavBar(
                canGoBack: true,
                onBack: { viewModel.previousOnboardStep() },
                onNext: { viewModel.nextOnboardStep() }
            )
        }
    }
}

// MARK: - Step 3: Gateway

struct GatewayStep: View {
    @EnvironmentObject var viewModel: InstallerViewModel
    @State private var showToken = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    ConfigHeader(title: "Gateway 配置", subtitle: "配置本地 Gateway 绑定地址、端口和认证方式")
                        .padding(.top, 12)

                    // Bind mode
                    VStack(alignment: .leading, spacing: 8) {
                        ConfigLabel(text: "绑定地址")
                        ForEach(GatewayBindMode.allCases, id: \.self) { mode in
                            Button(action: { viewModel.gatewayBindMode = mode }) {
                                HStack(spacing: 10) {
                                    Circle()
                                        .stroke(viewModel.gatewayBindMode == mode ? Color.accentColor : Color.white.opacity(0.2), lineWidth: 1.5)
                                        .frame(width: 14, height: 14)
                                        .overlay(
                                            Circle()
                                                .fill(viewModel.gatewayBindMode == mode ? Color.accentColor : Color.clear)
                                                .frame(width: 7, height: 7)
                                        )
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(mode.title)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.white)
                                        Text(mode.subtitle)
                                            .font(.system(size: 10))
                                            .foregroundColor(.white.opacity(0.35))
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                        }

                        if viewModel.gatewayBindMode == .custom {
                            ConfigTextField(placeholder: "192.168.1.100", text: $viewModel.gatewayCustomBindHost, mono: true)
                                .frame(width: 200)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        ConfigLabel(text: "端口")
                        ConfigTextField(placeholder: "18789", text: $viewModel.gatewayPort, mono: true)
                            .frame(width: 140)
                        Text("默认 ws://127.0.0.1:18789")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.3))
                    }

                    ConfigSegment(
                        label: "认证方式",
                        options: GatewayAuthMode.allCases.map { ($0.rawValue, $0.title) },
                        selection: Binding(
                            get: { viewModel.gatewayAuthMode.rawValue },
                            set: {
                                if let mode = GatewayAuthMode(rawValue: $0) {
                                    viewModel.gatewayAuthMode = mode
                                    if mode == .token && viewModel.gatewayToken.isEmpty {
                                        viewModel.generateGatewayToken()
                                    }
                                }
                            }
                        )
                    )

                    if viewModel.gatewayAuthMode == .token {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                ConfigLabel(text: "Gateway Token")
                                Spacer()
                                Button(action: { viewModel.generateGatewayToken() }) {
                                    Text("重新生成")
                                        .font(.system(size: 11))
                                        .foregroundColor(.accentColor)
                                }
                                .buttonStyle(.plain)
                            }

                            HStack(spacing: 0) {
                                if showToken {
                                    TextField("", text: $viewModel.gatewayToken)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.7))
                                } else {
                                    Text(String(repeating: "\u{2022}", count: min(viewModel.gatewayToken.count, 32)))
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

                    if viewModel.gatewayAuthMode == .password {
                        VStack(alignment: .leading, spacing: 6) {
                            ConfigLabel(text: "Gateway 密码")
                            SecureField("", text: $viewModel.gatewayPassword)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.white)
                                .darkPlaceholder("设置 Gateway 访问密码", show: viewModel.gatewayPassword.isEmpty)
                                .padding(10)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }

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

                    // Tailscale (matching CLI gateway config)
                    Divider().background(Color.white.opacity(0.06))

                    VStack(alignment: .leading, spacing: 8) {
                        ConfigLabel(text: "Tailscale")
                        ConfigToggleRow(
                            title: "启用 Tailscale",
                            subtitle: "通过 Tailscale 网络暴露 Gateway，实现远程安全访问",
                            isOn: $viewModel.tailscaleEnabled
                        )

                        if viewModel.tailscaleEnabled {
                            ConfigToggleRow(
                                title: "退出时重置",
                                subtitle: "Gateway 停止时自动撤销 Tailscale Serve",
                                isOn: $viewModel.tailscaleResetOnExit
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
                .padding(.horizontal, 24)
            }

            WizardNavBar(
                canGoBack: true,
                onBack: { viewModel.previousOnboardStep() },
                onNext: { viewModel.nextOnboardStep() }
            )
        }
        .onAppear {
            if viewModel.gatewayToken.isEmpty {
                viewModel.generateGatewayToken()
            }
        }
    }
}

// MARK: - Step 4: Channels

struct ChannelsStep: View {
    @EnvironmentObject var viewModel: InstallerViewModel

    let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    ConfigHeader(title: "连接频道", subtitle: "选择要连接的消息频道（可选，稍后可通过 openclaw configure 配置）")
                        .padding(.top, 12)

                    ForEach(ChannelGroup.allCases, id: \.self) { group in
                        let channels = ChannelType.allCases.filter { $0.group == group }
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.4))
                                .padding(.leading, 4)

                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(channels) { channel in
                                    ChannelCard(
                                        channel: channel,
                                        isSelected: viewModel.selectedChannels.contains(channel)
                                    ) {
                                        if viewModel.selectedChannels.contains(channel) {
                                            viewModel.selectedChannels.remove(channel)
                                        } else {
                                            viewModel.selectedChannels.insert(channel)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if !viewModel.selectedChannels.isEmpty {
                        Text("已选 \(viewModel.selectedChannels.count) 个频道 — 安装后可通过 openclaw channels login 配置凭据")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.bottom, 8)
                    }
                }
                .padding(.horizontal, 24)
            }

            WizardNavBar(
                canGoBack: true,
                onBack: { viewModel.previousOnboardStep() },
                onNext: { viewModel.nextOnboardStep() }
            )
        }
    }
}

// MARK: - Step 5: Channel Configuration

struct ChannelConfigStep: View {
    @EnvironmentObject var viewModel: InstallerViewModel

    private var channelsWithFields: [ChannelType] {
        viewModel.selectedChannels.sorted(by: { $0.rawValue < $1.rawValue })
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    ConfigHeader(title: "频道配置", subtitle: "为已选频道填写凭据和连接信息")
                        .padding(.top, 12)

                    ForEach(channelsWithFields) { channel in
                        ChannelConfigCard(channel: channel)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }

            WizardNavBar(
                canGoBack: true,
                onBack: { viewModel.previousOnboardStep() },
                onNext: { viewModel.nextOnboardStep() }
            )
        }
    }
}

struct ChannelConfigCard: View {
    @EnvironmentObject var viewModel: InstallerViewModel
    let channel: ChannelType
    @State private var visibleFields: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: channel.icon)
                    .font(.system(size: 14))
                    .foregroundColor(.accentColor)
                Text(channel.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }

            let fields = channel.configFields

            if fields.isEmpty {
                // No inline fields — show setup hint
                if let hint = channel.setupHint {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.4))
                        Text(hint)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.45))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                ForEach(fields) { field in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text(field.label)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                            if !field.hint.isEmpty {
                                Text("— \(field.hint)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.3))
                            }
                        }

                        if field.sensitive && !visibleFields.contains(field.id) {
                            HStack(spacing: 6) {
                                SecureField("", text: viewModel.channelCredentialBinding(channel: channel, field: field.id))
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.white)
                                    .darkPlaceholder(field.placeholder.isEmpty ? field.label : field.placeholder,
                                                     show: (viewModel.channelCredentials[channel.rawValue]?[field.id] ?? "").isEmpty)
                                    .padding(8)
                                    .background(Color.white.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))

                                Button(action: { visibleFields.insert(field.id) }) {
                                    Image(systemName: "eye")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.3))
                                        .frame(width: 28, height: 28)
                                        .background(Color.white.opacity(0.06))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                .buttonStyle(.plain)
                                .help("显示")
                            }
                        } else {
                            HStack(spacing: 6) {
                                TextField("", text: viewModel.channelCredentialBinding(channel: channel, field: field.id))
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.white)
                                    .darkPlaceholder(field.placeholder.isEmpty ? field.label : field.placeholder,
                                                     show: (viewModel.channelCredentials[channel.rawValue]?[field.id] ?? "").isEmpty)
                                    .padding(8)
                                    .background(Color.white.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))

                                if field.sensitive {
                                    Button(action: { visibleFields.remove(field.id) }) {
                                        Image(systemName: "eye.slash")
                                            .font(.system(size: 11))
                                            .foregroundColor(.white.opacity(0.3))
                                            .frame(width: 28, height: 28)
                                            .background(Color.white.opacity(0.06))
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                    .buttonStyle(.plain)
                                    .help("隐藏")
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

// MARK: - Step 6: Web Search

struct WebSearchStep: View {
    @EnvironmentObject var viewModel: InstallerViewModel
    @State private var showKey = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    ConfigHeader(title: "网络搜索", subtitle: "配置 Web Search 让 Agent 可以搜索互联网（可选）")
                        .padding(.top, 12)

                    // None option
                    Button(action: { viewModel.selectedWebSearchProvider = "" }) {
                        HStack(spacing: 10) {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 14))
                                .foregroundColor(viewModel.selectedWebSearchProvider.isEmpty ? .accentColor : .white.opacity(0.3))
                                .frame(width: 24)
                            Text("暂不配置")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                            Circle()
                                .stroke(viewModel.selectedWebSearchProvider.isEmpty ? Color.accentColor : Color.white.opacity(0.2), lineWidth: 1.5)
                                .frame(width: 16, height: 16)
                                .overlay(
                                    Circle()
                                        .fill(viewModel.selectedWebSearchProvider.isEmpty ? Color.accentColor : Color.clear)
                                        .frame(width: 8, height: 8)
                                )
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(viewModel.selectedWebSearchProvider.isEmpty ? 0.07 : 0.02))
                        )
                    }
                    .buttonStyle(.plain)

                    // Provider list
                    ForEach(WebSearchProvider.all) { provider in
                        Button(action: { viewModel.selectedWebSearchProvider = provider.id }) {
                            HStack(spacing: 10) {
                                Image(systemName: provider.icon)
                                    .font(.system(size: 14))
                                    .foregroundColor(viewModel.selectedWebSearchProvider == provider.id ? .accentColor : .white.opacity(0.35))
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(provider.title)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white)
                                    Text(provider.envKey)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.3))
                                }
                                Spacer()
                                Circle()
                                    .stroke(viewModel.selectedWebSearchProvider == provider.id ? Color.accentColor : Color.white.opacity(0.2), lineWidth: 1.5)
                                    .frame(width: 16, height: 16)
                                    .overlay(
                                        Circle()
                                            .fill(viewModel.selectedWebSearchProvider == provider.id ? Color.accentColor : Color.clear)
                                            .frame(width: 8, height: 8)
                                    )
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(viewModel.selectedWebSearchProvider == provider.id ? 0.07 : 0.02))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(viewModel.selectedWebSearchProvider == provider.id ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // API Key for selected provider
                    if !viewModel.selectedWebSearchProvider.isEmpty,
                       let provider = WebSearchProvider.all.first(where: { $0.id == viewModel.selectedWebSearchProvider }) {
                        VStack(alignment: .leading, spacing: 6) {
                            ConfigLabel(text: "\(provider.title) API Key")
                            HStack(spacing: 8) {
                                Group {
                                    if showKey {
                                        TextField("", text: $viewModel.webSearchApiKey)
                                    } else {
                                        SecureField("", text: $viewModel.webSearchApiKey)
                                    }
                                }
                                .textFieldStyle(.plain)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(.white)
                                .darkPlaceholder(provider.placeholder, show: viewModel.webSearchApiKey.isEmpty)
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
                            Text("API Key 可选 — 也可通过环境变量 \(provider.envKey) 设置")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.3))
                        }
                    }
                }
                .padding(.horizontal, 24)
            }

            WizardNavBar(
                canGoBack: true,
                onBack: { viewModel.previousOnboardStep() },
                onNext: { viewModel.nextOnboardStep() }
            )
        }
    }
}

// MARK: - Step 7: Skills

struct SkillsStep: View {
    @EnvironmentObject var viewModel: InstallerViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    ConfigHeader(title: "Skills 配置", subtitle: "Skills 是可安装的扩展能力包，让 Agent 获得新技能")
                        .padding(.top, 12)

                    ConfigToggleRow(
                        title: "启用 Skills 系统",
                        subtitle: "允许安装和管理 Skill 扩展包",
                        isOn: $viewModel.enableSkills
                    )

                    if viewModel.enableSkills {
                        // Node manager
                        ConfigSegment(
                            label: "包管理器",
                            options: [("npm", "npm"), ("pnpm", "pnpm"), ("bun", "bun")],
                            selection: $viewModel.skillsNodeManager
                        )

                        // Skill selection list
                        VStack(alignment: .leading, spacing: 4) {
                            Text("选择要安装的 Skills")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.bottom, 4)

                            ForEach(BundledSkill.popular) { skill in
                                let isSelected = viewModel.selectedSkills.contains(skill.id)
                                Button(action: {
                                    if isSelected {
                                        viewModel.selectedSkills.remove(skill.id)
                                    } else {
                                        viewModel.selectedSkills.insert(skill.id)
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
                        let envSkills = BundledSkill.popular.filter { viewModel.selectedSkills.contains($0.id) && $0.primaryEnv != nil }
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
                                            SecureField("", text: Binding(
                                                get: { viewModel.skillEnvVars[envKey] ?? "" },
                                                set: { viewModel.skillEnvVars[envKey] = $0 }
                                            ))
                                            .textFieldStyle(.plain)
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundColor(.white)
                                            .darkPlaceholder("可选，稍后通过 openclaw configure 配置", show: (viewModel.skillEnvVars[envKey] ?? "").isEmpty)
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

                        // Install dependencies button
                        let installableSkills = BundledSkill.popular.filter { viewModel.selectedSkills.contains($0.id) && $0.installKind != .none && !$0.installLabel.isEmpty }
                        if !installableSkills.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Button(action: {
                                    Task { await viewModel.installSkillDeps() }
                                }) {
                                    HStack(spacing: 6) {
                                        if viewModel.skillsInstalling {
                                            ProgressView()
                                                .scaleEffect(0.6)
                                                .progressViewStyle(.circular)
                                        } else {
                                            Image(systemName: "arrow.down.circle")
                                                .font(.system(size: 12, weight: .semibold))
                                        }
                                        Text(viewModel.skillsInstalling ? "安装中..." : "安装依赖 (\(installableSkills.count) 项)")
                                            .font(.system(size: 13, weight: .medium))
                                    }
                                    .foregroundColor(.white)
                                    .frame(height: 36)
                                    .padding(.horizontal, 16)
                                    .background(Color.accentColor)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                                .disabled(viewModel.skillsInstalling)

                                // Install log
                                if !viewModel.skillsInstallLog.isEmpty {
                                    ScrollView {
                                        VStack(alignment: .leading, spacing: 2) {
                                            ForEach(Array(viewModel.skillsInstallLog.enumerated()), id: \.offset) { _, line in
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
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }

            WizardNavBar(
                canGoBack: true,
                onBack: { viewModel.previousOnboardStep() },
                onNext: { viewModel.nextOnboardStep() }
            )
        }
    }
}

// MARK: - Step 8: Hooks

struct HooksStep: View {
    @EnvironmentObject var viewModel: InstallerViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    ConfigHeader(title: "Hooks 配置", subtitle: "Hooks 在 Agent 生命周期事件触发时自动执行脚本")
                        .padding(.top, 12)

                    ForEach(BundledHook.all) { hook in
                        let isEnabled = viewModel.enabledHooks.contains(hook.id)
                        Button(action: {
                            if isEnabled {
                                viewModel.enabledHooks.remove(hook.id)
                            } else {
                                viewModel.enabledHooks.insert(hook.id)
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: hook.icon)
                                    .font(.system(size: 14))
                                    .foregroundColor(isEnabled ? .accentColor : .white.opacity(0.3))
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

                                Image(systemName: isEnabled ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 16))
                                    .foregroundColor(isEnabled ? .accentColor : .white.opacity(0.25))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(isEnabled ? 0.06 : 0.02))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(isEnabled ? Color.accentColor.opacity(0.3) : Color.white.opacity(0.05), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.accentColor.opacity(0.7))
                        Text("Hooks 存储在 ~/.openclaw/hooks/ 目录。安装后可通过 openclaw configure 管理。")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.45))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.accentColor.opacity(0.1), lineWidth: 1)
                            )
                    )
                }
                .padding(.horizontal, 24)
            }

            WizardNavBar(
                canGoBack: true,
                onBack: { viewModel.previousOnboardStep() },
                onNext: { viewModel.nextOnboardStep() }
            )
        }
    }
}

// MARK: - Step 9: Daemon / Service Start

struct DaemonFinishStep: View {
    @EnvironmentObject var viewModel: InstallerViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    ConfigHeader(title: "Gateway 服务", subtitle: "安装并启动 Gateway 守护进程")
                        .padding(.top, 12)

                    ConfigToggleRow(
                        title: "安装守护进程",
                        subtitle: "开机自动启动 Gateway (LaunchAgent)",
                        isOn: $viewModel.installDaemon
                    )

                    if viewModel.installDaemon {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green.opacity(0.7))
                                Text("将创建 LaunchAgent 并自动启动 Gateway")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green.opacity(0.7))
                                Text("端口: \(viewModel.gatewayPort.isEmpty ? "18789" : viewModel.gatewayPort)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green.opacity(0.7))
                                Text("应用配置后将执行健康检查")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.green.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.green.opacity(0.1), lineWidth: 1)
                                )
                        )
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 12))
                                .foregroundColor(.yellow.opacity(0.7))
                            Text("跳过守护进程安装。之后可通过 openclaw gateway install 手动安装。")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.45))
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
                    }
                }
                .padding(.horizontal, 24)
            }

            WizardNavBar(
                canGoBack: true,
                onBack: { viewModel.previousOnboardStep() },
                onNext: { viewModel.nextOnboardStep() }
            )
        }
    }
}

// MARK: - Step 11: Shell Completion

struct ShellCompletionStep: View {
    @EnvironmentObject var viewModel: InstallerViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    ConfigHeader(title: "Shell 补全", subtitle: "为终端命令启用自动补全功能")
                        .padding(.top, 12)

                    ConfigToggleRow(
                        title: "安装 Shell 补全",
                        subtitle: "为 zsh/bash 安装 openclaw 命令补全",
                        isOn: $viewModel.installShellCompletion
                    )

                    if viewModel.installShellCompletion {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green.opacity(0.7))
                                Text("输入 openclaw 后按 Tab 自动补全子命令和参数")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green.opacity(0.7))
                                Text("安装后可能需要重启终端或运行 source ~/.zshrc")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.green.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.green.opacity(0.1), lineWidth: 1)
                                )
                        )
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.4))
                            Text("稍后可通过 openclaw completion install 手动安装")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.03))
                        )
                    }
                }
                .padding(.horizontal, 24)
            }

            WizardNavBar(
                canGoBack: true,
                onBack: { viewModel.previousOnboardStep() },
                onNext: { viewModel.nextOnboardStep() }
            )
        }
    }
}

// MARK: - Step 12: Hatch Bot

struct HatchBotStep: View {
    @EnvironmentObject var viewModel: InstallerViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    ConfigHeader(title: "孵化你的 Bot", subtitle: "选择首次启动方式，开始与 Agent 的第一次对话")
                        .padding(.top, 12)

                    // Hatch mode selection
                    ForEach(HatchMode.allCases, id: \.self) { mode in
                        Button(action: { viewModel.hatchMode = mode }) {
                            HStack(spacing: 12) {
                                Image(systemName: mode.icon)
                                    .font(.system(size: 16))
                                    .foregroundColor(viewModel.hatchMode == mode ? .accentColor : .white.opacity(0.35))
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(mode.title)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white)
                                    Text(mode.subtitle)
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.4))
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Spacer()

                                Circle()
                                    .stroke(viewModel.hatchMode == mode ? Color.accentColor : Color.white.opacity(0.2), lineWidth: 1.5)
                                    .frame(width: 16, height: 16)
                                    .overlay(
                                        Circle()
                                            .fill(viewModel.hatchMode == mode ? Color.accentColor : Color.clear)
                                            .frame(width: 8, height: 8)
                                    )
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(viewModel.hatchMode == mode ? 0.07 : 0.02))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(viewModel.hatchMode == mode ? Color.accentColor.opacity(0.4) : Color.white.opacity(0.05), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // Bootstrap info
                    if viewModel.hatchMode != .later {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12))
                                .foregroundColor(.accentColor.opacity(0.8))
                            Text("首次启动将触发 Bootstrap 仪式 — Agent 会通过对话了解你的偏好，建立它独特的身份和记忆。请花点时间与它互动。")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.45))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accentColor.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.accentColor.opacity(0.1), lineWidth: 1)
                                )
                        )
                    }

                    // Summary
                    VStack(alignment: .leading, spacing: 10) {
                        Text("配置摘要")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))

                        SummaryRow(label: "服务商", value: viewModel.selectedProvider.title)
                        SummaryRow(label: "模型", value: {
                            if viewModel.selectedProvider.needsModelId {
                                return viewModel.customModelId.isEmpty ? "未设置" : viewModel.customModelId
                            }
                            return viewModel.selectedModel.isEmpty
                                ? (viewModel.selectedProvider.defaultModel.isEmpty ? "服务商默认" : viewModel.selectedProvider.defaultModel)
                                : viewModel.selectedModel
                        }())
                        SummaryRow(label: "工作区", value: viewModel.workspacePath)
                        SummaryRow(label: "Gateway", value: ":\(viewModel.gatewayPort) / \(viewModel.gatewayAuthMode.title)")
                        if !viewModel.selectedChannels.isEmpty {
                            SummaryRow(label: "频道", value: viewModel.selectedChannels.map { $0.title }.joined(separator: ", "))
                        }
                        if !viewModel.selectedWebSearchProvider.isEmpty {
                            SummaryRow(label: "搜索", value: WebSearchProvider.all.first(where: { $0.id == viewModel.selectedWebSearchProvider })?.title ?? viewModel.selectedWebSearchProvider)
                        }
                        if !viewModel.enabledHooks.isEmpty {
                            SummaryRow(label: "Hooks", value: viewModel.enabledHooks.sorted().joined(separator: ", "))
                        }
                        SummaryRow(label: "守护进程", value: viewModel.installDaemon ? "安装" : "跳过")
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                    )

                    // Onboarding log
                    if !viewModel.onboardingLog.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("执行日志")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.4))

                            ScrollView {
                                VStack(alignment: .leading, spacing: 2) {
                                    ForEach(Array(viewModel.onboardingLog.enumerated()), id: \.offset) { _, line in
                                        Text(line)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(line.hasPrefix("==>") ? .accentColor : .white.opacity(0.6))
                                            .textSelection(.enabled)
                                    }
                                }
                                .padding(10)
                            }
                            .frame(maxHeight: 140)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.black.opacity(0.3))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                    )
                            )
                        }
                    }

                    if let error = viewModel.onboardingError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }

            // Bottom bar with apply + hatch
            HStack(spacing: 12) {
                Button(action: { viewModel.previousOnboardStep() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 11, weight: .semibold))
                        Text("上一步")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.6))
                    .frame(height: 38)
                    .padding(.horizontal, 16)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isOnboarding)

                Spacer()

                if viewModel.onboardingComplete {
                    Button(action: {
                        viewModel.executeHatch()
                        viewModel.nextStep()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "bird.fill")
                                .font(.system(size: 12))
                            Text(viewModel.hatchMode == .later ? "完成" : "孵化!")
                                .font(.system(size: 13, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(height: 38)
                        .padding(.horizontal, 20)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: {
                        Task { await viewModel.runOnboarding() }
                    }) {
                        HStack(spacing: 6) {
                            if viewModel.isOnboarding {
                                ProgressView()
                                    .scaleEffect(0.5)
                                    .progressViewStyle(.circular)
                            } else {
                                Image(systemName: "square.and.arrow.down.fill")
                                    .font(.system(size: 11))
                            }
                            Text(viewModel.isOnboarding ? "应用中..." : "应用配置")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(height: 38)
                        .padding(.horizontal, 20)
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isOnboarding)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.02))
        }
    }
}

// MARK: - Wizard Navigation Bar

struct WizardNavBar: View {
    let canGoBack: Bool
    let onBack: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack {
            if canGoBack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 11, weight: .semibold))
                        Text("上一步")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.6))
                    .frame(height: 38)
                    .padding(.horizontal, 16)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button(action: onNext) {
                HStack(spacing: 4) {
                    Text("下一步")
                        .font(.system(size: 13, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(height: 38)
                .padding(.horizontal, 20)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.02))
    }
}

// MARK: - Shared Components

struct ProviderRow: View {
    let provider: ModelProvider
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Image(systemName: provider.icon)
                    .font(.system(size: 13))
                    .foregroundColor(isSelected ? .accentColor : .white.opacity(0.4))
                    .frame(width: 24)

                Text(provider.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)

                Text(provider.description)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.35))
                    .lineLimit(1)

                Spacer()

                Circle()
                    .stroke(isSelected ? Color.accentColor : Color.white.opacity(0.2), lineWidth: 1.5)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .fill(isSelected ? Color.accentColor : Color.clear)
                            .frame(width: 8, height: 8)
                    )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(isSelected ? 0.07 : 0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct ChannelCard: View {
    let channel: ChannelType
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 6) {
                Image(systemName: channel.icon)
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? .accentColor : .white.opacity(0.35))

                Text(channel.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(isSelected ? 0.08 : 0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.accentColor.opacity(0.5) : Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct SummaryRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 70, alignment: .trailing)
            Text(value)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}
