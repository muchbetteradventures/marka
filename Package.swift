// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "marka",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "marka",
            path: "Sources/Marka",
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate",
                              "-Xlinker", "__TEXT",
                              "-Xlinker", "__info_plist",
                              "-Xlinker", "Info.plist"])
            ]
        )
    ]
)
