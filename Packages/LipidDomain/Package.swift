// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LipidDomain",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "LipidDomain", targets: ["LipidDomain"])],
    targets: [
        .target(name: "LipidDomain"),
        .testTarget(name: "LipidDomainTests", dependencies: ["LipidDomain"], resources: [.copy("Fixtures")]),
    ]
)
