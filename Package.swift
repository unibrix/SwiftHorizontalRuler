// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SwiftHorizontalRuler",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "SwiftHorizontalRuler",
            targets: ["SwiftHorizontalRuler"]
        ),
    ],
    targets: [
        .target(
            name: "SwiftHorizontalRuler"
        ),
    ]
)
