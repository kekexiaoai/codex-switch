// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "CodexSwitch",
    platforms: [
        .macOS(.v12),
    ],
    products: [
        .library(name: "CodexSwitchKit", targets: ["CodexSwitchKit"]),
        .executable(name: "CodexSwitch", targets: ["CodexSwitchApp"]),
    ],
    targets: [
        .target(
            name: "CodexSwitchKit",
            path: "CodexSwitch"
        ),
        .executableTarget(
            name: "CodexSwitchApp",
            dependencies: ["CodexSwitchKit"],
            path: "CodexSwitchApp"
        ),
        .testTarget(
            name: "CodexSwitchTests",
            dependencies: ["CodexSwitchKit"],
            path: "CodexSwitchTests"
        ),
    ]
)
