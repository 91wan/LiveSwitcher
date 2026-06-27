import SwiftUI

@MainActor
struct PanicChromeContainer: View {
    let isPanicMode: Bool
    let consoleMode: ConsoleMode
    let onTogglePanic: @MainActor () -> Void

    var body: some View {
        PanicChromeButton(
            model: PanicButtonModel.make(
                isActive: isPanicMode,
                consoleMode: consoleMode
            ),
            isActive: isPanicMode,
            action: onTogglePanic
        )
    }
}
