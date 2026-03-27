import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: InstallerViewModel
    @State private var showDonatePopover = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.07, blue: 0.12),
                    Color(red: 0.10, green: 0.10, blue: 0.18),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Step indicator
                StepIndicatorView(currentStep: viewModel.currentStep)
                    .padding(.horizontal, 32)
                    .padding(.top, 12)

                // Main content
                Group {
                    switch viewModel.currentStep {
                    case .welcome:
                        WelcomeView()
                    case .methodSelection:
                        MethodSelectionView()
                    case .dependencyCheck:
                        DependencyCheckView()
                    case .installing:
                        InstallProgressView()
                    case .configuring:
                        ConfigView()
                    case .completion:
                        CompletionView()
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Footer: version & repo link
                HStack {
                    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
                    Text("v\(version) (\(build))")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.35))

                    Spacer()

                    Button {
                        showDonatePopover.toggle()
                    } label: {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.35))
                    }
                    .buttonStyle(.plain)
                    .help("打赏一杯咖啡")
                    .onHover { hovering in
                        if hovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    .popover(isPresented: $showDonatePopover, arrowEdge: .top) {
                        VStack(spacing: 8) {
                            Text("打赏一杯咖啡")
                                .font(.system(size: 14, weight: .semibold))

                            HStack(spacing: 0) {
                                Image("AlipayQR")
                                    .resizable()
                                    .interpolation(.high)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 240, height: 240)

                                Image("WechatQR")
                                    .resizable()
                                    .interpolation(.high)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 240, height: 240)
                            }
                        }
                        .padding(0)
                    }

                    Link(destination: URL(string: "https://github.com/loverbabyz/OpenClawInstaller")!) {
                        GitHubIcon()
                            .fill(Color.white.opacity(0.35))
                            .frame(width: 16, height: 16)
                    }
                    .onHover { hovering in
                        if hovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 10)
                .padding(.top, 4)
            }
        }
        .navigationTitle("OpenClaw Installer")
        .task {
            await viewModel.detectSystem()
        }
    }

}

struct StepIndicatorView: View {
    let currentStep: InstallStep

    private let steps = ["欢迎", "方式", "依赖", "安装", "配置", "完成"]
    // step indices match InstallStep raw values

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<steps.count, id: \.self) { index in
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(index <= currentStep.rawValue ? Color.accentColor : Color.white.opacity(0.15))
                            .frame(width: 24, height: 24)

                        if index < currentStep.rawValue {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text("\(index + 1)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(index == currentStep.rawValue ? .white : .white.opacity(0.5))
                        }
                    }

                    if index < steps.count - 1 {
                        Rectangle()
                            .fill(index < currentStep.rawValue ? Color.accentColor : Color.white.opacity(0.15))
                            .frame(height: 2)
                    }
                }
            }
        }
    }
}

/// GitHub official Invertocat mark as a SwiftUI Shape.
struct GitHubIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height)
        let ox = rect.midX - s / 2
        let oy = rect.midY - s / 2
        // Scale from 16×16 viewBox
        func x(_ v: CGFloat) -> CGFloat { ox + v / 16 * s }
        func y(_ v: CGFloat) -> CGFloat { oy + v / 16 * s }

        var p = Path()
        // Outer circle body – simplified GitHub mark path (viewBox 0 0 16 16)
        p.move(to: CGPoint(x: x(8), y: y(0)))
        p.addCurve(to: CGPoint(x: x(0), y: y(8)),
                    control1: CGPoint(x: x(3.58), y: y(0)),
                    control2: CGPoint(x: x(0), y: y(3.58)))
        p.addCurve(to: CGPoint(x: x(5.46), y: y(15.88)),
                    control1: CGPoint(x: x(0), y: y(11.54)),
                    control2: CGPoint(x: x(2.29), y: y(14.73)))
        p.addCurve(to: CGPoint(x: x(6), y: y(14.65)),
                    control1: CGPoint(x: x(5.68), y: y(15.92)),
                    control2: CGPoint(x: x(6), y: y(15.31)))
        p.addLine(to: CGPoint(x: x(6), y: y(13.13)))
        p.addCurve(to: CGPoint(x: x(3.41), y: y(12.41)),
                    control1: CGPoint(x: x(4.22), y: y(13.55)),
                    control2: CGPoint(x: x(3.41), y: y(13.41)))
        p.addCurve(to: CGPoint(x: x(3.52), y: y(11.85)),
                    control1: CGPoint(x: x(3.41), y: y(12.2)),
                    control2: CGPoint(x: x(3.44), y: y(12.01)))
        p.addCurve(to: CGPoint(x: x(2.44), y: y(9.5)),
                    control1: CGPoint(x: x(2.92), y: y(11.63)),
                    control2: CGPoint(x: x(2.44), y: y(10.68)))
        p.addCurve(to: CGPoint(x: x(3.32), y: y(7.82)),
                    control1: CGPoint(x: x(2.44), y: y(8.84)),
                    control2: CGPoint(x: x(2.75), y: y(8.27)))
        p.addCurve(to: CGPoint(x: x(3.23), y: y(5.71)),
                    control1: CGPoint(x: x(2.93), y: y(7.14)),
                    control2: CGPoint(x: x(2.9), y: y(6.42)))
        p.addCurve(to: CGPoint(x: x(5.09), y: y(6.29)),
                    control1: CGPoint(x: x(4.09), y: y(5.71)),
                    control2: CGPoint(x: x(4.51), y: y(5.9)))
        p.addCurve(to: CGPoint(x: x(8), y: y(5.89)),
                    control1: CGPoint(x: x(5.68), y: y(6.03)),
                    control2: CGPoint(x: x(6.79), y: y(5.89)))
        p.addCurve(to: CGPoint(x: x(10.91), y: y(6.29)),
                    control1: CGPoint(x: x(9.21), y: y(5.89)),
                    control2: CGPoint(x: x(10.32), y: y(6.03)))
        p.addCurve(to: CGPoint(x: x(12.77), y: y(5.71)),
                    control1: CGPoint(x: x(11.49), y: y(5.9)),
                    control2: CGPoint(x: x(11.91), y: y(5.71)))
        p.addCurve(to: CGPoint(x: x(12.68), y: y(7.82)),
                    control1: CGPoint(x: x(13.1), y: y(6.42)),
                    control2: CGPoint(x: x(13.07), y: y(7.14)))
        p.addCurve(to: CGPoint(x: x(13.56), y: y(9.5)),
                    control1: CGPoint(x: x(13.25), y: y(8.27)),
                    control2: CGPoint(x: x(13.56), y: y(8.84)))
        p.addCurve(to: CGPoint(x: x(12.48), y: y(11.85)),
                    control1: CGPoint(x: x(13.56), y: y(10.68)),
                    control2: CGPoint(x: x(13.08), y: y(11.63)))
        p.addCurve(to: CGPoint(x: x(12.59), y: y(12.41)),
                    control1: CGPoint(x: x(12.56), y: y(12.01)),
                    control2: CGPoint(x: x(12.59), y: y(12.2)))
        p.addCurve(to: CGPoint(x: x(10), y: y(13.13)),
                    control1: CGPoint(x: x(12.59), y: y(13.41)),
                    control2: CGPoint(x: x(11.78), y: y(13.55)))
        p.addLine(to: CGPoint(x: x(10), y: y(14.65)))
        p.addCurve(to: CGPoint(x: x(10.54), y: y(15.88)),
                    control1: CGPoint(x: x(10), y: y(15.31)),
                    control2: CGPoint(x: x(10.32), y: y(15.92)))
        p.addCurve(to: CGPoint(x: x(16), y: y(8)),
                    control1: CGPoint(x: x(13.71), y: y(14.73)),
                    control2: CGPoint(x: x(16), y: y(11.54)))
        p.addCurve(to: CGPoint(x: x(8), y: y(0)),
                    control1: CGPoint(x: x(16), y: y(3.58)),
                    control2: CGPoint(x: x(12.42), y: y(0)))
        p.closeSubpath()
        return p
    }
}
