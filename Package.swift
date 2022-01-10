// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "SwiftyBluetooth",
    platforms: [
        .iOS(.v10),
        .macOS(.v10_13),
        .tvOS(.v10)
    ],
    products: [
        .library(name: "SwiftyBluetooth", targets: ["SwiftyBluetooth"])
    ],
    targets: [
        .target(name: "SwiftyBluetooth", path: "Sources", exclude: ["Info.plist"])
    ]
)
