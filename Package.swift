// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Capsomnia",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Capsomnia"
        )
    ],
    swiftLanguageModes: [.v5]
)
