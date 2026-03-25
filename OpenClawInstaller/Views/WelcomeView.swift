import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var viewModel: InstallerViewModel
    @State private var animate = false

    var body: some View {
        VStack(spacing: 0) {
            // Scrollable content area
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer(minLength: 20)

                    // Logo - App Icon
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.accentColor.opacity(0.3), Color.clear],
                                    center: .center,
                                    startRadius: 30,
                                    endRadius: 90
                                )
                            )
                            .frame(width: 160, height: 160)
                            .scaleEffect(animate ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: animate)

                        Image(nsImage: NSApp.applicationIconImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 140, height: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 30))
                    }

                    VStack(spacing: 10) {
                        Text("OpenClaw")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text(viewModel.randomTagline)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                            .italic()
                    }

                    if !viewModel.systemArch.isEmpty {
                        HStack(spacing: 16) {
                            SystemInfoBadge(icon: "cpu", label: "macOS", value: viewModel.systemArch)
                            SystemInfoBadge(icon: "desktopcomputer", label: "平台", value: "Darwin")
                        }
                    }

                    // Existing install info
                    if viewModel.isDetecting {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.7)
                                .progressViewStyle(.circular)
                            Text("检测现有安装...")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    } else if let existing = viewModel.existingInstall {
                        VStack(spacing: 12) {
                            ZStack(alignment: .trailing) {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(.green)
                                        .font(.system(size: 14))
                                    Text("已安装 OpenClaw")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)

                                HStack(spacing: 6) {
                                    Button(action: {
                                        // Open terminal with openclaw
                                        let script = """
                                        tell application "Terminal"
                                            activate
                                            do script "openclaw"
                                        end tell
                                        """
                                        if let appleScript = NSAppleScript(source: script) {
                                            var error: NSDictionary?
                                            appleScript.executeAndReturnError(&error)
                                        }
                                    }) {
                                        Image(systemName: "terminal")
                                            .font(.system(size: 11))
                                            .foregroundColor(.white.opacity(0.4))
                                            .frame(width: 24, height: 24)
                                    }
                                    .buttonStyle(.plain)
                                    .help("打开终端")

                                    Button(action: { viewModel.openDashboard() }) {
                                        Image(systemName: "globe")
                                            .font(.system(size: 11))
                                            .foregroundColor(.white.opacity(0.4))
                                            .frame(width: 24, height: 24)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Dashboard")

                                    Button(action: { viewModel.showConfigEditor = true }) {
                                        Image(systemName: "gearshape")
                                            .font(.system(size: 11))
                                            .foregroundColor(.white.opacity(0.4))
                                            .frame(width: 24, height: 24)
                                    }
                                    .buttonStyle(.plain)
                                    .help("配置")
                                }
                            }

                            VStack(spacing: 6) {
                                HStack(spacing: 6) {
                                    Text("版本")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.4))
                                    Text(existing.version)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.7))
                                }

                                HStack(spacing: 6) {
                                    Text("路径")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.4))
                                    Text(existing.path)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.5))
                                    Text("(\(existing.method))")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.35))
                                }
                            }

                            if existing.hasConfig {
                                Toggle(isOn: $viewModel.backupConfig) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "archivebox")
                                            .font(.system(size: 11))
                                        Text("备份现有配置")
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .foregroundColor(.white.opacity(0.7))
                                }
                                .toggleStyle(.checkbox)
                                .padding(.horizontal, 20)

                                if viewModel.backupConfig {
                                    Text("备份到 ~/.openclaw-backup-<时间戳>")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.35))
                                }
                            }

                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.green.opacity(0.2), lineWidth: 1)
                                )
                        )
                    }

                    // Uninstall complete message
                    if viewModel.uninstallComplete {
                        VStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("卸载完成")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.green)
                            }

                            if let backupPath = viewModel.lastBackupPath {
                                BackupPathView(path: backupPath)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 40)
            }

            // Fixed bottom buttons
            if viewModel.existingInstall != nil && !viewModel.isDetecting {
                HStack(spacing: 12) {
                    Button(action: { viewModel.backupAndReinstall() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 12, weight: .semibold))
                            Text("重新安装")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(width: 130, height: 44)
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        Task { await viewModel.uninstall() }
                    }) {
                        HStack(spacing: 6) {
                            if viewModel.isUninstalling {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .progressViewStyle(.circular)
                            } else {
                                Image(systemName: "trash")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            Text(viewModel.isUninstalling ? "卸载中..." : "卸载")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(width: 110, height: 44)
                        .background(Color.red.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isUninstalling)
                }
                .padding(.bottom, 40)
            } else if !viewModel.isDetecting {
                Button(action: { viewModel.nextStep() }) {
                    HStack(spacing: 8) {
                        Text("开始安装")
                            .font(.system(size: 15, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(width: 200, height: 44)
                    .background(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: Color.accentColor.opacity(0.4), radius: 12, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            animate = true
            Task { await viewModel.detectSystem() }
        }
        .onChange(of: viewModel.showConfigEditor) { show in
            if show {
                ConfigEditorWindowController.shared.showWindow {
                    viewModel.showConfigEditor = false
                }
            }
        }
    }
}

struct BackupPathView: View {
    let path: String
    @State private var copied = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "archivebox.fill")
                .font(.system(size: 11))
                .foregroundColor(.accentColor)

            Text(path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
                .lineLimit(1)

            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(path, forType: .string)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
            }) {
                Image(systemName: copied ? "checkmark" : "doc.on.clipboard")
                    .font(.system(size: 10))
                    .foregroundColor(copied ? .green : .white.opacity(0.4))
            }
            .buttonStyle(.plain)
            .help(copied ? "已复制" : "复制路径")

            Button(action: {
                NSWorkspace.shared.open(URL(fileURLWithPath: path))
            }) {
                Image(systemName: "folder")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }
            .buttonStyle(.plain)
            .help("在 Finder 中打开")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.04))
        )
    }
}

struct SystemInfoBadge: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                Text(value)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
