// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Raster",
    platforms: [.macOS("26.0")],
    targets: [
        .executableTarget(
            name: "Raster",
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
