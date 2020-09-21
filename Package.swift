// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "SwiftyBluetooth",
    platforms: [
        .iOS(.v10),
        .macOS(.v10_11),
        .tvOS(.v10)
    ],
    products: [
        .library(name: "SwiftyBluetooth", targets: ["SwiftyBluetooth"])
    ],
    targets: [
        .target(name: "SwiftyBluetooth", path: "Sources")
    ]
)
