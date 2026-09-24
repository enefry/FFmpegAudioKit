# FFmpegAudioKit

独立、可依赖、与业务解耦的 **audio-only ffmpeg** 封装。任意 iOS App 都可以通过 SwiftPM 直接依赖它做音频**解码 / 探测 / 元数据读取**。

- 从 ffmpeg 源码交叉编译，**不复用任何第三方（如 VLC）已编译产物** —— 真正独立。
- 只保留音频能力：视频、网络、滤镜、命令行工具全部关闭，体积最小化。
- C wrapper 不外泄任何 ffmpeg 类型；Swift API 只暴露格式中立的通用结构体。
- **不含播放器**：解出非交错（planar）Float32 PCM 后，AVAudioEngine 播放逻辑由使用方自行实现。

## 结构

```
Scripts/build-ffmpeg.sh            从源码 audio-only 交叉编译 → xcframework
Artifacts/FFmpegAudio.xcframework  构建产物（动态 FFmpegAudio.framework，需先跑脚本生成）
Sources/CFFmpegAudio/              C wrapper：decode / seek / probe / metadata
Sources/FFmpegAudioKit/            通用 Swift API（零业务依赖）
    FFmpegAudioDecoder             解码：PCM → AVAudioPCMBuffer（非交错 planar Float32）
    FFmpegProbe                    探测：流信息 / 容器 / 时长 / 是否含视频
    FFmpegMetadataReader           元数据：标签 + 内嵌封面
```

## 构建 xcframework

`Artifacts/FFmpegAudio.xcframework` 不入 git，首次使用前需本地生成：

```sh
./Scripts/build-ffmpeg.sh
```

脚本会：

1. 下载 pinned 版本 ffmpeg 源码（默认 `8.1.2`，缓存于 `.build-ffmpeg/`，不入 git）。
2. audio-only configure，交叉编译三片：`arm64-iphoneos`、`arm64-iphonesimulator`、`x86_64-iphonesimulator`（部署目标 iOS 17.0）。
3. 合并静态库并 `xcodebuild -create-xcframework`，产出 `ios-arm64` + `ios-arm64_x86_64-simulator`，每片为一个**动态** `FFmpegAudio.framework`。
4. 同步头文件到 `Sources/CFFmpegAudio/ffmpeg`（命令行 SwiftPM 构建下的私有 include 拷贝）。

可通过环境变量覆盖：`FFMPEG_VERSION`、`FFMPEG_URL`、`DEPLOY_TARGET`。

依赖：Xcode 命令行工具（`xcrun`/`clang`/`libtool`/`lipo`）、`curl`、`tar`。

## 许可证（LGPL）

本项目仅编译 ffmpeg 的 **LGPL** 子集（未开启 `--enable-gpl` 及任何 GPL 组件），
并以**动态 framework** 形式分发，使用方可替换/重链该 framework，因此接入的 App
无需开源自身代码。使用时仍需履行 LGPL 义务：随附 LGPL 许可证全文与 FFmpeg 归属
声明，并提供所用 ffmpeg 源码（本仓库固定 `FFMPEG_VERSION`，可复现构建）。

## 用法

```swift
import FFmpegAudioKit

// 解码
let decoder = try FFmpegAudioDecoder(localFileURL: url)
while let buffer = try decoder.nextBuffer() {
    // buffer 为非交错（planar）Float32 的 AVAudioPCMBuffer
}
try decoder.seek(to: .seconds(30))

// 探测
let probe = try FFmpegProbe.probe(localFileURL: url)
print(probe.container, probe.duration, probe.tracks)

// 元数据
let meta = try FFmpegMetadataReader.read(localFileURL: url)
print(meta.title, meta.artist, meta.artworks.count)
```
