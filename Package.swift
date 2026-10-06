// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AllSet",
    platforms: [.macOS("14.2")],
    products: [
        .executable(name: "AllSet", targets: ["AllSet"]),
        // Not linked into the app: /usr/bin/perl loads it at runtime to read
        // Now Playing info. See Sources/MediaHelper/MediaHelper.m.
        .library(name: "AllSetMediaHelper", type: .dynamic, targets: ["MediaHelper"]),
    ],
    targets: [
        .executableTarget(
            name: "AllSet",
            dependencies: ["AllSetCore"],
            path: "Sources/AllSet"
        ),
        .target(
            name: "AllSetCore",
            dependencies: ["CPrivateAPIs"],
            path: "Sources/AllSetCore",
            resources: [.copy("Resources/ThemeArt")],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("CoreWLAN"),
            ]
        ),
        .target(
            name: "CPrivateAPIs",
            path: "Sources/CPrivateAPIs",
            linkerSettings: [.linkedFramework("IOKit")]
        ),
        .target(
            name: "MediaHelper",
            path: "Sources/MediaHelper",
            linkerSettings: [.linkedFramework("Foundation")]
        ),
        .testTarget(
            name: "AllSetCoreTests",
            dependencies: ["AllSetCore"],
            path: "Tests/AllSetCoreTests"
        ),
    ]
)
