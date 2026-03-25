import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: InstallerViewModel

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
