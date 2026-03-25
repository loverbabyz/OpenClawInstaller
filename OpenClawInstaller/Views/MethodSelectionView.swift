import SwiftUI

struct MethodSelectionView: View {
    @EnvironmentObject var viewModel: InstallerViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("选择安装方式")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("选择最适合你的安装方式")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5))

            VStack(spacing: 14) {
                ForEach(InstallMethod.allCases, id: \.self) { method in
                    MethodCard(
                        method: method,
                        isSelected: viewModel.selectedMethod == method,
                        onSelect: { viewModel.selectedMethod = method }
                    )
                }
            }
            .padding(.horizontal, 40)

            Spacer()

            // Navigation buttons
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
                    viewModel.nextStep()
                    Task { await viewModel.checkDependencies() }
                }) {
                    HStack(spacing: 6) {
                        Text("下一步")
                            .font(.system(size: 14, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(width: 120, height: 40)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 40)
        }
    }
}

struct MethodCard: View {
    let method: InstallMethod
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.white.opacity(0.05))
                        .frame(width: 44, height: 44)

                    Image(systemName: method.icon)
                        .font(.system(size: 18))
                        .foregroundColor(isSelected ? .accentColor : .white.opacity(0.5))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(method.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)

                    Text(method.description)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(2)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.accentColor : Color.white.opacity(0.2), lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(isSelected ? 0.08 : 0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.accentColor.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
