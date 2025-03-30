// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "QSkipper",
    platforms: [
        .iOS(.v15),
        .macOS(.v11)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "QSkipper",
            targets: ["QSkipper"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/airbnb/lottie-ios.git", from: "4.3.3"),
        // Removed Alamofire dependency since we're using URLSession
        // .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.1"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "QSkipper",
            dependencies: [
                .product(name: "Lottie", package: "lottie-ios"),
                // Removed Alamofire dependency
                // .product(name: "Alamofire", package: "Alamofire")
            ]),
        .testTarget(
            name: "QSkipperTests",
            dependencies: ["QSkipper"]),
    ]
)
