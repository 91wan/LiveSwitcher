import XCTest

final class ViewModelRuntimeIdentityStoreSplitTests: XCTestCase {
    func testRuntimeCallbackIdentityStoreIsSplitFromRootViewModel() throws {
        let store = try XCTUnwrap(
            optionalRepositorySource(storePath),
            "Expected runtime callback identity state to live in \(storePath)"
        )
        let viewModel = try repositorySource(viewModelPath)

        for token in requiredStoreTokens {
            XCTAssertNotNil(store.range(of: token), token)
        }

        XCTAssertNotNil(viewModel.range(of: "runtimeIdentityStore"))
        for token in rootStorageTokens {
            XCTAssertNil(viewModel.range(of: "@ObservationIgnored private var \(token)"), token)
        }
    }

    private var requiredStoreTokens: [String] {
        [
            "struct ViewModelRuntimeIdentityStore",
            "activeMediaGeneration",
            "activeMediaURL",
            "activeBGMGeneration",
            "activeBGMItemID",
            "activeBGMURL",
            "transientBGMItem",
            "func setActiveMedia",
            "func clearActiveMedia",
            "func setActiveBGM",
            "func clearActiveBGM",
            "func includeTransientBGMItem",
            "func clearTransientBGMItemIfNeeded"
        ]
    }

    private var rootStorageTokens: [String] {
        [
            "activeRuntimeMediaGenerationForCallbacks",
            "activeRuntimeMediaURLForCallbacks",
            "activeRuntimeBGMGenerationForCallbacks",
            "activeRuntimeBGMItemIDForCallbacks",
            "activeRuntimeBGMURLForCallbacks",
            "transientRuntimeBGMItem"
        ]
    }

    private var storePath: String {
        "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel/Internal/ViewModelRuntimeIdentityStore.swift"
    }

    private var viewModelPath: String {
        "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift"
    }
}
