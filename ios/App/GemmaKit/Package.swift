// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "GemmaKit",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "GemmaKit", targets: ["GemmaKit"]),
    ],
    dependencies: [
        // mlx-swift-lm is the successor to mlx-swift-examples for hosting
        // MLXLLM / MLXLMCommon. 3.31.3 is the first release with Gemma 4
        // (`gemma4`, `gemma4_text`) registered in LLMModelFactory.
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", exact: "3.31.3"),
        // swift-huggingface provides the HuggingFace.HubClient that
        // mlx-swift-lm's MLXHuggingFace macros expand into. It is not a
        // transitive dep of mlx-swift-lm — packages opting into the HF path
        // must add it directly.
        .package(url: "https://github.com/huggingface/swift-huggingface", exact: "0.9.0"),
        // swift-transformers' Tokenizers module is what the
        // #huggingFaceTokenizerLoader() macro expansion bridges to.
        .package(url: "https://github.com/huggingface/swift-transformers", exact: "1.3.2"),
        .package(url: "https://github.com/ggerganov/llama.cpp", revision: "b3442"),
    ],
    targets: [
        .target(
            name: "GemmaKit",
            dependencies: [
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXHuggingFace", package: "mlx-swift-lm"),
                .product(name: "HuggingFace", package: "swift-huggingface"),
                .product(name: "Tokenizers", package: "swift-transformers"),
                .product(name: "llama", package: "llama.cpp"),
            ],
            path: "Sources",
            swiftSettings: [
                // Tools-version 6.1 defaults to Swift 6 strict concurrency,
                // which would require a wholesale refactor of the agent/MCP
                // layer to satisfy Sendable across actor boundaries.
                // Keeping the language mode at 5 preserves existing semantics
                // while still letting the project consume 6.x packages.
                .swiftLanguageMode(.v5),
            ]
        ),
        .testTarget(
            name: "GemmaKitTests",
            dependencies: ["GemmaKit"],
            path: "Tests"
        ),
    ]
)
