import SwiftUI

// MARK: - V27: 人名条下三分之一条（商业演播室级别）
// 文件原名 LowerThirdOverlay.swift，V27 激活为真正的 Lower Third 渲染视图
// 外科手术纪律：本文件仅负责 Lower Third 渲染逻辑，不触碰音视频底座

// MARK: - LowerThirdView（副屏叠层渲染）

struct LowerThirdView: View {
    let name: String
    let title: String
    let isVisible: Bool
    let metrics: LowerThirdTypographyMetrics

    // 进出动画状态
    @State private var appeared: Bool = false

    // 弹簧进场：专业感十足；线性退场：干脆利落
    private let enterAnim: Animation = .spring(response: 0.45, dampingFraction: 0.78)
    private let exitAnim:  Animation = .easeIn(duration: 0.25)

    init(
        name: String,
        title: String,
        isVisible: Bool,
        metrics: LowerThirdTypographyMetrics = .metrics(forCanvasHeight: 1080, canvasWidth: 1920)
    ) {
        self.name = name
        self.title = title
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
                Text(name)
                    .font(.system(size: metrics.nameFontSize, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(metrics.minimumTextScaleFactor)

                if !title.isEmpty {
                    Text(title)
                        .font(.system(size: metrics.titleFontSize, weight: .regular))
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

// MARK: - TickerEngine（类，持有 Timer 避免 SwiftUI 重建时泄漏）

struct TickerTrackGeometry: Equatable {
    static let internalTextPadding: CGFloat = 8
    static let trackGap: CGFloat = 40
    static let hiddenOffset: CGFloat = 10_000

    let containerWidth: CGFloat
    let textWidth: CGFloat

    init(containerWidth: CGFloat, measuredTextWidth: CGFloat) {
        self.containerWidth = max(0, containerWidth)
        self.textWidth = max(1, measuredTextWidth)
    }

    var initialOffsetA: CGFloat {
        containerWidth + Self.internalTextPadding
    }

    var initialOffsetB: CGFloat {
        initialOffsetA + textWidth + Self.trackGap
    }

    var resetThreshold: CGFloat {
        -textWidth
    }

    func nextOffset(after otherOffset: CGFloat) -> CGFloat {
        max(initialOffsetA, otherOffset + textWidth + Self.trackGap)
    }
}

@MainActor
final class TickerEngine: ObservableObject {
    @Published var offsetA: CGFloat = TickerTrackGeometry.hiddenOffset
    @Published var offsetB: CGFloat = TickerTrackGeometry.hiddenOffset
    @Published private(set) var isReadyForDisplay = false

    private var scrollTimer: Timer?
    private var currentGeometry: TickerTrackGeometry?
    var textWidth: CGFloat = 0
    var containerWidth: CGFloat = 0

    var activeTimerCountForTesting: Int {
        scrollTimer == nil ? 0 : 1
    }

    func configure(
        containerWidth: CGFloat,
        measuredTextWidth: CGFloat,
        speed: Double,
        resetPosition: Bool
    ) {
        guard containerWidth > 0, measuredTextWidth > 0 else {
            stop()
            self.containerWidth = max(0, containerWidth)
            self.textWidth = max(0, measuredTextWidth)
            currentGeometry = nil
            offsetA = TickerTrackGeometry.hiddenOffset
            offsetB = TickerTrackGeometry.hiddenOffset
            isReadyForDisplay = false
            return
        }

        let geometry = TickerTrackGeometry(containerWidth: containerWidth, measuredTextWidth: measuredTextWidth)
        let shouldReset = resetPosition || currentGeometry != geometry
        self.containerWidth = geometry.containerWidth
        self.textWidth = geometry.textWidth
        currentGeometry = geometry
        if shouldReset {
            offsetA = geometry.initialOffsetA
            offsetB = geometry.initialOffsetB
        }
        isReadyForDisplay = true

        stop()
        start(speed: speed, geometry: geometry)
    }

    func start(speed: Double) {
        guard let geometry = currentGeometry else { return }
        stop()
        start(speed: speed, geometry: geometry)
    }

    private func start(speed: Double, geometry: TickerTrackGeometry) {
        stop()
        let spd = max(speed, 20.0)
        let delta = CGFloat(spd / 60.0)
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.offsetA -= delta
                self.offsetB -= delta
                if self.offsetA < geometry.resetThreshold {
                    self.offsetA = geometry.nextOffset(after: self.offsetB)
                }
                if self.offsetB < geometry.resetThreshold {
                    self.offsetB = geometry.nextOffset(after: self.offsetA)
                }
            }
        }
        if let t = scrollTimer {
            RunLoop.main.add(t, forMode: .common)
        }
    }

    func stop() {
        scrollTimer?.invalidate()
        scrollTimer = nil
    }

    deinit {
        scrollTimer?.invalidate()
    }
}

// MARK: - TickerOverlay（V28 修复版：StateObject 驱动，避免 Timer 泄漏与重叠）

@MainActor
struct TickerOverlay: View {
    @Environment(SwitcherViewModel.self) var viewModel
    @StateObject private var engine = TickerEngine()
    @State private var measuredTextWidth: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let cardWidth = max(0, geo.size.width)
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.black.opacity(OutputOverlayLayoutMetrics.tickerBackgroundOpacity))
                    .overlay(
                        Rectangle()
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )

                ZStack(alignment: .leading) {
                    // A 轨道
                    tickerTextView
                        .fixedSize()
                        .offset(x: engine.offsetA)
                        .background(
                            GeometryReader { tg in
                                Color.clear
                                    .onAppear {
                                        measuredTextWidth = tg.size.width
                                        engine.configure(
                                            containerWidth: cardWidth,
                                            measuredTextWidth: tg.size.width,
                                            speed: viewModel.tickerSpeed,
                                            resetPosition: true
                                        )
                                    }
                                    .onChange(of: tg.size.width) { _, width in
                                        measuredTextWidth = width
                                        engine.configure(
                                            containerWidth: cardWidth,
                                            measuredTextWidth: width,
                                            speed: viewModel.tickerSpeed,
                                            resetPosition: true
                                        )
                                    }
                            }
                        )

                    // B 轨道
                    tickerTextView
                        .fixedSize()
                        .offset(x: engine.offsetB)
                }
                .frame(width: cardWidth, height: OutputOverlayLayoutMetrics.tickerHeight, alignment: .leading)
                .clipped()
                .opacity(engine.isReadyForDisplay ? 1 : 0)
                .transaction { transaction in
                    transaction.animation = nil
                    transaction.disablesAnimations = true
                }
                .onAppear {
                    engine.configure(
                        containerWidth: cardWidth,
                        measuredTextWidth: measuredTextWidth > 0 ? measuredTextWidth : estimatedTickerTextWidth,
                        speed: viewModel.tickerSpeed,
                        resetPosition: true
                    )
                }
            }
            .frame(width: cardWidth, height: OutputOverlayLayoutMetrics.tickerHeight, alignment: .leading)
        }
        .transition(.opacity)
        .onChange(of: viewModel.tickerText) { _, _ in
            engine.configure(
                containerWidth: engine.containerWidth,
                measuredTextWidth: estimatedTickerTextWidth,
                speed: viewModel.tickerSpeed,
                resetPosition: true
            )
        }
        .onChange(of: viewModel.tickerSpeed) { _, _ in
            engine.configure(
                containerWidth: engine.containerWidth,
                measuredTextWidth: engine.textWidth,
                speed: viewModel.tickerSpeed,
                resetPosition: false
            )
        }
        .onDisappear {
            engine.stop()
        }
    }

    private var tickerTextView: some View {
        Text(viewModel.tickerText + "    ◆    ")
            .font(.system(size: 36, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 8)
    }

    private var estimatedTickerTextWidth: CGFloat {
        max(CGFloat(viewModel.tickerText.count) * 28 + 120, 240)
    }
}
