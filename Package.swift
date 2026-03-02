// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "markie",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(url: "https://github.com/LiYanan2004/MarkdownView", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "markie",
            dependencies: [
                .product(name: "MarkdownView", package: "MarkdownView")
            ],
            path: "Sources/Markie",
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate",
                              "-Xlinker", "__TEXT",
                              "-Xlinker", "__info_plist",
                              "-Xlinker", "Info.plist"])
            ]
        )
    ]
)
