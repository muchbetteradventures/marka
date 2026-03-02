// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "markie",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "markie",
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
