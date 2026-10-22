// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "OpenNekoKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "OpenNekoKit", targets: ["OpenNekoKit"]),
        .executable(name: "SpritePipeline", targets: ["SpritePipeline"]),
    ],
    targets: [
        .target(name: "OpenNekoKit"),
        .executableTarget(name: "SpritePipeline", dependencies: ["OpenNekoKit"]),
        .testTarget(name: "OpenNekoKitTests", dependencies: ["OpenNekoKit"]),
    ]
)
