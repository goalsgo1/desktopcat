// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DesktopCat",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(name: "DesktopCat", path: "Sources/DesktopCat")
    ]
)
