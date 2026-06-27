import SwiftUI

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
