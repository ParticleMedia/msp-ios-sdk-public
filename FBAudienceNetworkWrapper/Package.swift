// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FBAudienceNetworkWrapper",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "FBAudienceNetworkWrapper",
            targets: ["FBAudienceNetworkWrapper"]
        )
    ],
    targets: [
        .binaryTarget(
            name: "FBAudienceNetwork",
            path: "Frameworks/FBAudienceNetwork.xcframework"
        ),
        .target(
            name: "FBAudienceNetworkWrapper",
            dependencies: ["FBAudienceNetwork"],
            path: "Sources/FBAudienceNetworkWrapper"
        )
    ]
)

