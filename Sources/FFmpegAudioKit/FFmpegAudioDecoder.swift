import AVFoundation
import CFFmpegAudio
import Foundation

/// ffmpeg C 解码桥的 Swift 薄封装。
///
/// 只做一件事：打开一个音频资源，按需把 PCM 解码进 `AVAudioPCMBuffer`
/// （交错 Float32）。它不是并发安全的——约定由单一解码队列独占访问，
/// 因此标注 `@unchecked Sendable` 以便在该队列间传递。
public final class FFmpegAudioDecoder: @unchecked Sendable {
    /// 解码输出格式，交错 Float32。
    public let format: AVAudioFormat
    /// 采样率下的总时长；未知为 nil。
    public let duration: Duration?

    private let handle: OpaquePointer
    private let channels: Int

    public enum DecoderError: Error {
        case open(Int32)
        case unsupportedFormat
    }

    /// 打开本地文件。远程资源留待后续版本（用自定义 AVIOContext + URLSession）。
    public init(localFileURL url: URL) throws {
        var status: Int32 = 0
        guard let handle = url.path.withCString({ ffaudio_open_file($0, &status) }) else {
            throw DecoderError.open(status)
        }
        let raw = ffaudio_format(handle)
        guard raw.sample_rate > 0, raw.channels > 0,
              let audioFormat = AVAudioFormat(
                  commonFormat: .pcmFormatFloat32,
                  sampleRate: Double(raw.sample_rate),
                  channels: AVAudioChannelCount(raw.channels),
                  interleaved: true
              )
        else {
            ffaudio_close(handle)
            throw DecoderError.unsupportedFormat
        }

        self.handle = handle
        self.format = audioFormat
        self.channels = Int(raw.channels)
        self.duration = raw.duration_ms >= 0 ? .milliseconds(raw.duration_ms) : nil
    }

    deinit {
        ffaudio_close(handle)
    }

    /// 把最多 `frameCapacity` 帧解码进新分配的 buffer。
    /// 返回 nil 表示到达文件尾，抛错表示解码失败。
    public func nextBuffer(frameCapacity: AVAudioFrameCount = 8192) throws -> AVAudioPCMBuffer? {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
            throw DecoderError.unsupportedFormat
        }
        let mBuffers = buffer.mutableAudioBufferList.pointee.mBuffers
        guard let data = mBuffers.mData?.assumingMemoryBound(to: Float.self) else {
            throw DecoderError.unsupportedFormat
        }

        let framesRead = ffaudio_read_float(handle, data, Int32(frameCapacity))
        if framesRead < 0 {
            throw DecoderError.open(framesRead)
        }
        if framesRead == 0 {
            return nil // EOF
        }
        buffer.frameLength = AVAudioFrameCount(framesRead)
        return buffer
    }

    /// seek 到指定位置；随后 `nextBuffer` 从该位置继续。
    public func seek(to position: Duration) throws {
        let ms = Int64(position.components.seconds * 1000
            + position.components.attoseconds / 1_000_000_000_000_000)
        let status = ffaudio_seek_ms(handle, ms)
        if status != FFAUDIO_OK.rawValue {
            throw DecoderError.open(status)
        }
    }
}
