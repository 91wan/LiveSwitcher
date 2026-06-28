import XCTest

final class ViewModelProjectionPageInterceptStoreSplitTests: XCTestCase {
    func testProjectionAndPageInterceptStoresAreSplitFromRootViewModel() throws {
        let projectionStore = try XCTUnwrap(
            optionalRepositorySource(projectionStorePath),
            "Expected projection output storage to live in \(projectionStorePath)"
        )
        let pageInterceptStore = try XCTUnwrap(
            optionalRepositorySource(pageInterceptStorePath),
            "Expected page-intercept storage to live in \(pageInterceptStorePath)"
        )
        let viewModel = try repositorySource(viewModelPath)

        for token in projectionStoreTokens {
            XCTAssertNotNil(projectionStore.range(of: token), token)
        }
        for token in pageInterceptStoreTokens {
            XCTAssertNotNil(pageInterceptStore.range(of: token), token)
        }
        for token in rootStorageTokens {
            XCTAssertNil(viewModel.range(of: "private var \(token)"), token)
            XCTAssertNil(viewModel.range(of: "@ObservationIgnored private var \(token)"), token)
        }

        XCTAssertNotNil(viewModel.range(of: "projectionOutputStore"))
        XCTAssertNotNil(viewModel.range(of: "pageInterceptStore"))
    }

    private var projectionStoreTokens: [String] {
        [
            "struct ViewModelProjectionOutputStore",
            "outputWindowController",
            "makeOutputWindowController",
            "currentOutputWindowController",
            "setOutputWindowController",
            "clearOutputWindowController"
        ]
    }

    private var pageInterceptStoreTokens: [String] {
        [
            "struct ViewModelPageInterceptStore",
            "pageInterceptEventTap",
            "pageInterceptRunLoopSource",
            "pageInterceptSelfRefcon",
            "pendingPPTToggleSource",
            "installPageInterceptTap",
            "clearPageInterceptTap",
            "setPendingPPTToggleSource",
            "consumePendingPPTToggleSource"
        ]
    }

    private var rootStorageTokens: [String] {
        [
            "outputWindowController",
            "pageInterceptEventTap",
            "pageInterceptRunLoopSource",
            "pageInterceptSelfRefcon",
            "pendingPPTToggleSource"
        ]
    }

    private var projectionStorePath: String {
        "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel/Internal/ViewModelProjectionOutputStore.swift"
    }

    private var pageInterceptStorePath: String {
        "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel/Internal/ViewModelPageInterceptStore.swift"
    }

    private var viewModelPath: String {
        "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift"
    }
}
