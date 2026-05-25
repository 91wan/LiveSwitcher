import AppKit
import AVFoundation
import CryptoKit
import Foundation
import QuickLookThumbnailing

actor ThumbnailService {
    static let shared = ThumbnailService()

    static let defaultCacheDirectory: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("LiveSwitcher", isDirectory: true)
            .appendingPathComponent("thumbnails", isDirectory: true)
    }()

    private let cacheDirectory: URL

    init(cacheDirectory: URL = ThumbnailService.defaultCacheDirectory) {
        self.cacheDirectory = cacheDirectory
    }

    func thumbnail(
        for sourceURL: URL,
        kind: ProgramSourceKind,
        targetSize: CGSize = CGSize(width: 192, height: 108)
    ) async -> NSImage? {
        do {
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            let cacheURL = try cacheFileURL(for: sourceURL, kind: kind, targetSize: targetSize)
            if let cached = NSImage(contentsOf: cacheURL) {
                return cached
            }

            let generated = await generateThumbnail(for: sourceURL, kind: kind, targetSize: targetSize)
            guard let generated else { return nil }
            if let data = generated.pngData {
                try? data.write(to: cacheURL, options: [.atomic])
            }
            return generated
        } catch {
            return nil
        }
    }

    func cacheFileURL(
        for sourceURL: URL,
        kind: ProgramSourceKind,
        targetSize: CGSize
    ) throws -> URL {
        let modificationDate = try Self.fileModificationDate(for: sourceURL)
        return cacheDirectory.appendingPathComponent(
            Self.cacheKey(
                for: sourceURL,
                kind: kind,
                targetSize: targetSize,
                modificationDate: modificationDate
            )
        )
    }

    static func cacheKey(
        for sourceURL: URL,
        kind: ProgramSourceKind,
        targetSize: CGSize,
        modificationDate: Date?
    ) -> String {
        let raw = [
            sourceURL.standardizedFileURL.path,
            kind.cacheSlug,
            "\(Int(targetSize.width))x\(Int(targetSize.height))",
            "\(modificationDate?.timeIntervalSince1970 ?? 0)"
        ].joined(separator: "|")
        let digest = SHA256.hash(data: Data(raw.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return "\(digest).png"
    }

    static func fallbackSystemImage(for kind: ProgramSourceKind, isVideo: Bool) -> String {
        switch kind {
        case .media:
            return isVideo ? "film" : "music.note"
        case .html:
            return "globe"
        case .keynote, .activeDeck:
            return "play.rectangle.fill"
        case .pptx:
            return "doc.richtext"
        case .agendaMarker:
            return "mappin.and.ellipse"
        case .unsupported:
            return "doc.fill"
        }
    }

    private func generateThumbnail(
        for sourceURL: URL,
        kind: ProgramSourceKind,
        targetSize: CGSize
    ) async -> NSImage? {
        switch kind {
        case .media:
            if ProgramSourceKind.isVideoFileURL(sourceURL),
               let video = await generateVideoThumbnail(for: sourceURL, targetSize: targetSize) {
                return video
            }
            if ProgramSourceKind.isAudioFileURL(sourceURL) {
                if let waveform = await generateAudioThumbnail(for: sourceURL, targetSize: targetSize) {
                    return waveform
                }
                return await MainActor.run {
                    Self.renderAudioPlaceholder(size: targetSize)
                }
            }
            return await MainActor.run {
                Self.renderFallbackPlaceholder(for: kind, sourceURL: sourceURL, size: targetSize)
            }
        case .html, .keynote, .pptx:
            if let quickLook = await generateQuickLookThumbnail(for: sourceURL, targetSize: targetSize) {
                return quickLook
            }
            return await MainActor.run {
                Self.renderFallbackPlaceholder(for: kind, sourceURL: sourceURL, size: targetSize)
            }
        case .activeDeck, .agendaMarker, .unsupported:
            return await MainActor.run {
                Self.renderFallbackPlaceholder(for: kind, sourceURL: sourceURL, size: targetSize)
            }
        }
    }

    private func generateVideoThumbnail(for sourceURL: URL, targetSize: CGSize) async -> NSImage? {
        let asset = AVAsset(url: sourceURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = targetSize

        do {
            let cgImage = try generator.copyCGImage(at: CMTime(seconds: 0.5, preferredTimescale: 600), actualTime: nil)
            return NSImage(cgImage: cgImage, size: targetSize).resized(to: targetSize)
        } catch {
            return nil
        }
    }

    private func generateAudioThumbnail(for sourceURL: URL, targetSize: CGSize) async -> NSImage? {
        do {
            let samples = try Self.normalizedAudioSamples(for: sourceURL, sampleCount: 36)
            guard samples.contains(where: { $0 > 0 }) else { return nil }
            return await MainActor.run {
                Self.renderAudioWaveform(samples: samples, size: targetSize)
            }
        } catch {
            return nil
        }
    }

    static func normalizedAudioSamples(for sourceURL: URL, sampleCount: Int) throws -> [CGFloat] {
        guard sampleCount > 0 else { return [] }

        let file = try AVAudioFile(forReading: sourceURL)
        let totalFrames = file.length
        guard totalFrames > 0 else {
            return Array(repeating: 0, count: sampleCount)
        }

        let format = file.processingFormat
        let framesPerBucket = max(1, totalFrames / AVAudioFramePosition(sampleCount))
        var peaks: [CGFloat] = []
        peaks.reserveCapacity(sampleCount)

        for bucket in 0..<sampleCount {
            let framePosition = min(AVAudioFramePosition(bucket) * framesPerBucket, totalFrames - 1)
            file.framePosition = framePosition
            let remainingFrames = max(1, totalFrames - framePosition)
            let framesToRead = AVAudioFrameCount(min(remainingFrames, min(framesPerBucket, 2_048)))
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: framesToRead) else {
                peaks.append(0)
                continue
            }

            try file.read(into: buffer, frameCount: framesToRead)
            peaks.append(peakAmplitude(in: buffer))
        }

        let maxPeak = peaks.max() ?? 0
        guard maxPeak > 0 else { return peaks }
        return peaks.map { min(max($0 / maxPeak, 0), 1) }
    }

    private static func peakAmplitude(in buffer: AVAudioPCMBuffer) -> CGFloat {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        guard channelCount > 0, frameLength > 0 else { return 0 }

        var peak: Float = 0
        for channel in 0..<channelCount {
            let samples = channelData[channel]
            for frame in 0..<frameLength {
                peak = max(peak, abs(samples[frame]))
            }
        }
        return CGFloat(min(max(peak, 0), 1))
    }

    private func generateQuickLookThumbnail(for sourceURL: URL, targetSize: CGSize) async -> NSImage? {
        await withCheckedContinuation { continuation in
            let request = QLThumbnailGenerator.Request(
                fileAt: sourceURL,
                size: targetSize,
                scale: 1,
                representationTypes: .thumbnail
            )
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
                continuation.resume(returning: representation?.nsImage.resized(to: targetSize))
            }
        }
    }

    private static func fileModificationDate(for sourceURL: URL) throws -> Date? {
        let attributes = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
        return attributes[.modificationDate] as? Date
    }

    @MainActor
    private static func renderFallbackPlaceholder(for kind: ProgramSourceKind, sourceURL: URL, size: CGSize) -> NSImage {
        let isVideo = ProgramSourceKind.isVideoFileURL(sourceURL)
        return renderSymbolCard(
            systemName: fallbackSystemImage(for: kind, isVideo: isVideo),
            size: size,
            accentColor: NSColor.systemBlue
        )
    }

    @MainActor
    private static func renderAudioPlaceholder(size: CGSize) -> NSImage {
        let samples = (0..<22).map { index in
            CGFloat(sin(CGFloat(index) * 0.86) * 0.5 + 0.5)
        }
        return renderAudioWaveform(samples: samples, size: size)
    }

    @MainActor
    private static func renderAudioWaveform(samples: [CGFloat], size: CGSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.18, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: 10, yRadius: 10).fill()

        NSColor.systemBlue.withAlphaComponent(0.80).setStroke()
        let path = NSBezierPath()
        let midY = size.height / 2
        let columns = max(samples.count, 1)
        for index in 0..<columns {
            let x = columns == 1 ? size.width / 2 : CGFloat(index) / CGFloat(columns - 1) * size.width
            let amplitude = min(max(samples[index], 0), 1)
            let height = amplitude * size.height * 0.64 + 4
            path.move(to: CGPoint(x: x, y: midY - height / 2))
            path.line(to: CGPoint(x: x, y: midY + height / 2))
        }
        path.lineWidth = max(2, size.width / 96)
        path.stroke()
        return image
    }

    @MainActor
    private static func renderSymbolCard(systemName: String, size: CGSize, accentColor: NSColor) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.18, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: 10, yRadius: 10).fill()

        if let symbol = NSImage(systemSymbolName: systemName, accessibilityDescription: nil) {
            let side = min(size.width, size.height) * 0.42
            let rect = NSRect(
                x: (size.width - side) / 2,
                y: (size.height - side) / 2,
                width: side,
                height: side
            )
            accentColor.withAlphaComponent(0.92).setFill()
            symbol.withSymbolConfiguration(.init(pointSize: side, weight: .bold))?
                .draw(in: rect, from: .zero, operation: .sourceOver, fraction: 0.92)
        }

        return image
    }
}

private extension ProgramSourceKind {
    var cacheSlug: String {
        switch self {
        case .media:
            return "media"
        case .html:
            return "html"
        case .keynote:
            return "keynote"
        case .pptx:
            return "pptx"
        case .activeDeck:
            return "activeDeck"
        case .agendaMarker:
            return "agendaMarker"
        case .unsupported:
            return "unsupported"
        }
    }
}

private extension NSImage {
    var pngData: Data? {
        guard let tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffRepresentation) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }

    func resized(to size: CGSize) -> NSImage {
        guard self.size != size else { return self }
        let image = NSImage(size: size)
        image.lockFocus()
        draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .copy, fraction: 1)
        image.unlockFocus()
        return image
    }
}
