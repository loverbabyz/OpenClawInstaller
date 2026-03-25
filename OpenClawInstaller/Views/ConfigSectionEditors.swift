import SwiftUI
import WebKit

// MARK: - Fallback Helper

/// Renders any keys from a ConfigValue.object that are NOT in the `handledKeys` set
/// using the generic ConfigNodeEditor, under an "其他设置" header.
private struct FallbackEditor: View {
    let sectionKey: String
    let value: ConfigValue
    let handledKeys: Set<String>
    @ObservedObject var vm: ConfigEditorViewModel

    var body: some View {
        if case .object(let pairs) = value {
            let remaining = pairs.filter { !handledKeys.contains($0.key) }
            if !remaining.isEmpty {
                Divider().background(Color.white.opacity(0.06)).padding(.vertical, 8)
                Text("其他设置")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.bottom, 4)
                ConfigNodeEditor(
                    value: .object(remaining),
                    sectionKey: sectionKey,
                    path: [],
                    vm: vm,
                    depth: 0
                )
            }
        }
    }
}

// MARK: - CLI Command Log View

private struct CommandLogView: View {
    @ObservedObject var vm: ConfigEditorViewModel

    var body: some View {
        if !vm.commandLog.isEmpty {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(vm.commandLog.enumerated()), id: \.offset) { _, line in
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
            .frame(maxHeight: 120)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.3))
            )
        }
    }
}

// MARK: - Gateway Section Editor

struct GatewaySectionEditor: View {
    @ObservedObject var vm: ConfigEditorViewModel
    @State private var showToken = false

    private var bindValue: String {
        vm.extractString(section: "gateway", path: ["bind"])
    }
    private var authMode: String {
        vm.extractString(section: "gateway", path: ["auth", "mode"], defaultValue: "token")
    }
    private var tailscaleMode: String {
        vm.extractString(section: "gateway", path: ["tailscale", "mode"], defaultValue: "off")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Bind mode
            ConfigRadioGroup(
                label: "绑定地址",
                options: GatewayBindMode.allCases.map { mode in
                    (value: mode.rawValue, title: mode.title, subtitle: mode.subtitle)
                },
                selection: vm.stringBinding(section: "gateway", path: ["bind"], defaultValue: "loopback")
            )

            if bindValue == "custom" {
                VStack(alignment: .leading, spacing: 6) {
                    ConfigLabel(text: "自定义绑定地址")
                    ConfigTextField(
                        placeholder: "192.168.1.100",
                        text: vm.stringBinding(section: "gateway", path: ["customBindHost"]),
                        mono: true
                    )
                    .frame(width: 200)
                }
            }

            // Port
            VStack(alignment: .leading, spacing: 6) {
                ConfigLabel(text: "端口")
                ConfigTextField(
                    placeholder: "18789",
                    text: vm.numberStringBinding(section: "gateway", path: ["port"]),
                    mono: true
                )
                .frame(width: 140)
                Text("默认 ws://127.0.0.1:18789")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.3))
            }

            // Auth mode
            ConfigSegment(
                label: "认证方式",
                options: GatewayAuthMode.allCases.map { ($0.rawValue, $0.title) },
                selection: vm.stringBinding(section: "gateway", path: ["auth", "mode"], defaultValue: "token")
            )

            // Conditional token field
            if authMode == "token" {
                VStack(alignment: .leading, spacing: 6) {
                    ConfigLabel(text: "Gateway Token")
                    HStack(spacing: 0) {
                        if showToken {
                            TextField("", text: vm.stringBinding(section: "gateway", path: ["auth", "token"]))
                                .textFieldStyle(.plain)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                        } else {
                            let tokenLen = vm.extractString(section: "gateway", path: ["auth", "token"]).count
                            Text(String(repeating: "\u{2022}", count: min(tokenLen, 32)))
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

            // Conditional password field
            if authMode == "password" {
                VStack(alignment: .leading, spacing: 6) {
                    ConfigLabel(text: "Gateway 密码")
                    SecureField("", text: vm.stringBinding(section: "gateway", path: ["auth", "password"]))
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white)
                        .darkPlaceholder("设置 Gateway 访问密码", show: vm.extractString(section: "gateway", path: ["auth", "password"]).isEmpty)
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
                    isOn: Binding<Bool>(
                        get: { self.tailscaleMode == "enabled" },
                        set: { vm.updateValue(sectionKey: "gateway", path: ["tailscale", "mode"], newValue: .string($0 ? "enabled" : "off")) }
                    )
                )

                if tailscaleMode == "enabled" {
                    ConfigToggleRow(
                        title: "退出时重置",
                        subtitle: "Gateway 停止时自动撤销 Tailscale Serve",
                        isOn: vm.boolBinding(section: "gateway", path: ["tailscale", "resetOnExit"])
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

            // Mode (read-only, inferred)
            VStack(alignment: .leading, spacing: 4) {
                ConfigLabel(text: "运行模式")
                Text(vm.extractString(section: "gateway", path: ["mode"], defaultValue: "local"))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Text("由 bind 模式自动推断")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.25))
            }

            // Fallback for unknown keys
            if let val = vm.sectionValue(for: "gateway") {
                FallbackEditor(
                    sectionKey: "gateway",
                    value: val,
                    handledKeys: ["bind", "customBindHost", "port", "auth", "tailscale", "mode"],
                    vm: vm
                )
            }
        }
    }
}

// MARK: - Channels Section Editor

struct ChannelsSectionEditor: View {
    @ObservedObject var vm: ConfigEditorViewModel
    @State private var showAddChannel = false

    private var channelPairs: [(key: String, value: ConfigValue)] {
        guard let val = vm.sectionValue(for: "channels"),
              case .object(let pairs) = val else { return [] }
        return pairs
    }

    private var existingChannelKeys: Set<String> {
        Set(channelPairs.map(\.key))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Add channel button
            Button(action: { showAddChannel = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 12))
                    Text("添加频道")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showAddChannel) {
                AddChannelSheet(vm: vm, existingKeys: existingChannelKeys, isPresented: $showAddChannel)
            }

            if channelPairs.isEmpty {
                Text("暂无频道配置，点击上方按钮添加")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.3))
            } else {
                ForEach(channelPairs, id: \.key) { pair in
                    ConfigChannelCard(channelKey: pair.key, value: pair.value, vm: vm)
                }
            }
        }
    }
}

// MARK: - Add Channel Sheet

private struct AddChannelSheet: View {
    @ObservedObject var vm: ConfigEditorViewModel
    let existingKeys: Set<String>
    @Binding var isPresented: Bool

    let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("添加频道")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Button("关闭") { isPresented = false }
                    .buttonStyle(.plain)
                    .foregroundColor(.white.opacity(0.6))
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.03))

            Divider().overlay(Color.white.opacity(0.06))

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(ChannelGroup.allCases, id: \.self) { group in
                        let channels = ChannelType.allCases.filter { $0.group == group && !existingKeys.contains($0.rawValue) }
                        if !channels.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(group.rawValue)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.4))
                                    .padding(.leading, 4)

                                LazyVGrid(columns: columns, spacing: 10) {
                                    ForEach(channels) { channel in
                                        Button(action: {
                                            vm.addObjectEntry(
                                                sectionKey: "channels",
                                                path: [],
                                                key: channel.rawValue,
                                                value: .object([(key: "enabled", value: .bool(true))])
                                            )
                                            isPresented = false
                                        }) {
                                            VStack(spacing: 6) {
                                                Image(systemName: channel.icon)
                                                    .font(.system(size: 16))
                                                    .foregroundColor(.accentColor)
                                                Text(channel.title)
                                                    .font(.system(size: 11, weight: .medium))
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color.white.opacity(0.04))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                                    )
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 480, height: 400)
        .background(Color(red: 0.08, green: 0.08, blue: 0.14))
        .preferredColorScheme(.dark)
    }
}

// MARK: - Channel Card with Delete

private struct ConfigChannelCard: View {
    let channelKey: String
    let value: ConfigValue
    @ObservedObject var vm: ConfigEditorViewModel
    @State private var expanded = true
    @State private var confirmDelete = false

    private var channelType: ChannelType? {
        ChannelType(rawValue: channelKey)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Channel header
            HStack(spacing: 8) {
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() } }) {
                    HStack(spacing: 8) {
                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white.opacity(0.3))
                            .frame(width: 12)
                        if let ct = channelType {
                            Image(systemName: ct.icon)
                                .font(.system(size: 12))
                                .foregroundColor(.accentColor)
                                .frame(width: 16)
                            Text(ct.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                        } else {
                            Text(channelKey)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        // Enabled badge
                        let enabled = vm.extractBool(section: "channels", path: [channelKey, "enabled"], defaultValue: false)
                        Text(enabled ? "已启用" : "已禁用")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(enabled ? .green : .white.opacity(0.3))
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                // Delete button
                if confirmDelete {
                    HStack(spacing: 6) {
                        Text("确认删除?")
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                        Button("删除") {
                            vm.deleteKey(sectionKey: "channels", path: [channelKey])
                            confirmDelete = false
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.red)
                        .buttonStyle(.plain)
                        Button("取消") { confirmDelete = false }
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.4))
                            .buttonStyle(.plain)
                    }
                } else {
                    Button(action: { confirmDelete = true }) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(.red.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .help("删除频道")
                }
            }
            .padding(.vertical, 8)

            if expanded {
                VStack(alignment: .leading, spacing: 10) {
                    // Enabled toggle
                    ConfigToggleRow(
                        title: "启用",
                        isOn: vm.boolBinding(section: "channels", path: [channelKey, "enabled"])
                    )

                    // Known channel fields
                    if let ct = channelType {
                        ForEach(ct.configFields) { field in
                            ChannelFieldRow(
                                field: field,
                                channelKey: channelKey,
                                vm: vm
                            )
                        }

                        if let hint = ct.setupHint {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 11))
                                    .foregroundColor(.blue.opacity(0.7))
                                Text(hint)
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

                        // Fallback for unknown fields within this channel
                        let knownFieldIds = Set(ct.configFields.map(\.id) + ["enabled"])
                        if case .object(let pairs) = value {
                            let unknown = pairs.filter { !knownFieldIds.contains($0.key) }
                            if !unknown.isEmpty {
                                ForEach(Array(unknown.enumerated()), id: \.offset) { _, pair in
                                    LeafRow(
                                        label: pair.key,
                                        value: pair.value,
                                        sectionKey: "channels",
                                        path: [channelKey, pair.key],
                                        vm: vm,
                                        depth: 0
                                    )
                                }
                            }
                        }
                    } else {
                        // Unknown channel type: generic editor
                        ConfigNodeEditor(
                            value: value,
                            sectionKey: "channels",
                            path: [channelKey],
                            vm: vm,
                            depth: 0
                        )
                    }
                }
                .padding(.leading, 20)
            }

            Divider().background(Color.white.opacity(0.04)).padding(.top, 4)
        }
    }
}

private struct ChannelFieldRow: View {
    let field: ChannelField
    let channelKey: String
    @ObservedObject var vm: ConfigEditorViewModel
    @State private var showSecure = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(field.label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                if !field.hint.isEmpty {
                    Text("— \(field.hint)")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.3))
                }
            }

            HStack(spacing: 6) {
                if field.sensitive && !showSecure {
                    SecureField("", text: vm.stringBinding(section: "channels", path: [channelKey, field.id]))
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white)
                        .darkPlaceholder(field.placeholder, show: vm.extractString(section: "channels", path: [channelKey, field.id]).isEmpty)
                        .padding(8)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    TextField("", text: vm.stringBinding(section: "channels", path: [channelKey, field.id]))
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white)
                        .darkPlaceholder(field.placeholder, show: vm.extractString(section: "channels", path: [channelKey, field.id]).isEmpty)
                        .padding(8)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                if field.sensitive {
                    Button(action: { showSecure.toggle() }) {
                        Image(systemName: showSecure ? "eye.slash" : "eye")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Web Section Editor

struct WebSectionEditor: View {
    @ObservedObject var vm: ConfigEditorViewModel

    private var currentProvider: String {
        vm.extractString(section: "web", path: ["search", "provider"])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ConfigRadioGroup(
                label: "搜索服务商",
                options: [
                    (value: "", title: "无", subtitle: "不使用网络搜索")
                ] + WebSearchProvider.all.map { provider in
                    (value: provider.id, title: provider.title, subtitle: "环境变量: \(provider.envKey)")
                },
                selection: vm.stringBinding(section: "web", path: ["search", "provider"])
            )

            if !currentProvider.isEmpty,
               let provider = WebSearchProvider.all.first(where: { $0.id == currentProvider }) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundColor(.blue.opacity(0.7))
                    Text("API Key 通过环境变量 \(provider.envKey) 配置，请在 env section 中设置。")
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

            // Fallback for unknown keys
            if let val = vm.sectionValue(for: "web") {
                FallbackEditor(
                    sectionKey: "web",
                    value: val,
                    handledKeys: ["search"],
                    vm: vm
                )
            }
        }
    }
}

// MARK: - Hooks Section Editor

struct HooksSectionEditor: View {
    @ObservedObject var vm: ConfigEditorViewModel
    @State private var newHookId = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(BundledHook.all) { hook in
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

                    Toggle("", isOn: vm.boolBinding(
                        section: "hooks",
                        path: ["internal", "entries", hook.id, "enabled"]
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .tint(.accentColor)
                }
                .padding(.vertical, 4)
            }

            // Custom hooks from config
            if let val = vm.sectionValue(for: "hooks"),
               case .object(let topPairs) = val {
                let bundledIds = Set(BundledHook.all.map(\.id))

                if let internalObj = topPairs.first(where: { $0.key == "internal" }),
                   case .object(let internalPairs) = internalObj.value,
                   let entriesObj = internalPairs.first(where: { $0.key == "entries" }),
                   case .object(let entries) = entriesObj.value {
                    let unknownEntries = entries.filter { !bundledIds.contains($0.key) }
                    if !unknownEntries.isEmpty {
                        Divider().background(Color.white.opacity(0.06)).padding(.vertical, 4)
                        Text("自定义 Hooks")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.3))
                        ForEach(unknownEntries, id: \.key) { entry in
                            HStack(spacing: 10) {
                                Image(systemName: "puzzlepiece")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.4))
                                    .frame(width: 20)
                                Text(entry.key)
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white)
                                Spacer()
                                Toggle("", isOn: vm.boolBinding(
                                    section: "hooks",
                                    path: ["internal", "entries", entry.key, "enabled"]
                                ))
                                .toggleStyle(.switch)
                                .labelsHidden()
                                .tint(.accentColor)

                                Button(action: {
                                    vm.deleteKey(sectionKey: "hooks", path: ["internal", "entries", entry.key])
                                }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11))
                                        .foregroundColor(.red.opacity(0.6))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                let otherTopKeys = topPairs.filter { $0.key != "internal" }
                if !otherTopKeys.isEmpty {
                    FallbackEditor(
                        sectionKey: "hooks",
                        value: val,
                        handledKeys: ["internal"],
                        vm: vm
                    )
                }
            }

            // Add custom hook
            Divider().background(Color.white.opacity(0.06)).padding(.vertical, 4)
            HStack(spacing: 8) {
                TextField("", text: $newHookId)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white)
                    .darkPlaceholder("自定义 Hook ID", show: newHookId.isEmpty)
                    .padding(8)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                Button(action: {
                    let hookId = newHookId.trimmingCharacters(in: .whitespaces)
                    guard !hookId.isEmpty else { return }
                    vm.addObjectEntry(
                        sectionKey: "hooks",
                        path: ["internal", "entries"],
                        key: hookId,
                        value: .object([(key: "enabled", value: .bool(true))])
                    )
                    newHookId = ""
                }) {
                    Text("添加")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(newHookId.trimmingCharacters(in: .whitespaces).isEmpty ? Color.accentColor.opacity(0.3) : Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(newHookId.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}

// MARK: - Skills Section Editor

struct SkillsSectionEditor: View {
    @ObservedObject var vm: ConfigEditorViewModel
    @State private var showWebBrowser = false
    @State private var installSkillName = ""
    @State private var selectedBundledSkills: Set<String> = []
    @State private var skillsInstalling = false
    @State private var skillsInstallLog: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Node manager
            ConfigSegment(
                label: "包管理器",
                options: [("npm", "npm"), ("pnpm", "pnpm"), ("bun", "bun")],
                selection: vm.stringBinding(section: "skills", path: ["install", "nodeManager"], defaultValue: "npm")
            )

            Divider().background(Color.white.opacity(0.06))

            // Bundled skills list
            VStack(alignment: .leading, spacing: 4) {
                Text("内置 Skills")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.bottom, 4)

                ForEach(BundledSkill.popular) { skill in
                    let isSelected = selectedBundledSkills.contains(skill.id)
                    Button(action: {
                        if isSelected {
                            selectedBundledSkills.remove(skill.id)
                        } else {
                            selectedBundledSkills.insert(skill.id)
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

            // Install dependencies button for selected bundled skills
            let installableSkills = BundledSkill.popular.filter { selectedBundledSkills.contains($0.id) && $0.installKind != .none && !$0.installLabel.isEmpty }
            if !installableSkills.isEmpty {
                Button(action: {
                    Task { await installBundledDeps(installableSkills) }
                }) {
                    HStack(spacing: 6) {
                        if skillsInstalling {
                            ProgressView()
                                .scaleEffect(0.6)
                                .progressViewStyle(.circular)
                        } else {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        Text(skillsInstalling ? "安装中..." : "安装依赖 (\(installableSkills.count) 项)")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(height: 36)
                    .padding(.horizontal, 16)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(skillsInstalling)
            }

            // Install log for bundled skills
            if !skillsInstallLog.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(skillsInstallLog.enumerated()), id: \.offset) { _, line in
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

            Divider().background(Color.white.opacity(0.06))

            // ClawHub browser section
            VStack(alignment: .leading, spacing: 8) {
                Button(action: { withAnimation { showWebBrowser.toggle() } }) {
                    HStack(spacing: 6) {
                        Image(systemName: showWebBrowser ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white.opacity(0.3))
                        Image(systemName: "globe")
                            .font(.system(size: 12))
                            .foregroundColor(.accentColor)
                        Text("从 ClawHub 浏览 Skills")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)

                if showWebBrowser {
                    SkillsWebBrowser()
                        .frame(height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
            }

            // Install skill by name
            VStack(alignment: .leading, spacing: 8) {
                ConfigLabel(text: "安装技能")
                HStack(spacing: 8) {
                    TextField("", text: $installSkillName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white)
                        .darkPlaceholder("输入 skill 名称，如 @anthropic/weather", show: installSkillName.isEmpty)
                        .padding(8)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    Button(action: {
                        let name = installSkillName.trimmingCharacters(in: .whitespaces)
                        guard !name.isEmpty else { return }
                        Task { await vm.runCLICommand("openclaw plugins install \(name)") }
                    }) {
                        HStack(spacing: 4) {
                            if vm.isRunningCommand {
                                ProgressView()
                                    .scaleEffect(0.5)
                                    .progressViewStyle(.circular)
                            } else {
                                Image(systemName: "arrow.down.circle")
                                    .font(.system(size: 11))
                            }
                            Text("安装")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(installSkillName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.accentColor.opacity(0.3) : Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .disabled(installSkillName.trimmingCharacters(in: .whitespaces).isEmpty || vm.isRunningCommand)
                }

                CommandLogView(vm: vm)
            }

            // Fallback
            if let val = vm.sectionValue(for: "skills") {
                FallbackEditor(
                    sectionKey: "skills",
                    value: val,
                    handledKeys: ["install"],
                    vm: vm
                )
            }
        }
    }

    private func installBundledDeps(_ skills: [BundledSkill]) async {
        await MainActor.run {
            skillsInstalling = true
            skillsInstallLog = []
        }
        for skill in skills {
            await MainActor.run {
                skillsInstallLog.append("==> 安装 \(skill.title) (\(skill.installLabel))...")
            }
            let result = await ShellExecutor.shared.run(skill.installLabel)
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
        await MainActor.run { skillsInstalling = false }
    }
}

// MARK: - Skills WebView Browser

private struct SkillsWebBrowser: NSViewRepresentable {
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        if let url = URL(string: "https://clawhub.ai/skills?sort=downloads") {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

// MARK: - Agents Section Editor

struct AgentsSectionEditor: View {
    @ObservedObject var vm: ConfigEditorViewModel
    @State private var selectedProviderId: String = ""
    @State private var showAddModel = false
    @State private var showAddAgent = false
    @State private var expandedAgentIndex: Int? = nil

    private var currentPrimary: String {
        vm.extractString(section: "agents", path: ["defaults", "model", "primary"])
    }

    private var modelKeys: [String] {
        guard let val = vm.sectionValue(for: "agents") else { return [] }
        if case .object(let topPairs) = val,
           let defaults = topPairs.first(where: { $0.key == "defaults" }),
           case .object(let defaultsPairs) = defaults.value,
           let models = defaultsPairs.first(where: { $0.key == "models" }),
           case .object(let modelPairs) = models.value {
            return modelPairs.map(\.key)
        }
        return []
    }

    private var agentsList: [ConfigValue] {
        vm.extractArray(section: "agents", path: ["list"])
    }

    private func agentId(at index: Int) -> String {
        let agents = agentsList
        guard index < agents.count else { return "agent-\(index)" }
        if case .object(let pairs) = agents[index],
           let idPair = pairs.first(where: { $0.key == "id" }),
           case .string(let s) = idPair.value {
            return s
        }
        return "agent-\(index)"
    }

    private func agentModel(at index: Int) -> String {
        vm.extractString(section: "agents", path: ["list", "\(index)", "model"])
    }

    private func agentBindings(at index: Int) -> [String] {
        let items = vm.extractArray(section: "agents", path: ["list", "\(index)", "bindings"])
        return items.compactMap { val in
            if case .string(let s) = val { return s }
            return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // ── Defaults ──
            ConfigHeader(title: "全局默认", subtitle: "所有 Agent 共享的默认配置")

            // Workspace
            VStack(alignment: .leading, spacing: 6) {
                ConfigLabel(text: "工作区路径")
                ConfigTextField(
                    placeholder: "~/.openclaw/workspace",
                    text: vm.stringBinding(section: "agents", path: ["defaults", "workspace"]),
                    mono: true
                )
            }

            Divider().background(Color.white.opacity(0.06))

            // Default model
            VStack(alignment: .leading, spacing: 6) {
                ConfigLabel(text: "默认模型")
                HStack(spacing: 8) {
                    Menu {
                        ForEach(ModelProvider.ProviderGroup.allCases, id: \.self) { group in
                            let providers = ModelProvider.providers(in: group)
                            if !providers.isEmpty {
                                Section(group.rawValue) {
                                    ForEach(providers, id: \.id) { provider in
                                        if !provider.models.isEmpty {
                                            Menu(provider.title) {
                                                ForEach(provider.models, id: \.self) { model in
                                                    Button(model) {
                                                        vm.updateValue(sectionKey: "agents", path: ["defaults", "model", "primary"], newValue: .string(model))
                                                    }
                                                }
                                            }
                                        } else {
                                            Button(provider.title) {
                                                selectedProviderId = provider.id
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "cpu")
                                .font(.system(size: 11))
                            Text("选择模型")
                                .font(.system(size: 12, weight: .medium))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9))
                        }
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }

                ConfigTextField(
                    placeholder: "anthropic/claude-sonnet-4-5-20250514",
                    text: vm.stringBinding(section: "agents", path: ["defaults", "model", "primary"]),
                    mono: true
                )
                Text("可通过上方菜单选择，或手动输入 provider/model-id")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.25))
            }

            Divider().background(Color.white.opacity(0.06))

            // Models map
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    ConfigLabel(text: "已配置模型")
                    Spacer()
                    Button(action: { showAddModel = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .semibold))
                            Text("添加")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showAddModel) {
                        AddModelPopover(vm: vm, isPresented: $showAddModel)
                    }
                }

                if modelKeys.isEmpty {
                    Text("暂无额外模型配置")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.3))
                } else {
                    ForEach(modelKeys, id: \.self) { modelKey in
                        HStack(spacing: 8) {
                            Image(systemName: "cpu")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.4))
                            Text(modelKey)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Spacer()

                            if modelKey == currentPrimary {
                                Text("默认")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(.accentColor)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            } else {
                                Button("设为默认") {
                                    vm.updateValue(sectionKey: "agents", path: ["defaults", "model", "primary"], newValue: .string(modelKey))
                                }
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.4))
                                .buttonStyle(.plain)
                            }

                            Button(action: {
                                vm.deleteKey(sectionKey: "agents", path: ["defaults", "models", modelKey])
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundColor(.red.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(modelKey == currentPrimary ? Color.accentColor.opacity(0.05) : Color.clear)
                        )
                    }
                }
            }

            // ── Agent List (Multi-Agent) ──
            Divider().background(Color.white.opacity(0.06))

            ConfigHeader(title: "Agent 列表", subtitle: "多 Agent 模式：每个 Agent 拥有独立工作区、认证和会话")

            if agentsList.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.3))
                    Text("当前为单 Agent 模式（默认 main）。添加 Agent 以启用多 Agent 路由。")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.35))
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.03))
                )
            } else {
                ForEach(Array(agentsList.enumerated()), id: \.offset) { index, _ in
                    AgentCardView(
                        vm: vm,
                        index: index,
                        agentId: agentId(at: index),
                        isExpanded: expandedAgentIndex == index,
                        onToggle: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                expandedAgentIndex = expandedAgentIndex == index ? nil : index
                            }
                        },
                        onDelete: {
                            vm.removeArrayItem(sectionKey: "agents", path: ["list"], index: index)
                            if expandedAgentIndex == index { expandedAgentIndex = nil }
                        }
                    )
                }
            }

            // Add agent button
            Button(action: { showAddAgent = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 13))
                    Text("添加 Agent")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.accentColor)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(Color.accentColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showAddAgent) {
                AddAgentPopover(vm: vm, isPresented: $showAddAgent)
            }

            // Fallback
            if let val = vm.sectionValue(for: "agents") {
                FallbackEditor(
                    sectionKey: "agents",
                    value: val,
                    handledKeys: ["defaults", "list"],
                    vm: vm
                )
            }
        }
    }
}

// MARK: - Agent Card View

private struct AgentCardView: View {
    @ObservedObject var vm: ConfigEditorViewModel
    let index: Int
    let agentId: String
    let isExpanded: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void

    @State private var showAddBinding = false
    @State private var newBindingText = ""

    private var basePath: [String] { ["list", "\(index)"] }

    private var bindings: [String] {
        vm.extractArray(section: "agents", path: basePath + ["bindings"]).compactMap { val in
            if case .string(let s) = val { return s }
            return nil
        }
    }

    private var model: String {
        vm.extractString(section: "agents", path: basePath + ["model"])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row (always visible)
            Button(action: onToggle) {
                HStack(spacing: 10) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(agentId)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                        if !model.isEmpty {
                            Text(model)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.white.opacity(0.4))
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    // Binding count badge
                    if !bindings.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.system(size: 9))
                            Text("\(bindings.count)")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))
                }
                .padding(12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 12)

                VStack(alignment: .leading, spacing: 14) {
                    // Agent ID
                    VStack(alignment: .leading, spacing: 6) {
                        ConfigLabel(text: "Agent ID")
                        ConfigTextField(
                            placeholder: "my-agent",
                            text: vm.stringBinding(section: "agents", path: basePath + ["id"]),
                            mono: true
                        )
                    }

                    // Workspace
                    VStack(alignment: .leading, spacing: 6) {
                        ConfigLabel(text: "工作区路径")
                        ConfigTextField(
                            placeholder: "~/.openclaw/workspace-\(agentId)",
                            text: vm.stringBinding(section: "agents", path: basePath + ["workspace"]),
                            mono: true
                        )
                    }

                    // Model
                    VStack(alignment: .leading, spacing: 6) {
                        ConfigLabel(text: "模型")
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
                                                            Button(m) {
                                                                vm.updateValue(sectionKey: "agents", path: basePath + ["model"], newValue: .string(m))
                                                            }
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
                        ConfigTextField(
                            placeholder: "留空则使用全局默认模型",
                            text: vm.stringBinding(section: "agents", path: basePath + ["model"]),
                            mono: true
                        )
                    }

                    // Agent directory
                    VStack(alignment: .leading, spacing: 6) {
                        ConfigLabel(text: "Agent 目录")
                        ConfigTextField(
                            placeholder: "~/.openclaw/agents/\(agentId)/agent",
                            text: vm.stringBinding(section: "agents", path: basePath + ["agentDir"]),
                            mono: true
                        )
                        Text("Agent 的状态和配置存储目录")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.25))
                    }

                    // Exec node binding (per-agent)
                    VStack(alignment: .leading, spacing: 6) {
                        ConfigLabel(text: "Exec 节点绑定")
                        ConfigTextField(
                            placeholder: "留空则使用全局设置",
                            text: vm.stringBinding(section: "agents", path: basePath + ["tools", "exec", "node"]),
                            mono: true
                        )
                        Text("覆盖全局 exec 节点绑定，指定此 Agent 使用的计算节点")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.25))
                    }

                    Divider().background(Color.white.opacity(0.06))

                    // ── Bindings ──
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.branch")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.5))
                                ConfigLabel(text: "路由绑定")
                            }
                            Spacer()
                            Button(action: { showAddBinding = true }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 9, weight: .semibold))
                                    Text("添加")
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                            .popover(isPresented: $showAddBinding) {
                                AddBindingPopover(
                                    vm: vm,
                                    agentIndex: index,
                                    isPresented: $showAddBinding
                                )
                            }
                        }

                        Text("将消息渠道路由到此 Agent，格式：channel[:accountId]")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.25))

                        if bindings.isEmpty {
                            Text("暂无路由绑定 — 消息将由默认 Agent 处理")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.3))
                                .padding(.vertical, 4)
                        } else {
                            ForEach(Array(bindings.enumerated()), id: \.offset) { bIdx, binding in
                                HStack(spacing: 8) {
                                    Image(systemName: channelIcon(for: binding))
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.4))
                                        .frame(width: 16)
                                    Text(binding)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.8))
                                        .lineLimit(1)
                                    Spacer()
                                    Button(action: {
                                        vm.removeArrayItem(sectionKey: "agents", path: basePath + ["bindings"], index: bIdx)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.red.opacity(0.5))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(Color.white.opacity(0.03))
                                )
                            }
                        }
                    }

                    Divider().background(Color.white.opacity(0.06))

                    // Delete agent
                    HStack {
                        Spacer()
                        Button(action: onDelete) {
                            HStack(spacing: 4) {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                Text("删除此 Agent")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.red.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(isExpanded ? 0.04 : 0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(isExpanded ? 0.08 : 0.04), lineWidth: 1)
                )
        )
    }

    private func channelIcon(for binding: String) -> String {
        let channel = binding.split(separator: ":").first.map(String.init) ?? binding
        switch channel {
        case "telegram": return "paperplane"
        case "discord": return "gamecontroller"
        case "whatsapp": return "phone"
        case "slack": return "number"
        case "signal": return "lock.shield"
        case "irc": return "text.bubble"
        case "imessage": return "message"
        case "line": return "ellipsis.message"
        case "matrix": return "square.grid.3x3"
        case "mattermost": return "bubble.left.and.bubble.right"
        default: return "antenna.radiowaves.left.and.right"
        }
    }
}

// MARK: - Add Agent Popover

private struct AddAgentPopover: View {
    @ObservedObject var vm: ConfigEditorViewModel
    @Binding var isPresented: Bool
    @State private var agentName = ""
    @State private var agentModel = ""
    @State private var agentWorkspace = ""

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
                Button("取消") { isPresented = false }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .buttonStyle(.plain)

                Button(action: {
                    let name = agentName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }

                    var pairs: [(key: String, value: ConfigValue)] = [
                        (key: "id", value: .string(name))
                    ]
                    let ws = agentWorkspace.trimmingCharacters(in: .whitespaces)
                    if !ws.isEmpty {
                        pairs.append((key: "workspace", value: .string(ws)))
                    }
                    let m = agentModel.trimmingCharacters(in: .whitespaces)
                    if !m.isEmpty {
                        pairs.append((key: "model", value: .string(m)))
                    }
                    pairs.append((key: "bindings", value: .array([])))

                    vm.appendArrayItem(sectionKey: "agents", path: ["list"], value: .object(pairs))
                    isPresented = false
                }) {
                    Text("创建")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(agentName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.accentColor.opacity(0.3) : Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(agentName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 340)
        .background(Color(red: 0.1, green: 0.1, blue: 0.16))
    }
}

// MARK: - Add Binding Popover

private struct AddBindingPopover: View {
    @ObservedObject var vm: ConfigEditorViewModel
    let agentIndex: Int
    @Binding var isPresented: Bool
    @State private var customBinding = ""
    @State private var selectedChannel = ""
    @State private var accountId = ""

    /// Channels currently configured in the `channels` section of openclaw.json
    private var configuredChannels: [(key: String, title: String, icon: String)] {
        guard let val = vm.sectionValue(for: "channels"),
              case .object(let pairs) = val else { return [] }
        return pairs.map { pair in
            if let ct = ChannelType(rawValue: pair.key) {
                return (key: pair.key, title: ct.title, icon: ct.icon)
            }
            return (key: pair.key, title: pair.key, icon: "antenna.radiowaves.left.and.right")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("添加路由绑定")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)

            Text("绑定格式：channel[:accountId]")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.35))

            // Pick from configured channels
            if configuredChannels.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 11))
                        .foregroundColor(.yellow.opacity(0.7))
                    Text("尚未配置任何频道，请先在 channels 中添加")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.yellow.opacity(0.04))
                )
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(configuredChannels, id: \.key) { ch in
                            Button(action: {
                                selectedChannel = ch.key
                            }) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .stroke(selectedChannel == ch.key ? Color.accentColor : Color.white.opacity(0.2), lineWidth: 1.5)
                                        .frame(width: 12, height: 12)
                                        .overlay(
                                            Circle()
                                                .fill(selectedChannel == ch.key ? Color.accentColor : Color.clear)
                                                .frame(width: 6, height: 6)
                                        )
                                    Image(systemName: ch.icon)
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.5))
                                        .frame(width: 16)
                                    Text(ch.title)
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.85))
                                    Spacer()
                                    Text(ch.key)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.3))
                                }
                                .padding(.vertical, 5)
                                .padding(.horizontal, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(selectedChannel == ch.key ? Color.accentColor.opacity(0.1) : Color.clear)
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 180)
            }

            // Account ID (optional)
            VStack(alignment: .leading, spacing: 4) {
                Text("Account ID（可选）")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                TextField("", text: $accountId)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white)
                    .darkPlaceholder("bot-token-id / 账号标识", show: accountId.isEmpty)
                    .padding(6)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            Divider().overlay(Color.white.opacity(0.06))

            // Or manual input
            VStack(alignment: .leading, spacing: 4) {
                Text("或手动输入绑定")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                HStack(spacing: 6) {
                    TextField("", text: $customBinding)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white)
                        .darkPlaceholder("telegram:bot1", show: customBinding.isEmpty)
                        .padding(6)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    Button("添加") {
                        let b = customBinding.trimmingCharacters(in: .whitespaces)
                        guard !b.isEmpty else { return }
                        vm.appendArrayItem(sectionKey: "agents", path: ["list", "\(agentIndex)", "bindings"], value: .string(b))
                        isPresented = false
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.accentColor)
                    .buttonStyle(.plain)
                    .disabled(customBinding.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            HStack {
                Spacer()
                Button(action: {
                    guard !selectedChannel.isEmpty else { return }
                    let acct = accountId.trimmingCharacters(in: .whitespaces)
                    let binding = acct.isEmpty ? selectedChannel : "\(selectedChannel):\(acct)"
                    vm.appendArrayItem(sectionKey: "agents", path: ["list", "\(agentIndex)", "bindings"], value: .string(binding))
                    isPresented = false
                }) {
                    Text("确定")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(selectedChannel.isEmpty ? Color.accentColor.opacity(0.3) : Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(selectedChannel.isEmpty)
            }
        }
        .padding(14)
        .frame(width: 320)
        .background(Color(red: 0.1, green: 0.1, blue: 0.16))
    }
}

// MARK: - Add Model Popover

private struct AddModelPopover: View {
    @ObservedObject var vm: ConfigEditorViewModel
    @Binding var isPresented: Bool
    @State private var customModelId = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("添加模型")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)

            // Quick pick from providers
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(ModelProvider.all.filter { !$0.models.isEmpty }, id: \.id) { provider in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(provider.title)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                            ForEach(provider.models, id: \.self) { model in
                                Button(action: {
                                    vm.addObjectEntry(
                                        sectionKey: "agents",
                                        path: ["defaults", "models"],
                                        key: model,
                                        value: .object([])
                                    )
                                    isPresented = false
                                }) {
                                    Text(model)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.8))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 6)
                                        .background(Color.white.opacity(0.04))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 200)

            Divider().overlay(Color.white.opacity(0.06))

            // Manual input
            HStack(spacing: 6) {
                TextField("", text: $customModelId)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white)
                    .darkPlaceholder("provider/model-id", show: customModelId.isEmpty)
                    .padding(6)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Button("添加") {
                    let id = customModelId.trimmingCharacters(in: .whitespaces)
                    guard !id.isEmpty else { return }
                    vm.addObjectEntry(
                        sectionKey: "agents",
                        path: ["defaults", "models"],
                        key: id,
                        value: .object([])
                    )
                    isPresented = false
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.accentColor)
                .buttonStyle(.plain)
                .disabled(customModelId.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(14)
        .frame(width: 320)
        .background(Color(red: 0.1, green: 0.1, blue: 0.16))
    }
}

// MARK: - Session Section Editor

struct SessionSectionEditor: View {
    @ObservedObject var vm: ConfigEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ConfigSegment(
                label: "DM 范围策略",
                options: [
                    ("per-channel-peer", "Per Channel Peer"),
                    ("per-channel", "Per Channel"),
                    ("global", "Global"),
                ],
                selection: vm.stringBinding(section: "session", path: ["dmScope"], defaultValue: "per-channel-peer")
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("per-channel-peer: 每个频道中的每个用户独立会话")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.3))
                Text("per-channel: 每个频道共享会话")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.3))
                Text("global: 所有频道共享一个全局会话")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.3))
            }

            // Fallback
            if let val = vm.sectionValue(for: "session") {
                FallbackEditor(
                    sectionKey: "session",
                    value: val,
                    handledKeys: ["dmScope"],
                    vm: vm
                )
            }
        }
    }
}

// MARK: - Plugins Section Editor

struct PluginsSectionEditor: View {
    @ObservedObject var vm: ConfigEditorViewModel
    @State private var installPluginName = ""

    private var pluginPairs: [(key: String, value: ConfigValue)] {
        guard let val = vm.sectionValue(for: "plugins"),
              case .object(let pairs) = val else { return [] }
        return pairs
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if pluginPairs.isEmpty {
                Text("暂无已安装插件")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.3))
            } else {
                ForEach(pluginPairs, id: \.key) { pair in
                    HStack(spacing: 8) {
                        if case .bool(_) = pair.value {
                            ConfigToggleRow(
                                title: pair.key,
                                isOn: vm.boolBinding(section: "plugins", path: [pair.key])
                            )
                        } else {
                            LeafRow(
                                label: pair.key,
                                value: pair.value,
                                sectionKey: "plugins",
                                path: [pair.key],
                                vm: vm,
                                depth: 0
                            )
                        }
                    }
                }
            }

            // Install plugin
            Divider().background(Color.white.opacity(0.06)).padding(.vertical, 4)
            VStack(alignment: .leading, spacing: 6) {
                ConfigLabel(text: "安装插件")
                HStack(spacing: 8) {
                    TextField("", text: $installPluginName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white)
                        .darkPlaceholder("插件名称", show: installPluginName.isEmpty)
                        .padding(8)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    Button(action: {
                        let name = installPluginName.trimmingCharacters(in: .whitespaces)
                        guard !name.isEmpty else { return }
                        Task { await vm.runCLICommand("openclaw plugins install \(name)") }
                    }) {
                        HStack(spacing: 4) {
                            if vm.isRunningCommand {
                                ProgressView()
                                    .scaleEffect(0.5)
                                    .progressViewStyle(.circular)
                            } else {
                                Image(systemName: "arrow.down.circle")
                                    .font(.system(size: 11))
                            }
                            Text("安装")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(installPluginName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.accentColor.opacity(0.3) : Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .disabled(installPluginName.trimmingCharacters(in: .whitespaces).isEmpty || vm.isRunningCommand)
                }

                CommandLogView(vm: vm)
            }
        }
    }
}

// MARK: - Tools Section Editor

struct ToolsSectionEditor: View {
    @ObservedObject var vm: ConfigEditorViewModel
    @State private var newAllowItem = ""
    @State private var newDenyItem = ""
    @State private var newProviderKey = ""
    @State private var showAddProvider = false
    @State private var newSafeBin = ""
    @State private var newPathPrepend = ""
    @State private var newElevatedChannel = ""
    @State private var newElevatedId = ""

    // MARK: - Extraction Helpers

    private func toolsStringArray(path: [String]) -> [String] {
        vm.extractArray(section: "tools", path: path).compactMap { val in
            if case .string(let s) = val { return s }
            return nil
        }
    }

    private var providerKeys: [String] {
        guard let val = vm.sectionValue(for: "tools"),
              case .object(let pairs) = val,
              let bp = pairs.first(where: { $0.key == "byProvider" }),
              case .object(let providers) = bp.value else { return [] }
        return providers.map(\.key)
    }

    private var elevatedAllowFromChannels: [String] {
        guard let val = vm.sectionValue(for: "tools"),
              case .object(let pairs) = val,
              let elev = pairs.first(where: { $0.key == "elevated" }),
              case .object(let elevPairs) = elev.value,
              let af = elevPairs.first(where: { $0.key == "allowFrom" }),
              case .object(let channels) = af.value else { return [] }
        return channels.map(\.key)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // ── Profile ──
            ConfigSegment(
                label: "工具 Profile",
                options: [
                    ("full", "Full"),
                    ("coding", "Coding"),
                    ("messaging", "Messaging"),
                    ("minimal", "Minimal"),
                ],
                selection: vm.stringBinding(section: "tools", path: ["profile"], defaultValue: "full")
            )
            VStack(alignment: .leading, spacing: 2) {
                Text("full: 全部工具 | coding: 文件/运行时/会话/内存")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.25))
                Text("messaging: 消息收发/会话 | minimal: 仅 session_status")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.25))
            }

            Divider().background(Color.white.opacity(0.06))

            // ── Allow / Deny Lists ──
            ToolsListEditor(
                label: "Allow（允许列表）",
                hint: "工具名或 group:runtime、group:fs 等",
                items: toolsStringArray(path: ["allow"]),
                newItem: $newAllowItem,
                onAdd: { item in
                    vm.appendArrayItem(sectionKey: "tools", path: ["allow"], value: .string(item))
                },
                onRemove: { idx in
                    vm.removeArrayItem(sectionKey: "tools", path: ["allow"], index: idx)
                }
            )

            ToolsListEditor(
                label: "Deny（拒绝列表）",
                hint: "deny 优先级高于 allow，被拒绝的工具不可恢复",
                items: toolsStringArray(path: ["deny"]),
                newItem: $newDenyItem,
                onAdd: { item in
                    vm.appendArrayItem(sectionKey: "tools", path: ["deny"], value: .string(item))
                },
                onRemove: { idx in
                    vm.removeArrayItem(sectionKey: "tools", path: ["deny"], index: idx)
                }
            )

            Divider().background(Color.white.opacity(0.06))

            // ── Exec Configuration ──
            ConfigHeader(title: "Exec 执行配置", subtitle: "命令执行的宿主、安全策略与审批行为")

            ConfigSegment(
                label: "执行宿主 (host)",
                options: [
                    ("sandbox", "Sandbox"),
                    ("gateway", "Gateway"),
                    ("node", "Node"),
                ],
                selection: vm.stringBinding(section: "tools", path: ["exec", "host"], defaultValue: "sandbox")
            )

            ConfigSegment(
                label: "安全级别 (security)",
                options: [
                    ("deny", "Deny"),
                    ("allowlist", "Allowlist"),
                    ("full", "Full"),
                ],
                selection: vm.stringBinding(section: "tools", path: ["exec", "security"], defaultValue: "deny")
            )
            Text("deny: 仅允许安全命令 | allowlist: 白名单审批 | full: 不限制")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.25))

            ConfigSegment(
                label: "审批模式 (ask)",
                options: [
                    ("off", "Off"),
                    ("on-miss", "On Miss"),
                    ("always", "Always"),
                ],
                selection: vm.stringBinding(section: "tools", path: ["exec", "ask"], defaultValue: "on-miss")
            )
            Text("off: 不询问 | on-miss: 未命中白名单时询问 | always: 每次都询问")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.25))

            // Node binding
            VStack(alignment: .leading, spacing: 6) {
                ConfigLabel(text: "Exec 节点绑定 (node)")
                ConfigTextField(
                    placeholder: "节点 ID / 名称 / IP（留空自动选择）",
                    text: vm.stringBinding(section: "tools", path: ["exec", "node"]),
                    mono: true
                )
            }

            // notifyOnExit
            ConfigToggleRow(
                title: "后台任务完成通知",
                subtitle: "notifyOnExit — 后台执行完成时发送系统事件",
                isOn: vm.boolBinding(section: "tools", path: ["exec", "notifyOnExit"], defaultValue: true)
            )

            // approvalRunningNoticeMs
            VStack(alignment: .leading, spacing: 6) {
                ConfigLabel(text: "审批等待提示延迟 (ms)")
                ConfigTextField(
                    placeholder: "10000",
                    text: vm.numberStringBinding(section: "tools", path: ["exec", "approvalRunningNoticeMs"]),
                    mono: true
                )
            }

            // pathPrepend
            ToolsListEditor(
                label: "PATH 前缀目录 (pathPrepend)",
                hint: "额外目录会被加到 PATH 最前面",
                items: toolsStringArray(path: ["exec", "pathPrepend"]),
                newItem: $newPathPrepend,
                onAdd: { item in
                    vm.appendArrayItem(sectionKey: "tools", path: ["exec", "pathPrepend"], value: .string(item))
                },
                onRemove: { idx in
                    vm.removeArrayItem(sectionKey: "tools", path: ["exec", "pathPrepend"], index: idx)
                }
            )

            // safeBins
            ToolsListEditor(
                label: "安全二进制 (safeBins)",
                hint: "仅允许 stdin 输入的安全命令，默认: jq, cut, uniq, head, tail, tr, wc",
                items: toolsStringArray(path: ["exec", "safeBins"]),
                newItem: $newSafeBin,
                onAdd: { item in
                    vm.appendArrayItem(sectionKey: "tools", path: ["exec", "safeBins"], value: .string(item))
                },
                onRemove: { idx in
                    vm.removeArrayItem(sectionKey: "tools", path: ["exec", "safeBins"], index: idx)
                }
            )

            Divider().background(Color.white.opacity(0.06))

            // ── Web Tools ──
            ConfigHeader(title: "Web 工具配置", subtitle: "web_search 与 web_fetch 参数")

            // web.search
            ConfigToggleRow(
                title: "Web Search",
                subtitle: "启用网页搜索工具",
                isOn: vm.boolBinding(section: "tools", path: ["web", "search", "enabled"], defaultValue: true)
            )
            VStack(alignment: .leading, spacing: 6) {
                ConfigLabel(text: "搜索最大结果数")
                ConfigTextField(
                    placeholder: "5",
                    text: vm.numberStringBinding(section: "tools", path: ["web", "search", "maxResults"]),
                    mono: true
                )
            }
            VStack(alignment: .leading, spacing: 6) {
                ConfigLabel(text: "搜索超时 (秒)")
                ConfigTextField(
                    placeholder: "30",
                    text: vm.numberStringBinding(section: "tools", path: ["web", "search", "timeoutSeconds"]),
                    mono: true
                )
            }
            VStack(alignment: .leading, spacing: 6) {
                ConfigLabel(text: "搜索缓存 TTL (分钟)")
                ConfigTextField(
                    placeholder: "15",
                    text: vm.numberStringBinding(section: "tools", path: ["web", "search", "cacheTtlMinutes"]),
                    mono: true
                )
            }

            Divider().background(Color.white.opacity(0.04)).padding(.vertical, 2)

            // web.fetch
            ConfigToggleRow(
                title: "Web Fetch",
                subtitle: "启用网页抓取工具",
                isOn: vm.boolBinding(section: "tools", path: ["web", "fetch", "enabled"], defaultValue: true)
            )
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    ConfigLabel(text: "最大字符数")
                    ConfigTextField(
                        placeholder: "50000",
                        text: vm.numberStringBinding(section: "tools", path: ["web", "fetch", "maxChars"]),
                        mono: true
                    )
                }
                VStack(alignment: .leading, spacing: 6) {
                    ConfigLabel(text: "最大响应字节")
                    ConfigTextField(
                        placeholder: "2000000",
                        text: vm.numberStringBinding(section: "tools", path: ["web", "fetch", "maxResponseBytes"]),
                        mono: true
                    )
                }
            }
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    ConfigLabel(text: "超时 (秒)")
                    ConfigTextField(
                        placeholder: "30",
                        text: vm.numberStringBinding(section: "tools", path: ["web", "fetch", "timeoutSeconds"]),
                        mono: true
                    )
                }
                VStack(alignment: .leading, spacing: 6) {
                    ConfigLabel(text: "最大重定向次数")
                    ConfigTextField(
                        placeholder: "3",
                        text: vm.numberStringBinding(section: "tools", path: ["web", "fetch", "maxRedirects"]),
                        mono: true
                    )
                }
            }
            ConfigToggleRow(
                title: "Readability 模式",
                subtitle: "提取正文内容，去除导航/广告等干扰元素",
                isOn: vm.boolBinding(section: "tools", path: ["web", "fetch", "readability"], defaultValue: true)
            )

            Divider().background(Color.white.opacity(0.06))

            // ── Elevated Mode ──
            ConfigHeader(title: "Elevated 模式", subtitle: "提权执行，需配合发送者白名单")

            ConfigToggleRow(
                title: "启用 Elevated 模式",
                subtitle: "允许通过聊天指令提升执行权限",
                isOn: vm.boolBinding(section: "tools", path: ["elevated", "enabled"])
            )

            // allowFrom per channel
            VStack(alignment: .leading, spacing: 8) {
                ConfigLabel(text: "发送者白名单 (allowFrom)")
                Text("按频道设置允许提权的用户 ID")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.25))

                if elevatedAllowFromChannels.isEmpty {
                    Text("暂无白名单配置")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.3))
                } else {
                    ForEach(elevatedAllowFromChannels, id: \.self) { channel in
                        ElevatedChannelRow(vm: vm, channel: channel)
                    }
                }

                // Add channel
                HStack(spacing: 6) {
                    TextField("", text: $newElevatedChannel)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white)
                        .darkPlaceholder("频道名 (discord, telegram...)", show: newElevatedChannel.isEmpty)
                        .padding(6)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    Button("添加频道") {
                        let ch = newElevatedChannel.trimmingCharacters(in: .whitespaces)
                        guard !ch.isEmpty else { return }
                        vm.updateValue(sectionKey: "tools", path: ["elevated", "allowFrom", ch], newValue: .array([]))
                        newElevatedChannel = ""
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.accentColor)
                    .buttonStyle(.plain)
                    .disabled(newElevatedChannel.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Divider().background(Color.white.opacity(0.06))

            // ── Loop Detection ──
            ConfigHeader(title: "循环检测", subtitle: "防止工具调用陷入死循环")

            ConfigToggleRow(
                title: "启用循环检测",
                subtitle: "默认关闭，开启后监控重复工具调用模式",
                isOn: vm.boolBinding(section: "tools", path: ["loopDetection", "enabled"])
            )

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    ConfigLabel(text: "历史窗口大小")
                    ConfigTextField(
                        placeholder: "30",
                        text: vm.numberStringBinding(section: "tools", path: ["loopDetection", "historySize"]),
                        mono: true
                    )
                }
                VStack(alignment: .leading, spacing: 6) {
                    ConfigLabel(text: "警告阈值")
                    ConfigTextField(
                        placeholder: "10",
                        text: vm.numberStringBinding(section: "tools", path: ["loopDetection", "warningThreshold"]),
                        mono: true
                    )
                }
            }
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    ConfigLabel(text: "严重阈值")
                    ConfigTextField(
                        placeholder: "20",
                        text: vm.numberStringBinding(section: "tools", path: ["loopDetection", "criticalThreshold"]),
                        mono: true
                    )
                }
                VStack(alignment: .leading, spacing: 6) {
                    ConfigLabel(text: "全局熔断阈值")
                    ConfigTextField(
                        placeholder: "30",
                        text: vm.numberStringBinding(section: "tools", path: ["loopDetection", "globalCircuitBreakerThreshold"]),
                        mono: true
                    )
                }
            }

            // Detectors
            VStack(alignment: .leading, spacing: 6) {
                ConfigLabel(text: "检测器")
                ConfigToggleRow(
                    title: "通用重复检测",
                    subtitle: "genericRepeat",
                    isOn: vm.boolBinding(section: "tools", path: ["loopDetection", "detectors", "genericRepeat"], defaultValue: true)
                )
                ConfigToggleRow(
                    title: "轮询无进展检测",
                    subtitle: "knownPollNoProgress",
                    isOn: vm.boolBinding(section: "tools", path: ["loopDetection", "detectors", "knownPollNoProgress"], defaultValue: true)
                )
                ConfigToggleRow(
                    title: "乒乓检测",
                    subtitle: "pingPong",
                    isOn: vm.boolBinding(section: "tools", path: ["loopDetection", "detectors", "pingPong"], defaultValue: true)
                )
            }

            Divider().background(Color.white.opacity(0.06))

            // ── Provider-specific Profiles ──
            ConfigHeader(title: "Provider 工具策略", subtitle: "按模型提供商覆盖工具 profile")

            if providerKeys.isEmpty {
                Text("暂无 Provider 级别的工具覆盖")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.3))
            } else {
                ForEach(providerKeys, id: \.self) { key in
                    HStack(spacing: 8) {
                        Text(key)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                        Menu {
                            ForEach(["full", "coding", "messaging", "minimal"], id: \.self) { p in
                                Button(p) {
                                    vm.updateValue(sectionKey: "tools", path: ["byProvider", key, "profile"], newValue: .string(p))
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(vm.extractString(section: "tools", path: ["byProvider", key, "profile"], defaultValue: "full"))
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8))
                            }
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        Button(action: {
                            vm.deleteKey(sectionKey: "tools", path: ["byProvider", key])
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundColor(.red.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.03))
                    )
                }
            }

            // Add provider
            HStack(spacing: 6) {
                TextField("", text: $newProviderKey)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white)
                    .darkPlaceholder("provider 名称", show: newProviderKey.isEmpty)
                    .padding(6)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                Button("添加") {
                    let key = newProviderKey.trimmingCharacters(in: .whitespaces)
                    guard !key.isEmpty else { return }
                    vm.addObjectEntry(sectionKey: "tools", path: ["byProvider"], key: key, value: .object([(key: "profile", value: .string("full"))]))
                    newProviderKey = ""
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.accentColor)
                .buttonStyle(.plain)
                .disabled(newProviderKey.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            // Fallback
            if let val = vm.sectionValue(for: "tools") {
                FallbackEditor(
                    sectionKey: "tools",
                    value: val,
                    handledKeys: ["profile", "allow", "deny", "byProvider", "exec", "web", "elevated", "loopDetection"],
                    vm: vm
                )
            }
        }
    }
}

// MARK: - Tools List Editor (reusable allow/deny/safeBins editor)

private struct ToolsListEditor: View {
    let label: String
    let hint: String
    let items: [String]
    @Binding var newItem: String
    let onAdd: (String) -> Void
    let onRemove: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ConfigLabel(text: label)
            if !hint.isEmpty {
                Text(hint)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.25))
            }

            if items.isEmpty {
                Text("（空）")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.25))
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                        HStack(spacing: 4) {
                            Text(item)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.white.opacity(0.8))
                            Button(action: { onRemove(idx) }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.white.opacity(0.06))
                        )
                    }
                }
            }

            HStack(spacing: 6) {
                TextField("", text: $newItem)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white)
                    .darkPlaceholder("输入后回车添加", show: newItem.isEmpty)
                    .padding(6)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .onSubmit {
                        let val = newItem.trimmingCharacters(in: .whitespaces)
                        guard !val.isEmpty else { return }
                        onAdd(val)
                        newItem = ""
                    }
                Button("添加") {
                    let val = newItem.trimmingCharacters(in: .whitespaces)
                    guard !val.isEmpty else { return }
                    onAdd(val)
                    newItem = ""
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.accentColor)
                .buttonStyle(.plain)
                .disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}

// MARK: - Flow Layout (tag chips)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: ProposedViewSize(width: bounds.width, height: nil), subviews: subviews)
        for (index, offset) in result.offsets.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y), proposal: .unspecified)
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, offsets: [CGPoint]) {
        let maxW = proposal.width ?? .infinity
        var offsets: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxW && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            offsets.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalWidth = max(totalWidth, x - spacing)
            totalHeight = y + rowHeight
        }
        return (CGSize(width: totalWidth, height: totalHeight), offsets)
    }
}

// MARK: - Elevated Channel Row

private struct ElevatedChannelRow: View {
    @ObservedObject var vm: ConfigEditorViewModel
    let channel: String
    @State private var newId = ""

    private var ids: [String] {
        vm.extractArray(section: "tools", path: ["elevated", "allowFrom", channel]).compactMap { val in
            if case .string(let s) = val { return s }
            return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(channel)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                Button(action: {
                    vm.deleteKey(sectionKey: "tools", path: ["elevated", "allowFrom", channel])
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundColor(.red.opacity(0.5))
                }
                .buttonStyle(.plain)
            }

            if ids.isEmpty {
                Text("暂无用户 ID")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.25))
            } else {
                FlowLayout(spacing: 4) {
                    ForEach(Array(ids.enumerated()), id: \.offset) { idx, userId in
                        HStack(spacing: 3) {
                            Text(userId)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                            Button(action: {
                                vm.removeArrayItem(sectionKey: "tools", path: ["elevated", "allowFrom", channel], index: idx)
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundColor(.white.opacity(0.3))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.05))
                        )
                    }
                }
            }

            HStack(spacing: 4) {
                TextField("", text: $newId)
                    .textFieldStyle(.plain)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white)
                    .darkPlaceholder("用户 ID / name:xxx / id:xxx", show: newId.isEmpty)
                    .padding(5)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .onSubmit {
                        let val = newId.trimmingCharacters(in: .whitespaces)
                        guard !val.isEmpty else { return }
                        vm.appendArrayItem(sectionKey: "tools", path: ["elevated", "allowFrom", channel], value: .string(val))
                        newId = ""
                    }
                Button("+") {
                    let val = newId.trimmingCharacters(in: .whitespaces)
                    guard !val.isEmpty else { return }
                    vm.appendArrayItem(sectionKey: "tools", path: ["elevated", "allowFrom", channel], value: .string(val))
                    newId = ""
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.accentColor)
                .buttonStyle(.plain)
                .disabled(newId.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
    }
}
