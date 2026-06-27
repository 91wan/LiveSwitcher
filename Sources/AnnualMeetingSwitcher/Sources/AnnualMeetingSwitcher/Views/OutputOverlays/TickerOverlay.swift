import SwiftUI

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
