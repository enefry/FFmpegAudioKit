// swift-tools-version: 6.2

import PackageDescription

// FFmpegAudioKit
//
// 独立、可依赖、与业务解耦的 audio-only ffmpeg 封装：
//   - FFmpegAudio.xcframework：从源码交叉编译的 ffmpeg 静态库（见 Scripts/build-ffmpeg.sh）
//   - CFFmpegAudio：干净的 C wrapper（解码 / 探测 / 元数据），不外泄 ffmpeg 类型
//   - FFmpegAudioKit：通用 Swift API，零业务依赖，供任意 App 复用
//
// 不含播放器：PCM 输出后的 AVAudioEngine 播放逻辑由使用方自行实现。
let package = Package(
    name: "FFmpegAudioKit",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "FFmpegAudioKit", targets: ["FFmpegAudioKit"])
    ],
    targets: [
        .binaryTarget(
            name: "FFmpegAudio",
            path: "Artifacts/FFmpegAudio.xcframework"
        ),
        .target(
            name: "CFFmpegAudio",
            dependencies: ["FFmpegAudio"],
            cSettings: [
                .headerSearchPath("ffmpeg")
            ],
            linkerSettings: [
                .linkedLibrary("z"),
                .linkedLibrary("bz2"),
                .linkedLibrary("iconv"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("CoreFoundation")
            ]
        ),
        .target(
            name: "FFmpegAudioKit",
            dependencies: ["CFFmpegAudio"]
        ),
        .testTarget(
            name: "FFmpegAudioKitTests",
            dependencies: ["FFmpegAudioKit"]
        )
    ]
)
