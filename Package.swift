// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "VoiceTag",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "VoiceTag", targets: ["VoiceTag"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "VoiceTag",
            dependencies: [],
            path: "Sources/VoiceTag",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .unsafeFlags(["-O"])
            ]
        ),
        .testTarget(
            name: "VoiceTagTests",
            dependencies: ["VoiceTag"],
            path: "Tests"
        )
    ]
)
