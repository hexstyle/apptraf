// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "apptraf",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "AppTrafCore",
            path: "Sources/AppTrafCore"
        ),
        .executableTarget(
            name: "apptrafd",
            dependencies: ["AppTrafCore"],
            path: "Sources/apptrafd"
        ),
        .executableTarget(
            name: "apptraf",
            dependencies: ["AppTrafCore"],
            path: "Sources/apptraf"
        ),
    ]
)
