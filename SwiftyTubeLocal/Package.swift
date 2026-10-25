// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftyTube",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "SwiftyTube", type: .static, targets: ["SwiftyTube"])
    ],
    targets: [
        .target(
            name: "SwiftyTube",
            path: "SwiftyTube",
            resources: [.copy("po_token.html"), .copy("player_configs.json")]
        ),
        .testTarget(name: "SwiftyTubeTests", dependencies: ["SwiftyTube"])
    ]
)
