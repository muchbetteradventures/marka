// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MarkdownQuickLook",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "MarkdownRenderer",
            targets: ["MarkdownRenderer"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-markdown.git", from: "0.4.0")
    ],
    targets: [
        .target(
            name: "MarkdownRenderer",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown")
            ]
        )
    ]
)
