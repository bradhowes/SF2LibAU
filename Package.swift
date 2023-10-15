// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "SF2LibAU",
  platforms: [.iOS(.v13), .macOS(.v10_15), .tvOS(.v12)],
  products: [.library(name: "SF2LibAU", targets: ["SF2LibAU"])],
  dependencies: [
    // .package(url: "https://github.com/bradhowes/SF2Lib", branch: "main")
    .package(path: "../SF2Lib"),
    .package(url: "https://github.com/bradhowes/AUv3Support", branch: "main")
  ],
  targets: [
    .target(name: "SF2LibAU", 
            dependencies: [.product(name: "SF2Lib", package: "SF2Lib")],
            swiftSettings: [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "SF2LibAUTests",
                dependencies: ["SF2LibAU",
                               .product(name: "AUv3-Support", package: "AUv3Support")],
                resources: [
                  .process("Resources"),
                ],
               swiftSettings: [.interoperabilityMode(.Cxx)])
  ],
  cxxLanguageStandard: .cxx20
)
