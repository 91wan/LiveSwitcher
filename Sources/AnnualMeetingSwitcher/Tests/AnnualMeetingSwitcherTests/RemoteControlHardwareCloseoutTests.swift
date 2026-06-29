import XCTest

final class RemoteControlHardwareCloseoutTests: XCTestCase {
    func testPhoneLANRemoteRehearsalDocumentHasCanonicalMatrixRows() throws {
        let document = try rehearsalDocument()
        let rows = hardwareMatrixRows(in: document)

        XCTAssertEqual(rows.count, expectedHardwareRows.count)
        for expectedRow in expectedHardwareRows {
            XCTAssertEqual(rows[expectedRow], "NOT RUN", expectedRow)
        }
    }

    func testPhoneLANRemoteRehearsalDocumentKeepsCloseoutBoundaries() throws {
        let document = try rehearsalDocument()

        XCTAssertTrue(document.contains("# Phone LAN Remote Rehearsal"))
        XCTAssertTrue(document.localizedStandardContains("No production code changes belong in this closeout slice."))
        XCTAssertTrue(document.localizedStandardContains("No release or tag is allowed from this document alone."))
        XCTAssertTrue(document.localizedStandardContains("Use PASS, FAIL, BLOCKED, or NOT RUN only."))
        XCTAssertTrue(document.localizedStandardContains("Do not paste per-run dated evidence into this canonical matrix."))
        XCTAssertTrue(document.localizedStandardContains(
            "Do not publish v0.6.0 until every required rehearsal row has real PASS evidence."
        ))
    }

    func testPhoneLANRemoteRehearsalDocumentRecordsSecurityAndNetworkLimits() throws {
        let document = try rehearsalDocument()

        XCTAssertTrue(document.localizedStandardContains("no cloud relay"))
        XCTAssertTrue(document.localizedStandardContains("no public internet remote"))
        XCTAssertTrue(document.localizedStandardContains("no UPnP or port mapping"))
        XCTAssertTrue(document.localizedStandardContains("token must not appear in logs"))
        XCTAssertTrue(document.localizedStandardContains(
            "support reports must not include token, full phone IP, program title, BGM title, or customer content"
        ))
        XCTAssertTrue(document.localizedStandardContains("Dangerous actions require long-press plus server confirmation nonce."))
    }

    private var expectedHardwareRows: [String] {
        [
            "Dedicated 5GHz router, iPhone Safari connects by QR",
            "Android Chrome connects by QR",
            "Public Wi-Fi with AP isolation fails gracefully",
            "Mac hotspot works",
            "Remote disabled rejects commands",
            "Token rotation invalidates old phone page",
            "Take Next latency acceptable",
            "Media play/pause works",
            "BGM play/pause/prev/next works",
            "Speaker mode works",
            "FTB long-press works, external output black",
            "Panic long-press works, external output black",
            "No accidental single-tap dangerous action",
            "Phone disconnect/reconnect safe",
            "Mac sleep/network change safe",
            "60-minute soak with phone connected"
        ]
    }

    private func hardwareMatrixRows(in document: String) -> [String: String] {
        var rows: [String: String] = [:]
        for line in document.split(separator: "\n").map(String.init) {
            let cells = line
                .split(separator: "|", omittingEmptySubsequences: false)
                .dropFirst()
                .dropLast()
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard cells.count == 2,
                  cells[0] != "Scenario",
                  !cells[0].allSatisfy({ $0 == "-" }) else {
                continue
            }
            rows[cells[0]] = cells[1]
        }
        return rows
    }

    private func rehearsalDocument() throws -> String {
        try String(
            contentsOf: repositoryRoot().appendingPathComponent("docs/qa/phone-lan-remote-rehearsal.md"),
            encoding: .utf8
        )
    }

    private func repositoryRoot() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            if FileManager.default.fileExists(atPath: directory.appendingPathComponent("docs").path) {
                return directory
            }
        }
        throw XCTSkip("Could not locate repository root from test source path.")
    }
}
