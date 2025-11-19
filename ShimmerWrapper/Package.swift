// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ShimmerWrapper",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "ShimmerWrapper",
            targets: ["ShimmerWrapper"]
        )
    ],
    targets: [
        .binaryTarget(
            name: "Shimmer",
            path: "Frameworks/Shimmer.xcframework"
        ),
        .target(
            name: "ShimmerWrapper",
            dependencies: ["Shimmer"],
            path: "Sources/ShimmerWrapper",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
            ]
        )
    ]
)
