// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GemmaKit",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "GemmaKit", targets: ["GemmaKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift-examples", exact: "1.18.0"),
        .package(url: "https://github.com/ggerganov/llama.cpp", exact: "b3442"),
        .package(url: "https://github.com/asg017/sqlite-vec-swift", exact: "0.1.1"),
    ],
    targets: [
        .target(
            name: "GemmaKit",
            dependencies: [
                .product(name: "MLXLLM", package: "mlx-swift-examples"),
                .product(name: "llama", package: "llama.cpp"),
                .product(name: "SQLiteVec", package: "sqlite-vec-swift"),
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
