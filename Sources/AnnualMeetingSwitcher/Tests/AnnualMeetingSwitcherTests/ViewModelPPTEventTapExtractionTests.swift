import XCTest

final class ViewModelPPTEventTapExtractionTests: XCTestCase {
    func testPPTEventTapMethodsAreNotDeclaredInMainViewModel() throws {
        let source = try mainViewModelSource()

        [
            "func startPPTEventTapFromRuntime(",
            "func stopPPTEventTapFromRuntime(",
            "func startPageIntercept(",
            "func stopPageIntercept(",
            "func reenablePageIntercept(",
            "func handlePageInterceptKey(",
            "func sendPageKeyToWPS("
        ].forEach { marker in
            XCTAssertFalse(source.contains(marker), "\(marker) should live in ViewModel+PPTEventTap.swift")
        }
    }

    func testPPTEventTapMethodsLiveInPPTEventTapExtension() throws {
        let source = try XCTUnwrap(
            optionalRepositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+PPTEventTap.swift")
        )

        [
            "func startPPTEventTapFromRuntime(",
            "func stopPPTEventTapFromRuntime(",
            "func startPageIntercept(",
            "func stopPageIntercept(",
            "func reenablePageIntercept(",
            "func handlePageInterceptKey(",
            "func sendPageKeyToWPS("
        ].forEach { marker in
            XCTAssertTrue(source.contains(marker), "\(marker) should live in ViewModel+PPTEventTap.swift")
        }
    }

    func testPageInterceptCallbackIsNotDeclaredInMainViewModel() throws {
        let source = try mainViewModelSource()

        XCTAssertFalse(source.contains("func pageInterceptCallback("))
    }

    func testPageInterceptCallbackLivesInPPTEventTapFile() throws {
        let source = try XCTUnwrap(
            optionalRepositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+PPTEventTap.swift")
        )

        XCTAssertTrue(source.contains("func pageInterceptCallback("))
    }

    func testPPTKeyForwardingMethodsAreNotDeclaredInMainViewModel() throws {
        let source = try mainViewModelSource()

        XCTAssertFalse(source.contains("func handlePageInterceptKey("))
        XCTAssertFalse(source.contains("func sendPageKeyToWPS("))
    }

    func testPPTEventTapPermissionAlertCodeIsNotDeclaredInMainViewModel() throws {
        let source = try mainViewModelSource()

        XCTAssertFalse(source.contains("pageIntercept.accessibilityPermission"))
        XCTAssertFalse(source.contains("PPT模式需要辅助功能权限"))
    }

    private func mainViewModelSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
    }
}
