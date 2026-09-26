// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "divine_video_player",
  platforms: [
    .iOS("16.0"),
    .macOS("13.0"),
  ],
  products: [
    .library(name: "divine-video-player", targets: ["divine_video_player"]),
  ],
  dependencies: [],
  targets: [
    .target(
      name: "divine_video_player",
      dependencies: [],
      resources: [
        .process("Resources"),
      ]
    ),
  ]
)
