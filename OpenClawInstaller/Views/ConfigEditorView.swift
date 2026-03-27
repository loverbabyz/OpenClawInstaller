import SwiftUI
import AppKit

// MARK: - Window Controller

final class ConfigEditorWindowController: NSObject, NSWindowDelegate {
    static let shared = ConfigEditorWindowController()
    private var window: NSWindow?
    private var onClose: (() -> Void)?

    func showWindow(onClose: @escaping () -> Void) {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }
        self.onClose = onClose

        let hostingView = NSHostingView(rootView: ConfigEditorView(onDismiss: { [weak self] in
            self?.window?.close()
        }).preferredColorScheme(.dark))

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 740, height: 580),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.contentMinSize = NSSize(width: 640, height: 480)
        window.title = "配置编辑器"
        window.center()
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
        onClose = nil
    }
}

// MARK: - Data Model

enum ConfigValue {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case object([(key: String, value: ConfigValue)])
    case array([ConfigValue])
}

private let allKnownSections: [String] = [
    "agents", "channels", "commands", "env", "gateway",
    "hooks", "meta", "models", "plugins", "session", "skills",
    "tools", "web", "wizard",
]

private let sectionIcons: [String: String] = [
    "agents": "cpu",
    "channels": "bubble.left.and.bubble.right",
    "commands": "command",
    "env": "key.fill",
    "gateway": "network",
    "hooks": "link",
    "meta": "info.circle",
    "models": "cpu",
    "plugins": "puzzlepiece",
    "session": "person.2",
    "skills": "wrench.and.screwdriver",
    "tools": "hammer",
    "wizard": "wand.and.stars",
    "web": "globe",
]

private let sectionDescriptions: [String: String] = [
    "agents": "Multi-Agent 管理、路由绑定与默认配置",
    "channels": "Telegram 等消息渠道连接配置",
    "commands": "命令行为与权限控制",
    "gateway": "网关端口、绑定模式和认证设置",
    "hooks": "内置钩子（session-memory、boot-md 等）",
    "meta": "配置元数据（版本、最后修改时间）",
    "models": "模型选择、默认模型与认证管理",
    "plugins": "已安装插件的启用/禁用状态",
    "session": "会话范围与 DM 策略",
    "skills": "技能安装管理器设置",
    "tools": "工具 Profile、Exec 执行策略、Web 工具与安全控制",
    "wizard": "安装向导运行记录",
    "web": "网络搜索服务商配置",
    "env": "环境变量配置（API Key 等）",
]

// MARK: - JSON ↔ ConfigValue

private func parseValue(_ json: Any) -> ConfigValue {
    switch json {
    case let s as String:
        return .string(s)
    case let n as NSNumber:
        if CFBooleanGetTypeID() == CFGetTypeID(n) {
            return .bool(n.boolValue)
        }
        return .number(n.doubleValue)
    case let dict as [String: Any]:
        let pairs = dict.keys.sorted().map { key in
            (key: key, value: parseValue(dict[key]!))
        }
        return .object(pairs)
    case let arr as [Any]:
        return .array(arr.map { parseValue($0) })
    case is NSNull:
        return .null
    default:
        return .string(String(describing: json))
    }
}

private func toJSON(_ value: ConfigValue) -> Any {
    switch value {
    case .string(let s): return s
    case .number(let n):
        if n == n.rounded() && abs(n) < 1e15 { return Int(n) }
        return n
    case .bool(let b): return b
    case .null: return NSNull()
    case .object(let pairs):
        var dict = [String: Any]()
        for (k, v) in pairs { dict[k] = toJSON(v) }
        return dict
    case .array(let items):
        return items.map { toJSON($0) }
    }
}

// MARK: - ViewModel

@MainActor
class ConfigEditorViewModel: ObservableObject {
    @Published var sections: [(key: String, value: ConfigValue)] = []
    @Published var selectedSection: String?
    @Published var hasUnsavedChanges = false
    @Published var saveError: String?
    @Published var saveSuccess = false

    private let configPath: String

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        configPath = "\(home)/.openclaw/openclaw.json"
    }

    func load() {
        if let data = FileManager.default.contents(atPath: configPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            sections = json.keys.sorted().map { key in
                (key: key, value: parseValue(json[key]!))
            }
        }

        // 补全所有已知 section，未配置的显示为空对象
        for sectionKey in allKnownSections {
            if !sections.contains(where: { $0.key == sectionKey }) {
                sections.append((key: sectionKey, value: .object([])))
            }
        }
        // 按 allKnownSections 顺序排序，未知 section 排在末尾
        sections.sort { a, b in
            let ai = allKnownSections.firstIndex(of: a.key) ?? Int.max
            let bi = allKnownSections.firstIndex(of: b.key) ?? Int.max
            if ai != bi { return ai < bi }
            return a.key < b.key
        }

        if selectedSection == nil, let first = sections.first {
            selectedSection = first.key
        }
    }

    func save() {
        var dict = [String: Any]()
        for (k, v) in sections {
            // 跳过空 section，不写入 JSON
            if case .object(let pairs) = v, pairs.isEmpty { continue }
            dict[k] = toJSON(v)
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
            if var jsonString = String(data: jsonData, encoding: .utf8) {
                if !jsonString.hasSuffix("\n") { jsonString += "\n" }
                try jsonString.write(toFile: configPath, atomically: true, encoding: .utf8)
            }
            hasUnsavedChanges = false
            saveSuccess = true
            saveError = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.saveSuccess = false }
        } catch {
            saveError = error.localizedDescription
        }
    }

    func updateValue(sectionKey: String, path: [String], newValue: ConfigValue) {
        guard let idx = sections.firstIndex(where: { $0.key == sectionKey }) else { return }
        sections[idx].value = updateNested(sections[idx].value, path: path, newValue: newValue)
        hasUnsavedChanges = true
    }

    private func updateNested(_ current: ConfigValue, path: [String], newValue: ConfigValue) -> ConfigValue {
        guard let first = path.first else { return newValue }
        let rest = Array(path.dropFirst())

        switch current {
        case .object(var pairs):
            if let idx = pairs.firstIndex(where: { $0.key == first }) {
                pairs[idx].value = updateNested(pairs[idx].value, path: rest, newValue: newValue)
            } else {
                // Create intermediate path if missing
                let child: ConfigValue = rest.isEmpty ? newValue : updateNested(.object([]), path: rest, newValue: newValue)
                pairs.append((key: first, value: child))
            }
            return .object(pairs)
        case .array(var items):
            if let index = Int(first), index < items.count {
                items[index] = updateNested(items[index], path: rest, newValue: newValue)
            }
            return .array(items)
        default:
            return current
        }
    }

    // MARK: - Extraction Helpers

    private func navigateTo(section: String, path: [String]) -> ConfigValue? {
        guard let sectionValue = sections.first(where: { $0.key == section })?.value else { return nil }
        var current = sectionValue
        for key in path {
            switch current {
            case .object(let pairs):
                guard let found = pairs.first(where: { $0.key == key }) else { return nil }
                current = found.value
            case .array(let items):
                guard let index = Int(key), index < items.count else { return nil }
                current = items[index]
            default:
                return nil
            }
        }
        return current
    }

    func extractString(section: String, path: [String], defaultValue: String = "") -> String {
        guard let val = navigateTo(section: section, path: path) else { return defaultValue }
        if case .string(let s) = val { return s }
        if case .number(let n) = val { return n == n.rounded() && abs(n) < 1e15 ? String(Int(n)) : String(n) }
        return defaultValue
    }

    func extractBool(section: String, path: [String], defaultValue: Bool = false) -> Bool {
        guard let val = navigateTo(section: section, path: path) else { return defaultValue }
        if case .bool(let b) = val { return b }
        return defaultValue
    }

    func extractNumber(section: String, path: [String]) -> Double? {
        guard let val = navigateTo(section: section, path: path) else { return nil }
        if case .number(let n) = val { return n }
        return nil
    }

    func sectionValue(for key: String) -> ConfigValue? {
        sections.first(where: { $0.key == key })?.value
    }

    // MARK: - Binding Helpers

    func stringBinding(section: String, path: [String], defaultValue: String = "") -> Binding<String> {
        Binding<String>(
            get: { self.extractString(section: section, path: path, defaultValue: defaultValue) },
            set: { self.updateValue(sectionKey: section, path: path, newValue: .string($0)) }
        )
    }

    func boolBinding(section: String, path: [String], defaultValue: Bool = false) -> Binding<Bool> {
        Binding<Bool>(
            get: { self.extractBool(section: section, path: path, defaultValue: defaultValue) },
            set: { self.updateValue(sectionKey: section, path: path, newValue: .bool($0)) }
        )
    }

    func numberStringBinding(section: String, path: [String]) -> Binding<String> {
        Binding<String>(
            get: {
                if let n = self.extractNumber(section: section, path: path) {
                    return n == n.rounded() && abs(n) < 1e15 ? String(Int(n)) : String(n)
                }
                return self.extractString(section: section, path: path)
            },
            set: {
                if let d = Double($0) {
                    self.updateValue(sectionKey: section, path: path, newValue: .number(d))
                } else {
                    self.updateValue(sectionKey: section, path: path, newValue: .string($0))
                }
            }
        )
    }

    // MARK: - Add / Delete Operations

    func addObjectEntry(sectionKey: String, path: [String], key: String, value: ConfigValue) {
        guard let idx = sections.firstIndex(where: { $0.key == sectionKey }) else {
            // Section doesn't exist yet, create it
            let newSection: ConfigValue
            if path.isEmpty {
                newSection = .object([(key: key, value: value)])
            } else {
                var built: ConfigValue = .object([(key: key, value: value)])
                for p in path.reversed() {
                    built = .object([(key: p, value: built)])
                }
                newSection = built
            }
            sections.append((key: sectionKey, value: newSection))
            sections.sort { $0.key < $1.key }
            hasUnsavedChanges = true
            return
        }
        sections[idx].value = addEntry(sections[idx].value, path: path, key: key, value: value)
        hasUnsavedChanges = true
    }

    private func addEntry(_ current: ConfigValue, path: [String], key: String, value: ConfigValue) -> ConfigValue {
        if path.isEmpty {
            switch current {
            case .object(var pairs):
                if pairs.firstIndex(where: { $0.key == key }) == nil {
                    pairs.append((key: key, value: value))
                }
                return .object(pairs)
            default:
                return .object([(key: key, value: value)])
            }
        }
        let first = path[0]
        let rest = Array(path.dropFirst())
        switch current {
        case .object(var pairs):
            if let idx = pairs.firstIndex(where: { $0.key == first }) {
                pairs[idx].value = addEntry(pairs[idx].value, path: rest, key: key, value: value)
            } else {
                let child = addEntry(.object([]), path: rest, key: key, value: value)
                pairs.append((key: first, value: child))
            }
            return .object(pairs)
        default:
            let child = addEntry(.object([]), path: rest, key: key, value: value)
            return .object([(key: first, value: child)])
        }
    }

    func deleteKey(sectionKey: String, path: [String]) {
        guard !path.isEmpty,
              let idx = sections.firstIndex(where: { $0.key == sectionKey }) else { return }
        sections[idx].value = removeKey(sections[idx].value, path: path)
        hasUnsavedChanges = true
    }

    private func removeKey(_ current: ConfigValue, path: [String]) -> ConfigValue {
        guard let first = path.first else { return current }
        let rest = Array(path.dropFirst())
        switch current {
        case .object(var pairs):
            if rest.isEmpty {
                pairs.removeAll { $0.key == first }
            } else if let idx = pairs.firstIndex(where: { $0.key == first }) {
                pairs[idx].value = removeKey(pairs[idx].value, path: rest)
            }
            return .object(pairs)
        default:
            return current
        }
    }

    // MARK: - Array Operations

    func appendArrayItem(sectionKey: String, path: [String], value: ConfigValue) {
        guard let idx = sections.firstIndex(where: { $0.key == sectionKey }) else {
            // Section doesn't exist, create it with path leading to an array
            var built: ConfigValue = .array([value])
            for p in path.reversed() {
                built = .object([(key: p, value: built)])
            }
            sections.append((key: sectionKey, value: built))
            sections.sort { $0.key < $1.key }
            hasUnsavedChanges = true
            return
        }
        sections[idx].value = appendItem(sections[idx].value, path: path, value: value)
        hasUnsavedChanges = true
    }

    private func appendItem(_ current: ConfigValue, path: [String], value: ConfigValue) -> ConfigValue {
        if path.isEmpty {
            switch current {
            case .array(var items):
                items.append(value)
                return .array(items)
            default:
                return .array([value])
            }
        }
        let first = path[0]
        let rest = Array(path.dropFirst())
        switch current {
        case .object(var pairs):
            if let idx = pairs.firstIndex(where: { $0.key == first }) {
                pairs[idx].value = appendItem(pairs[idx].value, path: rest, value: value)
            } else {
                let child = appendItem(.array([]), path: rest, value: value)
                pairs.append((key: first, value: child))
            }
            return .object(pairs)
        case .array(var items):
            if let index = Int(first), index < items.count {
                items[index] = appendItem(items[index], path: rest, value: value)
            }
            return .array(items)
        default:
            let child = appendItem(.array([]), path: rest, value: value)
            return .object([(key: first, value: child)])
        }
    }

    func removeArrayItem(sectionKey: String, path: [String], index: Int) {
        guard let idx = sections.firstIndex(where: { $0.key == sectionKey }) else { return }
        sections[idx].value = removeItem(sections[idx].value, path: path, index: index)
        hasUnsavedChanges = true
    }

    private func removeItem(_ current: ConfigValue, path: [String], index: Int) -> ConfigValue {
        if path.isEmpty {
            switch current {
            case .array(var items):
                guard index >= 0 && index < items.count else { return current }
                items.remove(at: index)
                return .array(items)
            default:
                return current
            }
        }
        let first = path[0]
        let rest = Array(path.dropFirst())
        switch current {
        case .object(var pairs):
            if let idx = pairs.firstIndex(where: { $0.key == first }) {
                pairs[idx].value = removeItem(pairs[idx].value, path: rest, index: index)
            }
            return .object(pairs)
        case .array(var items):
            if let arrIdx = Int(first), arrIdx < items.count {
                items[arrIdx] = removeItem(items[arrIdx], path: rest, index: index)
            }
            return .array(items)
        default:
            return current
        }
    }

    func extractArray(section: String, path: [String]) -> [ConfigValue] {
        guard let val = navigateTo(section: section, path: path) else { return [] }
        if case .array(let items) = val { return items }
        return []
    }

    // MARK: - CLI Command Execution

    @Published var commandLog: [String] = []
    @Published var isRunningCommand = false

    func runCLICommand(_ command: String) async {
        await MainActor.run {
            isRunningCommand = true
            commandLog = ["==> \(command)"]
        }
        let result = await ShellExecutor.shared.run(command)
        let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        await MainActor.run {
            if !output.isEmpty {
                commandLog.append(contentsOf: output.components(separatedBy: "\n"))
            }
            if result.exitCode == 0 {
                commandLog.append("✓ 完成 (exit 0)")
            } else {
                commandLog.append("✗ 失败 (exit \(result.exitCode))")
            }
            isRunningCommand = false
        }
    }
}

// MARK: - Views

struct ConfigEditorView: View {
    var onDismiss: (() -> Void)?
    @StateObject private var vm = ConfigEditorViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Main content: sidebar + detail
            HStack(spacing: 0) {
                // Sidebar
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 2) {
                        ForEach(vm.sections, id: \.key) { section in
                            let sectionEmpty: Bool = {
                                if case .object(let pairs) = section.value { return pairs.isEmpty }
                                return false
                            }()
                            let isSelected = vm.selectedSection == section.key

                            Button(action: { vm.selectedSection = section.key }) {
                                HStack(spacing: 8) {
                                    Image(systemName: sectionIcons[section.key] ?? "doc.text")
                                        .font(.system(size: 12))
                                        .foregroundColor(isSelected ? .accentColor : .white.opacity(sectionEmpty ? 0.2 : 0.4))
                                        .frame(width: 18)
                                    Text(section.key)
                                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                                        .foregroundColor(isSelected ? .white : .white.opacity(sectionEmpty ? 0.35 : 0.7))
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(10)
                }
                .frame(width: 170)
                .background(Color.white.opacity(0.02))

                Divider().overlay(Color.white.opacity(0.06))

                // Detail panel
                VStack(alignment: .leading, spacing: 0) {
                    if let key = vm.selectedSection,
                       let section = vm.sections.first(where: { $0.key == key }) {
                        // Section header
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: sectionIcons[key] ?? "doc.text")
                                    .font(.system(size: 14))
                                    .foregroundColor(.accentColor)
                                Text(key)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            if let desc = sectionDescriptions[key] {
                                Text(desc)
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)

                        Divider().overlay(Color.white.opacity(0.04))

                        // Editable fields
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 0) {
                                sectionDetailView(key: key, value: section.value)
                            }
                            .padding(16)
                        }
                    } else {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("选择左侧的配置项")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.3))
                            Spacer()
                        }
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider().overlay(Color.white.opacity(0.06))

            // Bottom bar
            HStack(spacing: 12) {
                if let error = vm.saveError {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 11))
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                        .lineLimit(1)
                } else if vm.hasUnsavedChanges {
                    Text("未保存的更改")
                        .font(.system(size: 11))
                        .foregroundColor(.yellow.opacity(0.7))
                }
                Spacer()

                Button("取消") { onDismiss?() }
                    .buttonStyle(.plain)
                    .foregroundColor(.white.opacity(0.6))
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Button(action: {
                    vm.save()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: vm.saveSuccess ? "checkmark" : "square.and.arrow.down")
                            .font(.system(size: 11, weight: .semibold))
                        Text(vm.saveSuccess ? "已保存" : "保存")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(vm.hasUnsavedChanges ? Color.accentColor : Color.accentColor.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(!vm.hasUnsavedChanges && !vm.saveSuccess)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.03))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.08, green: 0.08, blue: 0.14))
        .preferredColorScheme(.dark)
        .onAppear { vm.load() }
    }

    @ViewBuilder
    private func sectionDetailView(key: String, value: ConfigValue) -> some View {
        switch key {
        case "gateway":
            GatewaySectionEditor(vm: vm)
        case "channels":
            ChannelsSectionEditor(vm: vm)
        case "web":
            WebSectionEditor(vm: vm)
        case "hooks":
            HooksSectionEditor(vm: vm)
        case "skills":
            SkillsSectionEditor(vm: vm)
        case "agents":
            AgentsSectionEditor(vm: vm)
        case "session":
            SessionSectionEditor(vm: vm)
        case "models":
            ModelsSectionEditor(vm: vm)
        case "plugins":
            PluginsSectionEditor(vm: vm)
        case "tools":
            ToolsSectionEditor(vm: vm)
        default:
            ConfigNodeEditor(
                value: value,
                sectionKey: key,
                path: [],
                vm: vm,
                depth: 0
            )
        }
    }
}

// MARK: - Radio Group Component

struct ConfigRadioGroup: View {
    let label: String
    let options: [(value: String, title: String, subtitle: String)]
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ConfigLabel(text: label)
            ForEach(options, id: \.value) { option in
                Button(action: { selection = option.value }) {
                    HStack(spacing: 10) {
                        Circle()
                            .stroke(selection == option.value ? Color.accentColor : Color.white.opacity(0.2), lineWidth: 1.5)
                            .frame(width: 14, height: 14)
                            .overlay(
                                Circle()
                                    .fill(selection == option.value ? Color.accentColor : Color.clear)
                                    .frame(width: 7, height: 7)
                            )
                        VStack(alignment: .leading, spacing: 1) {
                            Text(option.title)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                            if !option.subtitle.isEmpty {
                                Text(option.subtitle)
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.35))
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Recursive Node Editor

struct ConfigNodeEditor: View {
    let value: ConfigValue
    let sectionKey: String
    let path: [String]
    @ObservedObject var vm: ConfigEditorViewModel
    let depth: Int

    var body: some View {
        switch value {
        case .object(let pairs):
            ForEach(Array(pairs.enumerated()), id: \.offset) { _, pair in
                let childPath = path + [pair.key]
                VStack(alignment: .leading, spacing: 0) {
                    if isLeaf(pair.value) {
                        LeafRow(
                            label: pair.key,
                            value: pair.value,
                            sectionKey: sectionKey,
                            path: childPath,
                            vm: vm,
                            depth: depth
                        )
                    } else {
                        // Nested object/array header
                        NestedSection(
                            label: pair.key,
                            value: pair.value,
                            sectionKey: sectionKey,
                            path: childPath,
                            vm: vm,
                            depth: depth
                        )
                    }
                }
            }
        case .array(let items):
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                let childPath = path + [String(index)]
                if isLeaf(item) {
                    LeafRow(
                        label: "[\(index)]",
                        value: item,
                        sectionKey: sectionKey,
                        path: childPath,
                        vm: vm,
                        depth: depth
                    )
                } else {
                    NestedSection(
                        label: "[\(index)]",
                        value: item,
                        sectionKey: sectionKey,
                        path: childPath,
                        vm: vm,
                        depth: depth
                    )
                }
            }
        default:
            EmptyView()
        }
    }

    private func isLeaf(_ v: ConfigValue) -> Bool {
        switch v {
        case .object, .array: return false
        default: return true
        }
    }
}

// MARK: - Leaf Value Row

struct LeafRow: View {
    let label: String
    let value: ConfigValue
    let sectionKey: String
    let path: [String]
    @ObservedObject var vm: ConfigEditorViewModel
    let depth: Int

    @State private var showSecure = false

    private var isSensitive: Bool {
        let lower = label.lowercased()
        return lower.contains("token") || lower.contains("password") || lower.contains("secret") || lower.contains("key")
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: max(100 - CGFloat(depth) * 10, 60), alignment: .trailing)

            valueEditor
                .frame(maxWidth: .infinity)
        }
        .padding(.leading, CGFloat(depth) * 16)
        .padding(.vertical, 5)
    }

    @ViewBuilder
    private var valueEditor: some View {
        switch value {
        case .bool(let b):
            HStack {
                Toggle("", isOn: Binding(
                    get: { b },
                    set: { vm.updateValue(sectionKey: sectionKey, path: path, newValue: .bool($0)) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                Spacer()
            }

        case .string(let s):
            HStack(spacing: 6) {
                if isSensitive && !showSecure {
                    SecureField("", text: Binding(
                        get: { s },
                        set: { vm.updateValue(sectionKey: sectionKey, path: path, newValue: .string($0)) }
                    ))
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    TextField("", text: Binding(
                        get: { s },
                        set: { vm.updateValue(sectionKey: sectionKey, path: path, newValue: .string($0)) }
                    ))
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                if isSensitive {
                    Button(action: { showSecure.toggle() }) {
                        Image(systemName: showSecure ? "eye.slash" : "eye")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .help(showSecure ? "隐藏" : "显示")
                }
            }

        case .number(let n):
            let display = n == n.rounded() && abs(n) < 1e15 ? String(Int(n)) : String(n)
            TextField("", text: Binding(
                get: { display },
                set: {
                    if let d = Double($0) {
                        vm.updateValue(sectionKey: sectionKey, path: path, newValue: .number(d))
                    }
                }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 12, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .frame(width: 100)

        case .null:
            Text("null")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.25))
                .italic()

        default:
            EmptyView()
        }
    }
}

// MARK: - Nested Section

struct NestedSection: View {
    let label: String
    let value: ConfigValue
    let sectionKey: String
    let path: [String]
    @ObservedObject var vm: ConfigEditorViewModel
    let depth: Int

    @State private var expanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() } }) {
                HStack(spacing: 6) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.3))
                        .frame(width: 12)
                    Text(label)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(.accentColor.opacity(0.8))
                    if case .object(let pairs) = value {
                        Text("(\(pairs.count))")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.2))
                    } else if case .array(let items) = value {
                        Text("[\(items.count)]")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.2))
                    }
                    Spacer()
                }
                .padding(.leading, CGFloat(depth) * 16)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            if expanded {
                ConfigNodeEditor(
                    value: value,
                    sectionKey: sectionKey,
                    path: path,
                    vm: vm,
                    depth: depth + 1
                )
            }
        }
    }
}
