// swift-tools-version: 5.9
import PackageDescription

// The root package mirrors the app package so `swift build` and `swift test`
// work from the repository root.

let package = Package(
    name: "LiveSwitcher",
    defaultLocalization: "en",
    platforms: [
        .macOS("14.0")
    ],
    targets: [
        .executableTarget(
            name: "LiveSwitcher",
            path: "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "LiveSwitcherTests",
            dependencies: ["LiveSwitcher"],
            path: "Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests"
        )
    ]
)
