// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "NLtypedesk",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "NLtypedesk",
            path: "Sources/NLtypedesk",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
