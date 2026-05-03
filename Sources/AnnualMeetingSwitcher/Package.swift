// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LiveSwitcher",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "LiveSwitcher",
            path: "Sources/AnnualMeetingSwitcher"
        ),
        .testTarget(
            name: "LiveSwitcherTests",
            dependencies: ["LiveSwitcher"]
        )
    ]
)
