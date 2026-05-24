import XCTest
@testable import LiveSwitcher

final class AudioPowerMeterTests: XCTestCase {
    func testAveragePowerDBReturnsNilForEmptySamples() {
        XCTAssertNil(AudioPowerMeter.averagePowerDB(samples: []))
    }

    func testAveragePowerDBFloorsSilence() throws {
        let db = try XCTUnwrap(AudioPowerMeter.averagePowerDB(samples: Array(repeating: 0, count: 128)))

        XCTAssertEqual(db, AudioPowerMeter.silenceFloorDB, accuracy: 0.001)
    }

    func testAveragePowerDBMapsFullScaleAndHalfScaleSamples() throws {
        let fullScale = try XCTUnwrap(AudioPowerMeter.averagePowerDB(samples: Array(repeating: 1, count: 128)))
        let halfScale = try XCTUnwrap(AudioPowerMeter.averagePowerDB(samples: Array(repeating: 0.5, count: 128)))

        XCTAssertEqual(fullScale, 0, accuracy: 0.001)
        XCTAssertEqual(halfScale, -6.02, accuracy: 0.05)
    }
}
