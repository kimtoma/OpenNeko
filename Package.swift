// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "OpenNekoKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "OpenNekoKit", targets: ["OpenNekoKit"]),
    ],
    targets: [
        .target(name: "OpenNekoKit"),
        .testTarget(name: "OpenNekoKitTests", dependencies: ["OpenNekoKit"]),
    ]
)
