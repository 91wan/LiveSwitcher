import XCTest
@testable import LiveSwitcher

final class SwitcherPersistenceRepairTests: XCTestCase {
    func testLoadDoesNotRewriteWallpaperPaths() throws {
        let defaults = try makeDefaults()
        let good = try makeTempPNG()
        let bad = try makeTempFile(extension: "png", contents: Data("not image".utf8))
        defaults.set([good.path, bad.path], forKey: "backgroundWallpapers_paths")

        _ = SwitcherPersistenceStore(userDefaults: defaults).load()

        XCTAssertEqual(defaults.stringArray(forKey: "backgroundWallpapers_paths"), [good.path, bad.path])
    }

    func testLoadDoesNotRewriteActiveWallpaper() throws {
        let defaults = try makeDefaults()
        let first = try makeTempPNG()
        let missing = "/tmp/missing-\(UUID().uuidString).png"
        defaults.set([first.path], forKey: "backgroundWallpapers_paths")
        defaults.set(missing, forKey: "activeWallpaper_path")

        _ = SwitcherPersistenceStore(userDefaults: defaults).load()

        XCTAssertEqual(defaults.string(forKey: "activeWallpaper_path"), missing)
    }

    func testLoadDoesNotRemoveCornerLogo() throws {
        let defaults = try makeDefaults()
        let missing = "/tmp/missing-\(UUID().uuidString).png"
        defaults.set(missing, forKey: "cornerLogo_path")

        _ = SwitcherPersistenceStore(userDefaults: defaults).load()

        XCTAssertEqual(defaults.string(forKey: "cornerLogo_path"), missing)
    }

    func testLoadReturnsWallpaperRewriteRepair() throws {
        let defaults = try makeDefaults()
        let good = try makeTempPNG()
        let bad = try makeTempFile(extension: "png", contents: Data("not image".utf8))
        defaults.set([good.path, bad.path], forKey: "backgroundWallpapers_paths")

        let result = SwitcherPersistenceStore(userDefaults: defaults).load()

        XCTAssertTrue(result.repairs.contains(.rewriteWallpaperPaths([good.path])))
    }

    func testLoadReturnsActiveWallpaperRepair() throws {
        let defaults = try makeDefaults()
        let first = try makeTempPNG()
        defaults.set([first.path], forKey: "backgroundWallpapers_paths")
        defaults.set("/tmp/missing-\(UUID().uuidString).png", forKey: "activeWallpaper_path")

        let result = SwitcherPersistenceStore(userDefaults: defaults).load()

        XCTAssertTrue(result.repairs.contains(.setActiveWallpaperPath(first.path)))
    }

    func testLoadReturnsActiveWallpaperRemovalRepair() throws {
        let defaults = try makeDefaults()
        defaults.set(["/tmp/missing-\(UUID().uuidString).png"], forKey: "backgroundWallpapers_paths")
        defaults.set("/tmp/missing-\(UUID().uuidString).png", forKey: "activeWallpaper_path")

        let result = SwitcherPersistenceStore(userDefaults: defaults).load()

        XCTAssertTrue(result.repairs.contains(.removeActiveWallpaper))
    }

    func testLoadReturnsCornerLogoRemovalRepair() throws {
        let defaults = try makeDefaults()
        defaults.set("/tmp/missing-\(UUID().uuidString).png", forKey: "cornerLogo_path")

        let result = SwitcherPersistenceStore(userDefaults: defaults).load()

        XCTAssertTrue(result.repairs.contains(.removeCornerLogo))
    }

    func testApplyRepairsRewritesWallpaperPaths() throws {
        let defaults = try makeDefaults()

        SwitcherPersistenceStore(userDefaults: defaults).applyRepairs([.rewriteWallpaperPaths(["/tmp/a.png", "/tmp/b.png"])])

        XCTAssertEqual(defaults.stringArray(forKey: "backgroundWallpapers_paths"), ["/tmp/a.png", "/tmp/b.png"])
    }

    func testApplyRepairsSetsActiveWallpaper() throws {
        let defaults = try makeDefaults()

        SwitcherPersistenceStore(userDefaults: defaults).applyRepairs([.setActiveWallpaperPath("/tmp/active.png")])

        XCTAssertEqual(defaults.string(forKey: "activeWallpaper_path"), "/tmp/active.png")
    }

    func testApplyRepairsRemovesActiveWallpaper() throws {
        let defaults = try makeDefaults()
        defaults.set("/tmp/old.png", forKey: "activeWallpaper_path")

        SwitcherPersistenceStore(userDefaults: defaults).applyRepairs([.removeActiveWallpaper])

        XCTAssertNil(defaults.string(forKey: "activeWallpaper_path"))
    }

    func testApplyRepairsRemovesCornerLogo() throws {
        let defaults = try makeDefaults()
        defaults.set("/tmp/old-logo.png", forKey: "cornerLogo_path")

        SwitcherPersistenceStore(userDefaults: defaults).applyRepairs([.removeCornerLogo])

        XCTAssertNil(defaults.string(forKey: "cornerLogo_path"))
    }

    func testLoadFunctionDoesNotCallUserDefaultsSetOrRemove() throws {
        let source = try persistenceStoreSource()
        let loadBody = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "load"))

        XCTAssertFalse(loadBody.contains(".set("))
        XCTAssertFalse(loadBody.contains(".removeObject("))
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "SwitcherPersistenceRepairTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeTempFile(extension pathExtension: String, contents: Data = Data()) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(pathExtension)
        try contents.write(to: url)
        return url
    }

    private func makeTempPNG() throws -> URL {
        let data = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=")!
        return try makeTempFile(extension: "png", contents: data)
    }

    private func persistenceStoreSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/SwitcherPersistenceStore.swift")
    }
}
