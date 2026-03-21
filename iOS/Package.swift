// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LeapSDK",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LeapSDK",
            targets: ["LeapSDK", "LeapSDKSupport"]
        ),
        .library(
            name: "LeapModelDownloader",
            targets: ["LeapModelDownloader"]
        ),
        .library(
            name: "MLXSupport",
            targets: ["MLXSupport"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift", .upToNextMinor(from: "0.30.3")),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", .upToNextMinor(from: "2.30.3")),
    ],
    targets: [
        .binaryTarget(
            name: "LeapSDK",
            path: "./LeapSDK.xcframework"
        ),
        .binaryTarget(
            name: "LeapModelDownloader",
            path: "./LeapModelDownloader.xcframework"
        ),
        .binaryTarget(
            name: "InferenceEngine",
            path: "./inference_engine.xcframework"
        ),
        .binaryTarget(
            name: "InferenceEngineExecutorchBackend",
            path: "./inference_engine_executorch_backend.xcframework"
        ),
        .binaryTarget(
            name: "InferenceEngineLlamaCppBackend",
            path: "./inference_engine_llamacpp_backend.xcframework"
        ),
        .target(
            name: "LeapSDKSupport",
            dependencies: [
                "InferenceEngine",
                "InferenceEngineExecutorchBackend",
                "InferenceEngineLlamaCppBackend",
            ],
            path: "Sources/LeapSDKSupport"
        ),
        .target(
            name: "MLXSupport",
            dependencies: [
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXVLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
            ],
            path: "Sources/MLXSupport"
        ),
    ]
)
