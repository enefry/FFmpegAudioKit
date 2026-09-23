import XCTest
@testable import FFmpegAudioKit

// 需要样本音频文件时把 SAMPLE_AUDIO 环境变量指向一个本地文件再跑，
// 否则依赖真实解码的用例自动跳过（CI/无样本环境不阻塞）。
final class FFmpegAudioKitTests: XCTestCase {
    private var sampleURL: URL? {
        ProcessInfo.processInfo.environment["SAMPLE_AUDIO"].map { URL(fileURLWithPath: $0) }
    }

    func testProbeReadsContainerAndDuration() throws {
        guard let url = sampleURL else {
            throw XCTSkip("设置 SAMPLE_AUDIO 环境变量指向本地音频文件后再运行")
        }
        let result = try FFmpegProbe.probe(localFileURL: url)
        XCTAssertFalse(result.tracks.isEmpty, "应至少探测到一条音频流")
        XCTAssertNotNil(result.duration)
    }

    func testDecoderProducesFrames() throws {
        guard let url = sampleURL else {
            throw XCTSkip("设置 SAMPLE_AUDIO 环境变量指向本地音频文件后再运行")
        }
        let decoder = try FFmpegAudioDecoder(localFileURL: url)
        let buffer = try decoder.nextBuffer()
        XCTAssertNotNil(buffer)
        XCTAssertGreaterThan(buffer?.frameLength ?? 0, 0)
    }

    func testMetadataReads() throws {
        guard let url = sampleURL else {
            throw XCTSkip("设置 SAMPLE_AUDIO 环境变量指向本地音频文件后再运行")
        }
        let meta = try FFmpegMetadataReader.read(localFileURL: url)
        // 至少能读到时长；标签/封面因文件而异，不强断言。
        XCTAssertNotNil(meta.duration)
    }
}
