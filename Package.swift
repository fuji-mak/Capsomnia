// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Capsomnia",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Capsomnia", targets: ["Capsomnia"]),
        .executable(name: "capsomnia-pmset", targets: ["CapsomniaPmsetHelper"]),
        .executable(name: "capsomnia-ai-hook", targets: ["CapsomniaAIHook"])
    ],
    targets: [
        .target(
            name: "CapsomniaIntegrationKit"
        ),
        .executableTarget(
            name: "Capsomnia",
            dependencies: ["CapsomniaIntegrationKit"]
        ),
        .executableTarget(
            name: "CapsomniaPmsetHelper"
        ),
        .executableTarget(
            name: "CapsomniaAIHook",
            dependencies: ["CapsomniaIntegrationKit"]
        ),
        .testTarget(
            name: "CapsomniaTests",
            dependencies: ["Capsomnia", "CapsomniaIntegrationKit"]
        )
    ],
    swiftLanguageModes: [.v5]
)
