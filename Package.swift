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
    dependencies: [
        .package(path: "Vendor/CapsomniaControl"),
        .package(path: "Vendor/MacStateCore")
    ],
    targets: [
        .executableTarget(
            name: "Capsomnia",
            dependencies: [
                .product(name: "CapsomniaControl", package: "CapsomniaControl"),
                .product(name: "MacStateCore", package: "MacStateCore")
            ]
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
