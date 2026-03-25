import SwiftUI

struct DoctorView: View {
    @EnvironmentObject var viewModel: InstallerViewModel
    @State private var logCopied = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "stethoscope")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.accentColor)
                Text("OpenClaw Doctor")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()

                if !viewModel.doctorOutput.isEmpty {
                    Button(action: {
                        let text = viewModel.doctorOutput.joined(separator: "\n")
                            + (viewModel.doctorFixDone ? "\n\n--- Fix Output ---\n" + viewModel.doctorFixOutput.joined(separator: "\n") : "")
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                        logCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { logCopied = false }
                    }) {
                        Image(systemName: logCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11))
                            .foregroundColor(logCopied ? .green : .white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                    .help(logCopied ? "已复制" : "复制全部")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider().background(Color.white.opacity(0.1))

            // Diagnostic output
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        if viewModel.doctorOutput.isEmpty && !viewModel.doctorRunning {
                            Text("点击下方「运行诊断」检测系统状态")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.4))
                                .padding(.top, 40)
                                .frame(maxWidth: .infinity)
                        }

                        ForEach(Array(viewModel.doctorOutput.enumerated()), id: \.offset) { index, line in
                            doctorLine(line)
                                .id("diag-\(index)")
                        }

                        if viewModel.doctorFixDone && !viewModel.doctorFixOutput.isEmpty {
                            Divider()
                                .background(Color.accentColor.opacity(0.3))
                                .padding(.vertical, 8)

                            HStack(spacing: 6) {
                                Image(systemName: "wrench.and.screwdriver")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.accentColor)
                                Text("修复输出")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.accentColor)
                            }
                            .padding(.bottom, 4)

                            ForEach(Array(viewModel.doctorFixOutput.enumerated()), id: \.offset) { index, line in
                                doctorLine(line)
                                    .id("fix-\(index)")
                            }
                        }

                        if viewModel.doctorRunning || viewModel.doctorFixRunning {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 14, height: 14)
                                Text(viewModel.doctorFixRunning ? "正在修复..." : "正在诊断...")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .padding(.top, 6)
                            .id("spinner")
                        }

                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onChange(of: viewModel.doctorOutput.count) { _ in
                    withAnimation { proxy.scrollTo("bottom") }
                }
                .onChange(of: viewModel.doctorFixOutput.count) { _ in
                    withAnimation { proxy.scrollTo("bottom") }
                }
            }
            .background(Color.black.opacity(0.3))

            Divider().background(Color.white.opacity(0.1))

            // Status bar + actions
            HStack(spacing: 12) {
                // Status indicator
                if viewModel.doctorRunning || viewModel.doctorFixRunning {
                    statusBadge(
                        icon: "arrow.triangle.2.circlepath",
                        text: viewModel.doctorFixRunning ? "修复中" : "诊断中",
                        color: .orange
                    )
                } else if viewModel.doctorFixDone {
                    statusBadge(
                        icon: viewModel.doctorFixExitCode == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                        text: viewModel.doctorFixExitCode == 0 ? "修复完成" : "部分修复",
                        color: viewModel.doctorFixExitCode == 0 ? .green : .yellow
                    )
                } else if !viewModel.doctorOutput.isEmpty {
                    statusBadge(
                        icon: viewModel.doctorExitCode == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                        text: viewModel.doctorExitCode == 0 ? "状态正常" : "发现问题",
                        color: viewModel.doctorExitCode == 0 ? .green : .yellow
                    )
                }

                Spacer()

                Button(action: { viewModel.runDoctor() }) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                        Text("运行诊断")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.doctorRunning || viewModel.doctorFixRunning)

                Button(action: { viewModel.runDoctorFix() }) {
                    HStack(spacing: 5) {
                        Image(systemName: "wrench.and.screwdriver")
                            .font(.system(size: 11, weight: .semibold))
                        Text("自动修复")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.doctorRunning || viewModel.doctorFixRunning || viewModel.doctorOutput.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 680, height: 520)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.09, green: 0.09, blue: 0.15))
        )
        .onAppear {
            if viewModel.doctorOutput.isEmpty {
                viewModel.runDoctor()
            }
        }
    }

    private func doctorLine(_ line: String) -> some View {
        Text(stripAnsi(line))
            .font(.system(size: 11.5, design: .monospaced))
            .foregroundColor(lineColor(line))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statusBadge(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(color)
    }

    private func lineColor(_ line: String) -> Color {
        let lower = line.lowercased()
        if lower.contains("critical") || lower.contains("error") { return .red.opacity(0.9) }
        if lower.contains("warn") { return .yellow.opacity(0.85) }
        if lower.contains("✓") || lower.contains("pass") || lower.contains("ok") { return .green.opacity(0.8) }
        if line.hasPrefix("◇") || line.hasPrefix("┌") || line.hasPrefix("├") || line.hasPrefix("└") { return .accentColor.opacity(0.8) }
        if line.hasPrefix("│") { return .white.opacity(0.65) }
        return .white.opacity(0.55)
    }

    private func stripAnsi(_ text: String) -> String {
        text.replacingOccurrences(
            of: "\\x1B\\[[0-9;]*[A-Za-z]",
            with: "",
            options: .regularExpression
        )
    }
}
