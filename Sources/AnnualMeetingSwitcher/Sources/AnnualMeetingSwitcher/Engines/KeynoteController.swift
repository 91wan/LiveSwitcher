import Foundation
import AppKit

// MARK: - KeynoteController
// 职责：
// 1. 用 NSAppleScript 控制 Keynote 在窗口内放映
// 2. Issue #5: 用 System Events 精确扫描 Keynote 已打开的窗口
// 3. Issue #9: 支持扫描 PPTX 转换后的 Keynote 文档

final class KeynoteController {

    // MARK: - Error

    enum KeynoteError: LocalizedError {
        case scriptCompilationFailed(String)
        case scriptExecutionFailed(String)
        case invalidFilePath
        case keynoteNotRunning

        var errorDescription: String? {
            switch self {
            case .scriptCompilationFailed(let msg): return "AppleScript 编译失败: \(msg)"
            case .scriptExecutionFailed(let msg):   return "AppleScript 执行失败: \(msg)"
            case .invalidFilePath:                   return "Keynote 文件路径无效"
            case .keynoteNotRunning:                 return "Keynote 未在运行"
            }
        }
    }

    // MARK: - Issue #5: 用 System Events 精确扫描 Keynote 窗口名

    /// 通过 System Events 获取 Keynote 所有窗口名
    func scanKeynoteWindowNames() -> [String] {
        // Issue #5: 精确扫描 System Events
        let script = """
        tell application "System Events"
            try
                if exists application process "Keynote" then
                    return name of every window of application process "Keynote"
                else
                    return {}
                end if
            on error
                return {}
            end try
        end tell
        """

        var errorDict: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else { return [] }
        let result = appleScript.executeAndReturnError(&errorDict)
        guard errorDict == nil else { return [] }

        var names: [String] = []
        if result.numberOfItems > 0 {
            for i in 1...result.numberOfItems {
                if let item = result.atIndex(i), let name = item.stringValue, !name.isEmpty {
                    names.append(name)
                }
            }
        } else if let single = result.stringValue, !single.isEmpty {
            names.append(single)
        }
        return names
    }

    // MARK: - Issue #5: 扫描后台已打开的 .key 文件（通过 Keynote 直接获取路径）

    /// 返回 Keynote 当前所有已打开文档的文件路径列表
    func scanOpenKeynoteFiles() -> [String] {
        // 先检测 Keynote 是否在运行
        let keynoteRunning = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "com.apple.iWork.Keynote"
        }
        guard keynoteRunning else { return [] }

        // 优先尝试直接从 Keynote 获取文档路径
        let script = """
        tell application "Keynote"
            set allPaths to {}
            repeat with d in documents
                try
                    set docPath to POSIX path of (path of d)
                    set end of allPaths to docPath
                on error
                    -- 跳过未保存的文档
                end try
            end repeat
            return allPaths
        end tell
        """

        var errorDict: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else { return [] }

        let result = appleScript.executeAndReturnError(&errorDict)
        guard errorDict == nil else { return [] }

        var paths: [String] = []
        if result.numberOfItems > 0 {
            for i in 1...result.numberOfItems {
                if let item = result.atIndex(i),
                   let path = item.stringValue, !path.isEmpty {
                    paths.append(path)
                }
            }
        } else if let singlePath = result.stringValue, !singlePath.isEmpty {
            paths.append(singlePath)
        }

        // 包含 .key 和 .pptx（Keynote 打开后也会有 pptx 路径）
        return paths.filter { $0.hasSuffix(".key") || $0.hasSuffix(".pptx") || $0.hasSuffix(".keynote") }
    }

    // MARK: - 以"在窗口中播放"方式启动指定 Keynote 文件放映

    func startPresentationInWindow(filePath: String) throws {
        guard !filePath.isEmpty else { throw KeynoteError.invalidFilePath }

        let posixPath = (filePath as NSString).expandingTildeInPath

        let script = """
        tell application "Keynote"
            activate
            open \(AppleScriptSupport.posixFileExpression(path: posixPath))
            delay 0.5
            tell front document
                play slideshow in window true
            end tell
        end tell
        """

        try runAppleScript(script)
    }

    /// 停止 Keynote 当前正在播放的幻灯片
    func stopPresentation() throws {
        let script = """
        tell application "Keynote"
            if playing is true then
                stop the front document
            end if
        end tell
        """
        try runAppleScript(script)
    }

    // MARK: - Private Helpers

    private func runAppleScript(_ source: String) throws {
        var errorDict: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            throw KeynoteError.scriptCompilationFailed("无法初始化 NSAppleScript 对象")
        }

        script.compileAndReturnError(&errorDict)
        if let err = errorDict {
            let msg = err[NSAppleScript.errorMessage] as? String ?? err.description
            throw KeynoteError.scriptCompilationFailed(msg)
        }

        script.executeAndReturnError(&errorDict)
        if let err = errorDict {
            let msg = err[NSAppleScript.errorMessage] as? String ?? err.description
            throw KeynoteError.scriptExecutionFailed(msg)
        }
    }
}
