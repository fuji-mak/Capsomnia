// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Capsomnia",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Capsomnia", targets: ["Capsomnia"]),
        .executable(name: "capsomnia-pmset", targets: ["CapsomniaPmsetHelper"])
    ],
    targets: [
        .executableTarget(
            name: "Capsomnia"
        ),
        .executableTarget(
            name: "CapsomniaPmsetHelper"
        ),
        .testTarget(
            name: "CapsomniaTests",
            dependencies: ["Capsomnia"]
        )
    ],
    swiftLanguageModes: [.v5]
)
