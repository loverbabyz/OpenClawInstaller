import SwiftUI

struct InstallProgressView: View {
    @EnvironmentObject var viewModel: InstallerViewModel
    @State private var showLog = false
    @State private var logCopied = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("正在安装")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("通过 \(viewModel.selectedMethod.rawValue) 安装 OpenClaw")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5))

            // Progress bar with status text
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.accentColor, Color(red: 0.3, green: 0.8, blue: 0.5)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * viewModel.installProgress, height: 8)
                                .animation(.easeInOut(duration: 0.3), value: viewModel.installProgress)
                        }
                    }
                    .frame(height: 8)

                    Text("\(Int(viewModel.installProgress * 100))%")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 36, alignment: .trailing)
                }
                .padding(.horizontal, 40)

                // Current status line
                if let lastStatus = viewModel.installLog.last(where: { $0.hasPrefix("==>") }) {
                    HStack {
                        Spacer()
                        Text(lastStatus.replacingOccurrences(of: "==> ", with: ""))
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                            .transition(.opacity)
                    }
                    .padding(.horizontal, 40)
                }
            }

            // Collapsible log toggle (left-aligned with progress bar)
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showLog.toggle()
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: showLog ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                        Text("详细日志")
                            .font(.system(size: 12, weight: .medium))
                        if !showLog {
                            Text("(\(viewModel.installLog.count) 行)")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.3))
                        }
                    }
                    .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 40)

            // Log output (collapsible)
            if showLog {
                VStack(spacing: 0) {
                    // Log panel header with copy button
                    HStack {
                        Spacer()
                        if !viewModel.installLog.isEmpty {
                            Button(action: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(viewModel.installLog.joined(separator: "\n"), forType: .string)
                                logCopied = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    logCopied = false
                                }
                            }) {
                                Image(systemName: logCopied ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 10))
                                    .foregroundColor(logCopied ? .green : .white.opacity(0.4))
                            }
                            .buttonStyle(.plain)
                            .help(logCopied ? "已复制" : "复制全部")
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 2) {
                                ForEach(Array(viewModel.installLog.enumerated()), id: \.offset) { index, line in
                                    Text(line)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(logLineColor(line))
                                        .textSelection(.enabled)
                                        .id(index)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 12)
                        }
                        .onChange(of: viewModel.installLog.count) { _ in
                            if let last = viewModel.installLog.indices.last {
                                withAnimation {
                                    proxy.scrollTo(last, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 40)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if let error = viewModel.installError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                }
                .padding(.top, 4)
            }

            Spacer()

            if viewModel.installSucceeded {
                Button(action: { viewModel.nextStep() }) {
                    HStack(spacing: 6) {
                        Text("开始配置")
                            .font(.system(size: 14, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(width: 140, height: 40)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 40)
            } else if viewModel.installCancelled {
                HStack(spacing: 16) {
                    Button(action: { viewModel.goToStep(.dependencyCheck) }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 12, weight: .semibold))
                            Text("返回")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 120, height: 40)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        viewModel.startInstallation()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 12, weight: .semibold))
                            Text("重新安装")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(width: 130, height: 40)
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 40)
            } else if viewModel.installError != nil {
                HStack(spacing: 16) {
                    Button(action: { viewModel.goToStep(.dependencyCheck) }) {
                        Text("返回")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 100, height: 40)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        viewModel.startInstallation()
                    }) {
                        Text("重试")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 100, height: 40)
                            .background(Color.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 40)
            } else {
                // Installing in progress — show cancel button
                Button(action: {
                    viewModel.cancelInstallation()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 13, weight: .semibold))
                        Text("取消安装")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 140, height: 40)
                    .background(Color.red.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 40)
            }
        }
    }

    private func logLineColor(_ line: String) -> Color {
        if line.hasPrefix("==>") { return Color.accentColor }
        if line.lowercased().contains("error") || line.lowercased().contains("fail") { return .red.opacity(0.8) }
        if line.lowercased().contains("warn") { return .yellow.opacity(0.8) }
        return .white.opacity(0.6)
    }
}
