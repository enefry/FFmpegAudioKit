// swift-tools-version: 6.2

import Foundation
import PackageDescription

// FFmpegAudioKit
//
// 独立、可依赖、与业务解耦的 audio-only ffmpeg 封装：
//   - FFmpegAudio.xcframework：从源码交叉编译的 ffmpeg 动态 framework（见 Scripts/build-ffmpeg.sh）
//   - CFFmpegAudio：干净的 C wrapper（解码 / 探测 / 元数据），不外泄 ffmpeg 类型
//   - FFmpegAudioKit：通用 Swift API，零业务依赖，供任意 App 复用
//
// 不含播放器：PCM 输出后的 AVAudioEngine 播放逻辑由使用方自行实现。

// FFmpegAudio.xcframework 来源：
//   - 本地跑过 Scripts/build-ffmpeg.sh（Artifacts/ 下存在产物）时直接用本地产物；
//   - 否则使用 GitHub Release 上的预编译 zip。下面两行由 release workflow 自动改写。
let releaseBinaryURL = "https://github.com/enefry/FFmpegAudioKit/releases/download/0.0.2/FFmpegAudio.xcframework.zip" // release:url
let releaseBinaryChecksum = "da5b8ff4466c531f667c67bbc6f9fe3cd6beb9c5f8ef5e591f58d9b00d4b55e6" // release:checksum

let localBinaryPath = "Artifacts/FFmpegAudio.xcframework"
let usesLocalBinary = FileManager.default.fileExists(
    atPath: URL(fileURLWithPath: Context.packageDirectory)
        .appendingPathComponent(localBinaryPath).path
)
let ffmpegBinary: Target = usesLocalBinary
    ? .binaryTarget(name: "FFmpegAudio", path: localBinaryPath)
    : .binaryTarget(name: "FFmpegAudio", url: releaseBinaryURL, checksum: releaseBinaryChecksum)

let package = Package(
    name: "FFmpegAudioKit",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "FFmpegAudioKit", targets: ["FFmpegAudioKit"])
    ],
    targets: [
        ffmpegBinary,
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
            dependencies: ["FFmpegAudioKit"],
            resources: [.copy("Fixtures/dsd-quarter-second.dsf")]
        )
    ]
)
