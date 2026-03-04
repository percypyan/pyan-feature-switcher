// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PyanFeatureSwitcher",
	platforms: [
		.iOS(.v18),
		.macOS(.v15),
		.tvOS(.v18),
		.watchOS(.v11),
		.visionOS(.v2)
	],
    products: [
        .library(
            name: "PyanFeatureSwitcher",
            targets: ["PyanFeatureSwitcher"]
        ),
    ],
	dependencies: [
		.package(url: "https://github.com/apple/swift-log", from: "1.10.1")
	],
    targets: [
		.target(
            name: "PyanFeatureSwitcher",
			dependencies: [
				.product(name: "Logging", package: "swift-log")
			]
        ),
        .testTarget(
            name: "PyanFeatureSwitcherTests",
            dependencies: ["PyanFeatureSwitcher"],
            resources: [
                .process("Resources"),
            ]
        ),
    ]
)
