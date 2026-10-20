// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "InkDesk",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "InkDesk",
            path: "Sources/InkDesk",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
