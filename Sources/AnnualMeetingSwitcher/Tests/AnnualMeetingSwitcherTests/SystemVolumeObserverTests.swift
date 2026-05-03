import CoreAudio
import XCTest
@testable import LiveSwitcher

final class SystemVolumeObserverTests: XCTestCase {
    private final class FakeCoreAudioClient: CoreAudioClient {
        var defaultOutputDevice: AudioDeviceID? = 101
        var volumeByDevice: [AudioDeviceID: Float32] = [101: 0.45, 202: 0.75]
        private(set) var addedTokens: [CoreAudioListenerToken] = []
        private(set) var removedTokens: [CoreAudioListenerToken] = []

        func addPropertyListener(
            objectID: AudioObjectID,
            address: AudioObjectPropertyAddress,
            queue: DispatchQueue,
            block: @escaping AudioObjectPropertyListenerBlock
        ) -> CoreAudioListenerToken? {
            let token = CoreAudioListenerToken(
                objectID: objectID,
                address: address,
                queue: queue,
                block: block
            )
            addedTokens.append(token)
            return token
        }

        func removePropertyListener(_ token: CoreAudioListenerToken) {
            removedTokens.append(token)
        }

        func getDefaultOutputDevice() -> AudioDeviceID? {
            defaultOutputDevice
        }

        func getVirtualMainVolume(deviceID: AudioDeviceID) -> Float32? {
            volumeByDevice[deviceID]
        }
    }

    @MainActor
    func testRebindRemovesPreviousVolumeListenerTokenAndStopRemovesRemainingTokens() {
        let fakeClient = FakeCoreAudioClient()
        let observer = SystemVolumeObserver(client: fakeClient) { _, _ in }

        observer.start()

        XCTAssertEqual(fakeClient.addedTokens.count, 2)
        let routeToken = fakeClient.addedTokens[0]
        let firstVolumeToken = fakeClient.addedTokens[1]

        fakeClient.defaultOutputDevice = 202
        observer.rebindVolumeListener()

        XCTAssertTrue(fakeClient.removedTokens.contains { $0 === firstVolumeToken })
        XCTAssertEqual(fakeClient.addedTokens.count, 3)
        let secondVolumeToken = fakeClient.addedTokens[2]

        observer.stop()

        XCTAssertTrue(fakeClient.removedTokens.contains { $0 === routeToken })
        XCTAssertTrue(fakeClient.removedTokens.contains { $0 === secondVolumeToken })
    }
}
