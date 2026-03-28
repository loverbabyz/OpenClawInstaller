import SwiftUI

struct DependencyCheckView: View {
    @EnvironmentObject var viewModel: InstallerViewModel

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("依赖检查")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("检查并安装所需的系统依赖")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5))

            // Dependency list
            VStack(spacing: 10) {
                ForEach(Array(viewModel.dependencies.enumerated()), id: \.element.id) { index, dep in
                    DependencyRow(dependency: dep) {
                        Task { await viewModel.installDependency(at: index) }
                    }
                }
            }
            .padding(.horizontal, 40)

            // NPM Mirror selector
            if viewModel.selectedMethod == .npm {
                NpmMirrorPicker(selectedMirror: $viewModel.selectedNpmMirror)
                    .padding(.horizontal, 40)
            }

            if !viewModel.allDepsReady && !viewModel.isCheckingDeps {
                Button(action: {
                    Task { await viewModel.installAllMissing() }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 13))
                        Text("安装全部缺失依赖")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }

            if viewModel.allDepsReady {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    Text("所有依赖已就绪")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.green)
                }
                .padding(.top, 4)
            }

            Spacer()

            HStack(spacing: 16) {
                Button(action: { viewModel.previousStep() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 12, weight: .semibold))
                        Text("上一步")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 120, height: 40)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button(action: {
                    Task { await viewModel.checkDependencies() }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 12, weight: .semibold))
                        Text("重新检查")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 120, height: 40)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button(action: {
                    viewModel.nextStep()
                    viewModel.startInstallation()
                }) {
                    HStack(spacing: 6) {
                        Text("开始安装")
                            .font(.system(size: 14, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(width: 120, height: 40)
                    .background(viewModel.allDepsReady ? Color.accentColor : Color.gray.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.allDepsReady)
            }
            .padding(.bottom, 40)
        }
    }
}

struct DependencyRow: View {
    let dependency: DependencyStatus
    let onInstall: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: dependency.icon)
                .font(.system(size: 16))
                .foregroundColor(dependency.statusColor)
                .frame(width: 24)
                .rotationEffect(dependency.isChecking || dependency.isInstalling ? .degrees(360) : .degrees(0))
                .animation(
                    (dependency.isChecking || dependency.isInstalling)
                        ? .linear(duration: 1).repeatForever(autoreverses: false)
                        : .default,
                    value: dependency.isChecking || dependency.isInstalling
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(dependency.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)

                if let version = dependency.version {
                    Text(version)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(1)
                }
            }

            Spacer()

            if dependency.isChecking {
                Text("检查中...")
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
            } else if dependency.isInstalling {
                ProgressView()
                    .scaleEffect(0.7)
                    .progressViewStyle(.circular)
                Text("安装中...")
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
            } else if !dependency.isInstalled {
                Button(action: onInstall) {
                    Text("安装")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.green)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

struct NpmMirrorPicker: View {
    @Binding var selectedMirror: NpmMirror

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "globe.asia.australia")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                Text("NPM 镜像源")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            .fixedSize()

            Menu {
                ForEach(NpmMirror.all) { mirror in
                    Button(action: { selectedMirror = mirror }) {
                        HStack {
                            Text(mirror.name)
                            if selectedMirror == mirror {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(selectedMirror.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                    Spacer()
                    Text(selectedMirror.url)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.35))
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
            }
            .menuStyle(.borderlessButton)
        }
    }
}
