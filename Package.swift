// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ModelServerStatusBoard",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "StatusBoardCore", targets: ["StatusBoardCore"]),
        .executable(name: "StatusBoardApp", targets: ["StatusBoardApp"]),
        .executable(name: "StatusBoardSelfTests", targets: ["StatusBoardSelfTests"])
    ],
    targets: [
        .target(
            name: "StatusBoardCore",
            linkerSettings: [
                .linkedFramework("Security")
            ]
        ),
        .executableTarget(
            name: "StatusBoardApp",
            dependencies: ["StatusBoardCore"],
            linkerSettings: [
                .linkedFramework("WebKit")
            ]
        ),
        .executableTarget(
            name: "StatusBoardSelfTests",
            dependencies: ["StatusBoardCore"]
        ),
        .testTarget(
            name: "StatusBoardAppTests",
            dependencies: ["StatusBoardCore"]
        )
    ]
)
