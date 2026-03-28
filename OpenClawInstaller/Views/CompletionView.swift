import SwiftUI

struct CompletionView: View {
    @EnvironmentObject var viewModel: InstallerViewModel
    @State private var showConfetti = false
    @State private var showLog = false
    @State private var logCopied = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Success animation
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 120, height: 120)
                    .scaleEffect(showConfetti ? 1.0 : 0.5)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6), value: showConfetti)

                Circle()
                    .fill(Color.green.opacity(0.08))
                    .frame(width: 160, height: 160)
                    .scaleEffect(showConfetti ? 1.0 : 0.3)
                    .animation(.spring(response: 0.8, dampingFraction: 0.5), value: showConfetti)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.green)
                    .scaleEffect(showConfetti ? 1.0 : 0.0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.2), value: showConfetti)
            }

            VStack(spacing: 10) {
                Text("安装完成!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(showConfetti ? 1 : 0)
                    .animation(.easeIn(duration: 0.4).delay(0.4), value: showConfetti)

                Text("OpenClaw 已成功安装到你的系统")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
                    .opacity(showConfetti ? 1 : 0)
                    .animation(.easeIn(duration: 0.4).delay(0.5), value: showConfetti)
            }

            // Quick start guide
            VStack(alignment: .leading, spacing: 12) {
                Text("快速开始")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))

                CommandHintRow(command: "openclaw", description: "启动 OpenClaw")
                CommandHintRow(command: "openclaw --help", description: "查看帮助信息")
                CommandHintRow(command: "openclaw onboard", description: "运行入门引导")
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 50)
            .opacity(showConfetti ? 1 : 0)
            .animation(.easeIn(duration: 0.4).delay(0.6), value: showConfetti)

            Spacer()

            HStack(spacing: 12) {
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
                    HStack(spacing: 6) {
                        Image(systemName: "terminal")
                            .font(.system(size: 12, weight: .semibold))
                        Text("打开终端")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(width: 130, height: 44)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Button(action: { viewModel.openDashboard() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "globe")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Dashboard")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(width: 140, height: 44)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Button(action: {
                    viewModel.showConfigEditor = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 12, weight: .semibold))
                        Text("配置")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(width: 100, height: 44)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Button(action: {
                    viewModel.showDoctor = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "stethoscope")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Doctor")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(width: 110, height: 44)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 40)
        }
        .onAppear { showConfetti = true }
        .onChange(of: viewModel.showConfigEditor) { show in
            if show {
                ConfigEditorWindowController.shared.showWindow {
                    viewModel.showConfigEditor = false
                }
            }
        }
        .sheet(isPresented: $viewModel.showDoctor) {
            DoctorView()
                .environmentObject(viewModel)
        }
    }

    private func logLineColor(_ line: String) -> Color {
        if line.hasPrefix("==>") { return Color.accentColor }
        if line.lowercased().contains("error") || line.lowercased().contains("fail") { return .red.opacity(0.8) }
        if line.lowercased().contains("warn") { return .yellow.opacity(0.8) }
        return .white.opacity(0.6)
    }
}

struct CommandHintRow: View {
    let command: String
    let description: String
    @State private var copied = false

    var body: some View {
        HStack(spacing: 10) {
            Text("$")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.accentColor)

            Text(command)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))

            Spacer()

            Text(description)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.35))

            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(command, forType: .string)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    copied = false
                }
            }) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11))
                    .foregroundColor(copied ? .green : .white.opacity(0.3))
            }
            .buttonStyle(.plain)
            .help(copied ? "已复制" : "复制命令")
        }
        .padding(.vertical, 4)
    }
}
