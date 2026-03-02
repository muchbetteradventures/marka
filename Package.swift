// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "markie",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(url: "https://github.com/gonzalezreal/textual", from: "0.1.0")
    ],
    targets: [
        .executableTarget(
            name: "markie",
            dependencies: [
                .product(name: "Textual", package: "textual")
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
