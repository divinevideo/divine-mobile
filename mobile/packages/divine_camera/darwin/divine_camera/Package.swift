// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "divine_camera",
  platforms: [
    .iOS("16.0"),
    .macOS("13.0"),
  ],
  products: [
    .library(name: "divine-camera", targets: ["divine_camera"]),
  ],
  dependencies: [],
  targets: [
    .target(
      name: "divine_camera",
      dependencies: [],
      resources: [
        .process("Resources"),
      ]
    ),
  ]
)
