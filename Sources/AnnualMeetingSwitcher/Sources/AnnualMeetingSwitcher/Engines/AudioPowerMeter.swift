import AVFoundation
import Foundation

enum AudioPowerMeter {
    static let silenceFloorDB: Float = -160

    static func averagePowerDB(samples: [Float]) -> Float? {
        guard !samples.isEmpty else { return nil }

        var sumSquares: Double = 0
        for sample in samples {
            let clamped = min(max(Double(sample), -1), 1)
            sumSquares += clamped * clamped
        }

        return averagePowerDB(sumSquares: sumSquares, sampleCount: samples.count)
    }

    static func averagePowerDB(
        bufferList: UnsafeMutablePointer<AudioBufferList>,
        streamDescription: AudioStreamBasicDescription
    ) -> Float? {
        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        guard !buffers.isEmpty else { return nil }

        var sumSquares: Double = 0
        var sampleCount = 0
        let formatID = streamDescription.mFormatID
        let formatFlags = streamDescription.mFormatFlags
        let bitsPerChannel = streamDescription.mBitsPerChannel

        for buffer in buffers {
            guard let data = buffer.mData, buffer.mDataByteSize > 0 else { continue }

            if formatID == kAudioFormatLinearPCM,
               formatFlags & kAudioFormatFlagIsFloat != 0,
               bitsPerChannel == 32 {
                let count = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
                let samples = data.assumingMemoryBound(to: Float.self)
                for index in 0..<count {
                    let clamped = min(max(Double(samples[index]), -1), 1)
                    sumSquares += clamped * clamped
                }
                sampleCount += count
            } else if formatID == kAudioFormatLinearPCM,
                      bitsPerChannel == 16 {
                let count = Int(buffer.mDataByteSize) / MemoryLayout<Int16>.size
                let samples = data.assumingMemoryBound(to: Int16.self)
                for index in 0..<count {
                    let normalized = Double(samples[index]) / Double(Int16.max)
                    let clamped = min(max(normalized, -1), 1)
                    sumSquares += clamped * clamped
                }
                sampleCount += count
            }
        }

        return averagePowerDB(sumSquares: sumSquares, sampleCount: sampleCount)
    }

    private static func averagePowerDB(sumSquares: Double, sampleCount: Int) -> Float? {
        guard sampleCount > 0 else { return nil }

        let meanSquare = sumSquares / Double(sampleCount)
        guard meanSquare > 0 else { return silenceFloorDB }

        let rms = sqrt(meanSquare)
        return Float(20 * log10(max(rms, 0.000_000_01)))
    }
}
