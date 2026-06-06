import XCTest

final class ViewModelAssetsExtractionTests: XCTestCase {
    func testAssetMethodsAreNotDeclaredInMainViewModel() throws {
        let source = try viewModelSource()

        [
            "func loadBackgroundImage(",
            "func loadCornerLogoImage(",
            "func addWallpaper(",
            "func removeWallpaper(",
            "func setActiveWallpaper(",
            "func setCornerLogo(",
            "func removeCornerLogo(",
            "static func imageData("
        ].forEach { snippet in
            XCTAssertFalse(source.contains(snippet), snippet)
        }
    }

    func testAssetMethodsLiveInAssetsExtension() throws {
        let source = try assetsSource()

        [
            "func loadBackgroundImage(",
            "func loadCornerLogoImage(",
            "func addWallpaper(",
            "func removeWallpaper(",
            "func setActiveWallpaper(",
            "func setCornerLogo(",
            "func removeCornerLogo(",
            "static func imageData("
        ].forEach { snippet in
            XCTAssertTrue(source.contains(snippet), snippet)
        }
    }

    func testImageLoadHelpersAreNotDeclaredInMainViewModel() throws {
        let source = try viewModelSource()

        XCTAssertFalse(source.contains("func loadBackgroundImage("))
        XCTAssertFalse(source.contains("func loadCornerLogoImage("))
        XCTAssertFalse(source.contains("static func imageData("))
    }

    func testWallpaperLibraryMethodsAreNotDeclaredInMainViewModel() throws {
        let source = try viewModelSource()

        XCTAssertFalse(source.contains("func addWallpaper("))
        XCTAssertFalse(source.contains("func removeWallpaper("))
        XCTAssertFalse(source.contains("func setActiveWallpaper("))
    }

    func testCornerLogoMethodsAreNotDeclaredInMainViewModel() throws {
        let source = try viewModelSource()

        XCTAssertFalse(source.contains("func setCornerLogo("))
        XCTAssertFalse(source.contains("func removeCornerLogo("))
    }

    private func viewModelSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
    }

    private func assetsSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+Assets.swift")
    }
}
