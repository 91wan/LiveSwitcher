import SwiftUI

// MARK: - LowerThirdView（副屏叠层渲染）

struct LowerThirdView: View {
    let name: String
    let role: String
    let organization: String
    let isVisible: Bool
    let metrics: LowerThirdTypographyMetrics

    // 进出动画状态
    @State private var appeared: Bool = false

    // 弹簧进场：专业感十足；线性退场：干脆利落
    private let enterAnim: Animation = .spring(response: 0.45, dampingFraction: 0.78)
    private let exitAnim:  Animation = .easeIn(duration: 0.25)

    init(
        name: String,
        role: String,
        organization: String,
        isVisible: Bool,
        metrics: LowerThirdTypographyMetrics = .metrics(forCanvasHeight: 1080, canvasWidth: 1920)
    ) {
        self.name = name
        self.role = role
        self.organization = organization
        self.isVisible = isVisible
        self.metrics = metrics
    }

    var body: some View {
        nameCardContent
            .offset(y: appeared ? 0 : 72)
            .opacity(appeared ? 1.0 : 0.0)
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .onAppear {
            if isVisible {
                withAnimation(enterAnim) { appeared = true }
            }
        }
        .onChange(of: isVisible) { _, newVal in
            if newVal {
                withAnimation(enterAnim) { appeared = true }
            } else {
                withAnimation(exitAnim) { appeared = false }
            }
        }
    }

    // MARK: - 人名牌主体（演播室标准格式）

    private var nameCardContent: some View {
        HStack(alignment: .center, spacing: 0) {
            // Left accent rail.
            Rectangle()
                .fill(Color(red: 0.80, green: 0.00, blue: 0.00))
                .frame(width: metrics.accentWidth)

            // 文字区
            VStack(alignment: .leading, spacing: metrics.textSpacing) {
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text(name)
                        .font(.system(size: metrics.nameFontSize, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(metrics.minimumTextScaleFactor)

                    if !role.isEmpty {
                        Text(role)
                            .font(.system(size: metrics.roleFontSize, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                            .minimumScaleFactor(metrics.minimumTextScaleFactor)
                    }
                }
                .lineLimit(1)

                if !organization.isEmpty {
                    Text(organization)
                        .font(.system(size: metrics.organizationFontSize, weight: .regular))
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(1)
                        .minimumScaleFactor(metrics.minimumTextScaleFactor)
                }
            }
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.vertical, metrics.verticalPadding)
        }
        .background(
            RoundedRectangle(cornerRadius: 0)
                .fill(Color.black.opacity(0.65))
                .overlay(
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 0))
        .frame(maxWidth: metrics.maxWidth, alignment: .leading)
        .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 8)
    }
}
