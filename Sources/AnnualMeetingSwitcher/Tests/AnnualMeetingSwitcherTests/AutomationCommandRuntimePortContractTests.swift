import XCTest
@testable import LiveSwitcher

@MainActor
final class AutomationCommandRuntimePortContractTests: XCTestCase {
    func testAutomationPortHasNoDefaultNoOpImplementation() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimePorts.swift")

        XCTAssertTrue(source.contains("protocol AutomationPort"))
        XCTAssertFalse(source.contains("extension AutomationPort"))
    }

    func testProductionClosureAutomationPortImplementsRun() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeClosurePorts.swift")
        let body = try XCTUnwrap(source.classBody(named: "ClosureAutomationPort"))

        XCTAssertTrue(source.contains("final class ClosureAutomationPort: AutomationPort"))
        XCTAssertTrue(body.contains("var runHandler: ((String, String) -> Void)?"))
        XCTAssertTrue(body.contains("func run(script: String, action: String)"))
        XCTAssertTrue(body.contains("runHandler?(script, action)"))
    }

    func testAutomationPortDoesNotOwnSupportStorage() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeClosurePorts.swift")
        let body = try XCTUnwrap(source.classBody(named: "ClosureAutomationPort"))

        XCTAssertFalse(body.contains("supportEvents"))
        XCTAssertFalse(body.contains("recordSupportEvent"))
    }

    func testAutomationPortDoesNotOwnAutomationNoticeStorage() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeClosurePorts.swift")
        let body = try XCTUnwrap(source.classBody(named: "ClosureAutomationPort"))

        XCTAssertFalse(body.contains("automationRuntimeNotice"))
        XCTAssertFalse(body.contains("AutomationRuntimeNotice"))
    }

    func testAutomationPortDoesNotRunForSupportOwnedMode() {
        let automation = AutomationCommandPortContractSpy()
        let runtime = LiveRuntimeStore(
            effectRunner: LiveRuntimeEffectRunner(recordsOnly: false, automation: automation),
            environment: .productionSupportOwning(now: Date(timeIntervalSince1970: 100))
        )

        runtime.dispatch(.automationScriptRequested(script: "tell application \"Keynote\"", action: "keynote.next-slide"))

        XCTAssertTrue(automation.actions.isEmpty)
    }

    func testAutomationCommandOwnedModeWiresAutomationPort() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertEqual(viewModel.runtimeBridgeMode, .programActivationOwned)
        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.automation))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: repositoryRoot().appendingPathComponent(relativePath), encoding: .utf8)
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

private final class AutomationCommandPortContractSpy: AutomationPort {
    private(set) var actions: [String] = []

    func run(script: String, action: String) {
        actions.append(action)
    }
}

private extension String {
    func classBody(named className: String) -> String? {
        guard let nameRange = range(of: "class \(className)") else { return nil }
        guard let openingBrace = self[nameRange.lowerBound...].firstIndex(of: "{") else { return nil }
        return balancedBody(startingAt: openingBrace)
    }

    func balancedBody(startingAt openingBrace: String.Index) -> String? {
        var depth = 0
        var index = openingBrace
        while index < endIndex {
            if self[index] == "{" {
                depth += 1
            } else if self[index] == "}" {
                depth -= 1
                if depth == 0 {
                    return String(self[openingBrace...index])
                }
            }
            index = self.index(after: index)
        }
        return nil
    }
}
