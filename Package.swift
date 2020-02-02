// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "Vicrab",
    platforms: [
        .macOS(.v10_10),
        .iOS(.v8),
        .tvOS(.v9),
        .watchOS(.v2),
    ],
    products: [
        .library(
            name: "Vicrab",
            targets: ["Vicrab"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Vicrab",
            dependencies: [
                "VicrabCrash/Installations",
                "VicrabCrash/Recording",
                "VicrabCrash/Recording/Monitors",
                "VicrabCrash/Recording/Tools",
                "VicrabCrash/Reporting/Filters",
                "VicrabCrash/Reporting/Filters/Tools",
                "VicrabCrash/Reporting/Tools",
            ],
            path: "Sources/Vicrab",
            cxxSettings: [
                .headerSearchPath("../VicrabCrash/Installations"),
                .headerSearchPath("../VicrabCrash/Recording"),
                .headerSearchPath("../VicrabCrash/Recording/Monitors"),
                .headerSearchPath("../VicrabCrash/Recording/Tools"),
                .headerSearchPath("../VicrabCrash/Reporting/Filters"),
            ],
            linkerSettings: [
                .linkedLibrary("z"),
                .linkedLibrary("c++"),
            ]
        ),

        .target(
            name: "VicrabCrash/Installations",
            path: "Sources/VicrabCrash/Installations",
            publicHeadersPath: ".",
            cxxSettings: [
                .headerSearchPath("../Recording"),
                .headerSearchPath("../Recording/Monitors"),
                .headerSearchPath("../Recording/Tools"),
                .headerSearchPath("../Reporting/Filters"),
                .headerSearchPath("../Reporting/Tools"),
            ]
        ),

        .target(
            name: "VicrabCrash/Recording",
            path: "Sources/VicrabCrash/Recording",
            exclude: [
                "Monitors",
                "Tools",
            ],
            publicHeadersPath: ".",
            cxxSettings: [
                .headerSearchPath("Tools"),
                .headerSearchPath("Monitors"),
                .headerSearchPath("../Reporting/Filters"),
            ]
        ),

        .target(
            name: "VicrabCrash/Recording/Monitors",
            path: "Sources/VicrabCrash/Recording/Monitors",
            publicHeadersPath: ".",
            cxxSettings: [
                .define("GCC_ENABLE_CPP_EXCEPTIONS", to: "YES"),
                .headerSearchPath(".."),
                .headerSearchPath("../Tools"),
                .headerSearchPath("../../Reporting/Filters"),
            ]
        ),

        .target(
            name: "VicrabCrash/Recording/Tools",
            path: "Sources/VicrabCrash/Recording/Tools",
            publicHeadersPath: ".",
            cxxSettings: [
                .headerSearchPath(".."),
            ]
        ),

        .target(
            name: "VicrabCrash/Reporting/Filters",
            path: "Sources/VicrabCrash/Reporting/Filters",
            exclude: [
                "Tools",
            ],
            publicHeadersPath: ".",
            cxxSettings: [
                .headerSearchPath("Tools"),
                .headerSearchPath("../../Recording/Tools"),
            ]
        ),

        .target(
            name: "VicrabCrash/Reporting/Filters/Tools",
            path: "Sources/VicrabCrash/Reporting/Filters/Tools",
            publicHeadersPath: "."
        ),

        .target(
            name: "VicrabCrash/Reporting/Tools",
            path: "Sources/VicrabCrash/Reporting/Tools",
            publicHeadersPath: "."
        ),

        .testTarget(
            name: "VicrabSwiftTests",
            dependencies: [
                "Vicrab",
            ],
            path: "Tests/VicrabTests",
            sources: [
                "VicrabSwiftTests.swift",
            ]
        ),

        // TODO: make Objective-C tests work.
        // .testTarget(
        //     name: "VicrabTests",
        //     dependencies: [
        //         "Vicrab",
        //     ],
        //     exclude: [
        //         "VicrabSwiftTests.swift",
        //     ]
        // ),
    ]
)
