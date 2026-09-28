// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NotchX",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "NotchX",
            path: "Sources/NotchX",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("AVKit"),
                .linkedFramework("EventKit"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Security"),
            ]
        )
    ]
)
