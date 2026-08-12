// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Capsomnia",
    platforms: [
        .macOS("13.5")
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
    swiftLanguageVersions: [.v5]
)
