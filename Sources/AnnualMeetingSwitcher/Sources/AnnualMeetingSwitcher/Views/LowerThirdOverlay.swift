import SwiftUI

// MARK: - V27: 人名条下三分之一条（商业演播室级别）
// 文件原名 LowerThirdOverlay.swift，V27 激活为真正的 Lower Third 渲染视图
// 外科手术纪律：本文件仅负责 Lower Third 渲染逻辑，不触碰音视频底座

// MARK: - LowerThirdView（副屏叠层渲染）

struct LowerThirdView: View {
    let name: String
    let title: String
    let isVisible: Bool

    // 进出动画状态
    @State private var appeared: Bool = false

    // 弹簧进场：专业感十足；线性退场：干脆利落
    private let enterAnim: Animation = .spring(response: 0.45, dampingFraction: 0.78)
    private let exitAnim:  Animation = .easeIn(duration: 0.25)

    var body: some View {
        VStack {
            Spacer()

            // 人名条主体
            nameCardContent
                .padding(.horizontal, 60)   // 16:9 横向留边
                .padding(.bottom, 56)       // 底部安全边距（避免遮挡字幕条）
                .offset(y: appeared ? 0 : 72)
                .opacity(appeared ? 1.0 : 0.0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
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
                .frame(width: 5)

            // 文字区
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                if !title.isEmpty {
                    Text(title)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.white.opacity(0.88))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.80))
        }
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .frame(maxWidth: 560, alignment: .leading)
        // 外边框微妙高光
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.45), radius: 8, x: 0, y: 4)
    }
}

// MARK: - TickerEngine（类，持有 Timer 避免 SwiftUI 重建时泄漏）

@MainActor
final class TickerEngine: ObservableObject {
    @Published var offsetA: CGFloat = 0
    @Published var offsetB: CGFloat = 0

    private var scrollTimer: Timer?
    var textWidth: CGFloat = 800
    var containerWidth: CGFloat = 1920
    private var started: Bool = false

    func setup(containerWidth W: CGFloat, textWidth tw: CGFloat, speed: Double) {
        self.containerWidth = W
        self.textWidth = max(tw, 200)
        stop()
        // A 从右侧屏幕外，B 紧随 A 之后
        offsetA = W
        offsetB = W + self.textWidth + 40
        start(speed: speed)
    }

    func start(speed: Double) {
        stop()
        let spd = max(speed, 20.0)
        let delta = CGFloat(spd / 60.0)
        let tw = textWidth
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.offsetA -= delta
                self.offsetB -= delta
                if self.offsetA < -(tw + 40) {
                    self.offsetA = self.offsetB + tw + 40
                }
                if self.offsetB < -(tw + 40) {
                    self.offsetB = self.offsetA + tw + 40
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

struct TickerOverlay: View {
    @EnvironmentObject var viewModel: SwitcherViewModel
    @StateObject private var engine = TickerEngine()

    var body: some View {
        VStack {
            GeometryReader { geo in
                let W = geo.size.width
                ZStack(alignment: .leading) {
                    Color.black.opacity(0.80)

                    // A 轨道
                    tickerTextView
                        .fixedSize()
                        .offset(x: engine.offsetA)
                        .background(
                            GeometryReader { tg in
                                Color.clear.onAppear {
                                    // 用真实测量宽度初始化（仅首次）
                                    if engine.textWidth == 800 {
                                        engine.setup(
                                            containerWidth: W,
                                            textWidth: tg.size.width,
                                            speed: viewModel.tickerSpeed
                                        )
                                    }
                                }
                            }
                        )

                    // B 轨道
                    tickerTextView
                        .fixedSize()
                        .offset(x: engine.offsetB)
                }
                .clipped()
                .frame(width: W, height: 56, alignment: .leading)  // 高度从40→56
                .onAppear {
                    // 估算宽度兜底（若 background GeometryReader 未触发）
                    if engine.textWidth == 800 {
                        let estimated = CGFloat(viewModel.tickerText.count) * 28 + 120  // 估算字宽随字体增大
                        engine.setup(
                            containerWidth: W,
                            textWidth: max(estimated, 400),
                            speed: viewModel.tickerSpeed
                        )
                    }
                }
            }
            .frame(height: 56)  // 高度从40→56
            Spacer()  // 把字幕条推到顶部
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // 新增：确保 VStack 铺满全屏，使字幕条真正吸附顶部
        .transition(.opacity)
        .onChange(of: viewModel.tickerText) { _, _ in
            let estimated = CGFloat(viewModel.tickerText.count) * 28 + 120  // 字体36pt，估算字宽更新
            engine.textWidth = 800  // 重置，触发下次 GeometryReader 重新测量
            engine.setup(
                containerWidth: engine.containerWidth,
                textWidth: max(estimated, 400),
                speed: viewModel.tickerSpeed
            )
        }
        .onChange(of: viewModel.tickerSpeed) { _, _ in
            engine.stop()
            engine.start(speed: viewModel.tickerSpeed)
        }
        .onDisappear {
            engine.stop()
        }
    }

    private var tickerTextView: some View {
        Text(viewModel.tickerText + "    ◆    ")
            .font(.system(size: 36, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .lineLimit(1)
            .padding(.horizontal, 8)
    }
}
