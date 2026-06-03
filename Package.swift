// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "whatscopy",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "WhatsCopy", targets: ["WhatsCopyApp"])
    ],
    targets: [
        .target(
            name: "WhatsCopy",
            path: "Sources/WhatsCopy",
            resources: [
                .copy("Resources")
            ]
        ),
        .executableTarget(
            name: "WhatsCopyApp",
            dependencies: ["WhatsCopy"],
            path: "Sources/WhatsCopyApp"
        ),
        .testTarget(
            name: "WhatsCopyTests",
            dependencies: ["WhatsCopy"],
            path: "Tests/WhatsCopyTests"
        )
    ]
)
