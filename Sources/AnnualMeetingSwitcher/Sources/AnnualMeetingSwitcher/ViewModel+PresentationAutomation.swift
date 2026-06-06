import AppKit

@MainActor
extension SwitcherViewModel {
    private var presentationQueryService: PresentationQueryService {
        if let presentationQueryService = testHooks.presentationQueryService {
            return presentationQueryService
        }

        return PresentationQueryService(
            runAppleScript: { script, action in
                try AppleScriptRunner.run(script, action: action)
            },
            queryOpenKeynoteFiles: { [keynoteController] in
                keynoteController.scanOpenKeynoteFiles()
            }
        )
    }

    func isLikelyValidDeckDocument(url: URL, sourceKind: ProgramSourceKind) -> Bool {
        PresentationDocumentValidator.isLikelyValid(url: url, sourceKind: sourceKind)
    }

    func presentInvalidDeckAlert(for url: URL) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "当前演示文件无效"
        alert.informativeText = "“\(url.lastPathComponent)” 不是可直接播放的演示文稿，已阻止发送到输出。请删除这条节目，或重新导入真实的 Keynote / PowerPoint 文件。"
        alert.addButton(withTitle: "好的")
        alert.runModal()
    }

    func runAutomationScript(_ source: String, action: String) {
        dispatchRuntimeFacadeAction(.automationScriptRequested(script: source, action: action))
    }

    private static func openWithWPSOffice(url: URL) async throws {
        guard let appURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: AppConfiguration.wpsBundleIdentifier
        ) else {
            throw AppleScriptError.executionFailed(
                action: "wps.open.command",
                message: "WPS Office application was not found"
            )
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            NSWorkspace.shared.open(
                [url],
                withApplicationAt: appURL,
                configuration: configuration
            ) { _, error in
                if let error {
                    continuation.resume(throwing: AppleScriptError.executionFailed(
                        action: "wps.open.command",
                        message: error.localizedDescription
                    ))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    /// Fix Issue #3: 打开并立即放映 Keynote 文件
    func openAndPresentKeynote(url: URL) {
        let script = PresentationAutomationService.keynoteStartScript(url: url)
        runAutomationScript(
            script,
            action: "keynote.open.present"
        )
    }

    /// V24 Fix #3: PPTX → 默认调取 WPS Office 执行播放（彻底替换 Keynote 调用逻辑）
    func openPPTXWithKeynote(url: URL) {
        Task { @MainActor [weak self] in
            // 优先尝试 WPS Office
            let wpsScript = PresentationAutomationService.wpsOpenScript(url: url)
            do {
                try AppleScriptRunner.run(wpsScript, action: "wps.open.script")
                return
            } catch {
                self?.handleAppleScriptFailure(error, action: "wps.open.script")
            }

            // WPS AppleScript 不可用时，降级用 NSWorkspace 打开 WPS，避免沙盒下调用 /usr/bin/open。
            do {
                try await Self.openWithWPSOffice(url: url)
            } catch {
                self?.handleAppleScriptFailure(error, action: "wps.open.command")
            }
        }
    }

    /// 放映当前最前面的 Keynote 文档
    func presentFrontKeynoteDocument() {
        let script = """
        tell application "Keynote"
            if (count of documents) > 0 then
                start (front document) from (slide 1 of front document)
            end if
        end tell
        """
        runAutomationScript(
            script,
            action: "keynote.present.front"
        )
    }

    /// Fix Issue #4: Keynote 下一张（右箭头）
    func keynoteNextSlide() {
        let script = """
        tell application "Keynote"
            if playing is true then
                show next
            end if
        end tell
        """
        runAutomationScript(
            script,
            action: "keynote.next-slide"
        )
    }

    /// Fix Issue #4: Keynote 上一张（左箭头）
    func keynotePreviousSlide() {
        let script = """
        tell application "Keynote"
            if playing is true then
                show previous
            end if
        end tell
        """
        runAutomationScript(
            script,
            action: "keynote.previous-slide"
        )
    }

    private func scanKeynoteWindowNames() throws -> [String] {
        if let scanKeynoteWindowNames = testHooks.scanKeynoteWindowNames {
            return try scanKeynoteWindowNames()
        }

        do {
            return try presentationQueryService.scanKeynoteWindowNames()
        } catch {
            handleAppleScriptFailure(error, action: "keynote.scan.windows")
            throw error
        }
    }

    private func scanOpenKeynoteFiles() -> [String] {
        if let scanOpenKeynoteFiles = testHooks.scanOpenKeynoteFiles {
            return scanOpenKeynoteFiles()
        }
        return presentationQueryService.queryOpenKeynoteFiles()
    }

    private func scanPresentationQuery() throws -> PresentationQueryResult {
        if testHooks.scanKeynoteWindowNames != nil || testHooks.scanOpenKeynoteFiles != nil {
            let windowNames: [String]
            if let scanKeynoteWindowNames = testHooks.scanKeynoteWindowNames {
                windowNames = try scanKeynoteWindowNames()
            } else {
                windowNames = try presentationQueryService.scanKeynoteWindowNames()
            }
            let openFilePaths = scanOpenKeynoteFiles()
            return PresentationQueryResult(
                openFilePaths: openFilePaths,
                windowNames: windowNames
            )
        }
        return try presentationQueryService.scanPresentationQuery()
    }

    func scanPresentationQueryForRuntimePort() throws -> PresentationQueryResult {
        try scanPresentationQuery()
    }

    func scanAndAddKeynoteWindows() {
        let requestID = UUID()
        dispatchRuntimeFacadeAction(.operatorRequestedPresentationQuery(id: requestID))
        consumePresentationQueryOutcomeFromRuntime(requestID: requestID)
    }

    func consumePresentationQueryOutcomeFromRuntime(requestID: UUID) {
        let presentationQuery = runtime.state.presentationQuery
        guard !presentationQuery.hasConsumed(requestID) else { return }

        if presentationQuery.latestCompletedRequestID == requestID,
           let result = presentationQuery.latestResult {
            let itemsToAdd = PresentationQueryResultBuilder.makeProgramItems(
                from: result,
                existingProgramItems: programItems
            )
            addProgramItems(itemsToAdd)
            dispatchRuntimeFacadeAction(.presentationQueryResultConsumed(id: requestID))
            return
        }

        if let failure = presentationQuery.latestFailure,
           failure.id == requestID {
            recordSupportEvent(
                kind: .appleScriptFailed,
                detail: "action=\(failure.action),error=\(failure.sanitizedMessage)"
            )
            dispatchRuntimeFacadeAction(.automationFailed(
                action: failure.action,
                sanitizedMessage: failure.sanitizedMessage
            ))
            dispatchRuntimeFacadeAction(.presentationQueryResultConsumed(id: requestID))
        }
    }

    func stopDeckPresentation() {
        let script = """
        tell application "Keynote"
            if playing is true then
                stop the front document
            end if
        end tell
        """
        runAutomationScript(
            script,
            action: "keynote.stop.presentation"
        )
    }
}
