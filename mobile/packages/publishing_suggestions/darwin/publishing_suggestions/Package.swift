// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "publishing_suggestions",
  platforms: [
    .iOS("13.0"),
    .macOS("10.15"),
  ],
  products: [
    .library(name: "publishing-suggestions", targets: ["publishing_suggestions"]),
  ],
  dependencies: [],
  targets: [
    .target(
      name: "publishing_suggestions",
      dependencies: []
    ),
  ]
)
