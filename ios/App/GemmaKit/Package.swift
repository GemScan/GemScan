// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GemmaKit",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "GemmaKit", targets: ["GemmaKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift-examples", exact: "1.18.2"),
        .package(url: "https://github.com/ggerganov/llama.cpp", revision: "b3442"),
    ],
    targets: [
        .target(
            name: "GemmaKit",
            dependencies: [
                .product(name: "MLXLLM", package: "mlx-swift-examples"),
                .product(name: "llama", package: "llama.cpp"),
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "GemmaKitTests",
            dependencies: ["GemmaKit"],
            path: "Tests"
        ),
    ]
)
