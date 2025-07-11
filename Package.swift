// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "SF2LibAU",
  platforms: [.iOS(.v16), .macOS(.v14), .tvOS(.v16)],
  products: [.library(name: "SF2LibAU", targets: ["SF2LibAU"])],
  dependencies: [
    .package(url: "https://github.com/bradhowes/SF2Lib", from: "6.5.0"),
    // .package(path: "../SF2Lib"),
  ],
  targets: [
    .target(name: "SF2LibAU", 
            dependencies: [.product(name: "Engine", package: "SF2Lib")],
            swiftSettings: [.interoperabilityMode(.Cxx)]),
    .testTarget(name: "SF2LibAUTests",
                dependencies: ["SF2LibAU"],
                resources: [.process("Resources")],
                swiftSettings: [.interoperabilityMode(.Cxx)])
  ],
  cxxLanguageStandard: .cxx2b
)
