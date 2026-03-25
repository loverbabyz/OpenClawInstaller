import SwiftUI

struct DoctorView: View {
    @EnvironmentObject var viewModel: InstallerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var logCopied = false
    @State private var showRawLog = false

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

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("关闭")
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider().background(Color.white.opacity(0.1))

            // Main content
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {

                        // Report card (shown after diagnosis completes)
                        if let report = viewModel.doctorReport, !viewModel.doctorRunning {
                            reportCardView(report)
                                .padding(.bottom, 12)
                                .id("report")
                        }

                        if viewModel.doctorOutput.isEmpty && !viewModel.doctorRunning && viewModel.doctorReport == nil {
                            Text("点击下方「运行诊断」检测系统状态")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.4))
                                .padding(.top, 40)
                                .frame(maxWidth: .infinity)
                        }

                        // Running spinner
                        if viewModel.doctorRunning || viewModel.doctorFixRunning {
                            ForEach(Array(viewModel.doctorOutput.enumerated()), id: \.offset) { index, line in
                                doctorLine(line)
                                    .id("diag-\(index)")
                            }

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

                        // Raw log (collapsible after report is shown)
                        if !viewModel.doctorRunning && !viewModel.doctorOutput.isEmpty {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) { showRawLog.toggle() }
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: showRawLog ? "chevron.down" : "chevron.right")
                                        .font(.system(size: 9, weight: .semibold))
                                    Text("原始日志")
                                        .font(.system(size: 12, weight: .medium))
                                    Text("(\(viewModel.doctorOutput.count) 行)")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.3))
                                }
                                .foregroundColor(.white.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)

                            if showRawLog {
                                ForEach(Array(viewModel.doctorOutput.enumerated()), id: \.offset) { index, line in
                                    doctorLine(line)
                                        .id("diag-\(index)")
                                }
                            }
                        }

                        // Fix output
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
                .onChange(of: viewModel.doctorReport != nil) { hasReport in
                    if hasReport {
                        withAnimation { proxy.scrollTo("report", anchor: .top) }
                    }
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

                if viewModel.doctorRunning || viewModel.doctorFixRunning {
                    Button(action: { viewModel.cancelDoctor() }) {
                        HStack(spacing: 5) {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 11, weight: .semibold))
                            Text("取消")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                } else {
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
                    .disabled(viewModel.doctorOutput.isEmpty)
                }
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

    // MARK: - Report Card

    private func reportCardView(_ report: DoctorReport) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Summary bar
            HStack(spacing: 14) {
                if !report.passed.isEmpty {
                    reportCountBadge(count: report.passed.count, label: "通过", color: .green, icon: "checkmark.circle.fill")
                }
                if !report.warnings.isEmpty {
                    reportCountBadge(count: report.warnings.count, label: "警告", color: .yellow, icon: "exclamationmark.triangle.fill")
                }
                if !report.errors.isEmpty {
                    reportCountBadge(count: report.errors.count, label: "错误", color: .red, icon: "xmark.circle.fill")
                }
                if !report.infos.isEmpty {
                    reportCountBadge(count: report.infos.count, label: "信息", color: .blue, icon: "info.circle.fill")
                }
                Spacer()
                if report.isHealthy && report.totalChecks > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11))
                        Text("系统状态良好")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.green)
                } else if !report.isHealthy {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                        Text("发现 \(report.warnings.count + report.errors.count) 个问题")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(report.errors.isEmpty ? .yellow : .red)
                }
            }

            Divider().background(Color.white.opacity(0.06))

            // Errors
            if !report.errors.isEmpty {
                reportSection(title: "错误", items: report.errors, color: .red)
            }

            // Warnings
            if !report.warnings.isEmpty {
                reportSection(title: "警告", items: report.warnings, color: .yellow)
            }

            // Info
            if !report.infos.isEmpty {
                reportSection(title: "信息", items: report.infos, color: .blue)
            }

            // Passed
            if !report.passed.isEmpty {
                reportSection(title: "通过", items: report.passed, color: .green)
            }

            // Fallback: show raw sections if nothing was classified
            if report.passed.isEmpty && report.warnings.isEmpty && report.errors.isEmpty && report.infos.isEmpty {
                ForEach(Array(report.sections.enumerated()), id: \.offset) { _, section in
                    if !section.title.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(section.title)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                            ForEach(Array(section.bodyLines.enumerated()), id: \.offset) { _, bodyLine in
                                Text(bodyLine)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.55))
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func reportCountBadge(count: Int, label: String, color: Color, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
            Text("\(count)")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(color.opacity(0.7))
        }
    }

    private func reportSection(title: String, items: [DoctorReportItem], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color)

            ForEach(items) { item in
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: item.icon)
                        .font(.system(size: 9))
                        .foregroundColor(color)
                        .frame(width: 12, alignment: .center)
                        .padding(.top, 3)
                    Text(item.text)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
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
