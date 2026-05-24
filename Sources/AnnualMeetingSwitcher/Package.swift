// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LiveSwitcher",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "LiveSwitcher",
            path: "Sources/AnnualMeetingSwitcher",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "LiveSwitcherTests",
            dependencies: ["LiveSwitcher"]
        )
    ]
)
