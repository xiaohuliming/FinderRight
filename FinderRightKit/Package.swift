// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "FinderRightKit",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "FinderRightKit",
            targets: ["FinderRightKit"]
        ),
    ],
    targets: [
        .target(
            name: "FinderRightKit",
            path: "Sources/FinderRightKit"
        ),
        .testTarget(name: "FinderRightKitTests", dependencies: ["FinderRightKit"]),
    ]
)
