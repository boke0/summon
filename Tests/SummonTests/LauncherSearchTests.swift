import AppKit
import Foundation
import SummonKit
import SwiftUI
import Testing
import Vision
@testable import summon

@MainActor
private func makeLauncher(
    plugins: [(name: String, titles: [String], delay: TimeInterval)]
) throws -> (model: LauncherModel, root: URL) {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("summon-launcher-\(UUID().uuidString)")
    let bundled = root.appendingPathComponent("bundled")
    let user = root.appendingPathComponent("user")
    try FileManager.default.createDirectory(at: user, withIntermediateDirectories: true)

    for plugin in plugins {
        try writeSearchPlugin(
            named: plugin.name,
            titles: plugin.titles,
            delay: plugin.delay,
            in: bundled
        )
    }

    let configURL = root.appendingPathComponent("config.json")
    let names = plugins.map(\.name)
    let config = #"{"tabs":\#(String(data: try JSONEncoder().encode(names), encoding: .utf8) ?? "[]")}"#
    try Data(config.utf8).write(to: configURL)

    let model = LauncherModel(
        bundledPluginsDirectory: bundled,
        userPluginsDirectory: user,
        configURL: configURL
    )
    return (model, root)
}

private func writeSearchPlugin(
    named name: String,
    titles: [String],
    delay: TimeInterval,
    in root: URL
) throws {
    let dir = root.appendingPathComponent(name)
    let bin = dir.appendingPathComponent("bin")
    try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)

    let manifest = """
    {"name":"\(name)","title":"\(name)","search":["bin/search"],"action":["bin/action"]}
    """
    try Data(manifest.utf8).write(to: dir.appendingPathComponent("plugin.json"))

    var listLines = ""
    for (index, title) in titles.enumerated() {
        listLines += "\(name)-\(index)|\(title)\n"
    }

    let delayLine = delay > 0 ? "sleep \(delay)" : ""
    let search = """
    #!/bin/bash
    set -euo pipefail
    \(delayLine)
    query="${1-}"
    query_lc=$(printf '%s' "$query" | tr '[:upper:]' '[:lower:]')
    json_items=""
    while IFS='|' read -r id title; do
      [ -z "$id" ] && continue
      title_lc=$(printf '%s' "$title" | tr '[:upper:]' '[:lower:]')
      if [ -z "$query_lc" ] || [[ "$title_lc" == "$query_lc"* ]]; then
        item=$(printf '{"id":"%s","title":"%s"}' "$id" "$title")
        if [ -z "$json_items" ]; then
          json_items="$item"
        else
          json_items="$json_items,$item"
        fi
      fi
    done <<'LIST'
    \(listLines)LIST
    printf '{"items":[%s]}\\n' "$json_items"
    """
    let searchURL = bin.appendingPathComponent("search")
    try Data(search.utf8).write(to: searchURL)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: searchURL.path)

    let action = "#!/bin/bash\nexit 0\n"
    let actionURL = bin.appendingPathComponent("action")
    try Data(action.utf8).write(to: actionURL)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: actionURL.path)
}

@MainActor
private func waitUntil(
    timeout: Duration = .seconds(3),
    _ condition: () -> Bool,
    sourceLocation: SourceLocation = #_sourceLocation
) async {
    let start = ContinuousClock.now
    while ContinuousClock.now - start < timeout {
        if condition() { return }
        try? await Task.sleep(for: .milliseconds(20))
    }
    Issue.record("timed out waiting for search results", sourceLocation: sourceLocation)
}

@Suite(.serialized)
@MainActor
struct LauncherSearchTests {
    @Test func queryFilterReplacesCandidateContentsNotJustCount() async throws {
        let cursorTitles = (0..<8).map { "Cursor-\($0)" }
        let (model, root) = try makeLauncher(plugins: [
            (name: "cursor", titles: cursorTitles, delay: 0),
        ])
        defer { try? FileManager.default.removeItem(at: root) }

        model.prepareForDisplay()
        await waitUntil { model.candidates.count == 8 }
        #expect(model.candidates.map(\.title) == cursorTitles)

        model.query = "Cursor-7"
        await waitUntil { model.candidates.count == 1 }
        let titles = model.candidates.map(\.title)
        #expect(titles == ["Cursor-7"])
        #expect(titles != ["Cursor-0"])
    }

    @Test func switchingTabsReplacesCandidatesWithTheNewPlugin() async throws {
        let cursorTitles = (0..<8).map { "Cursor-\($0)" }
        let appsTitles = (0..<5).map { "Apps-\($0)" }
        let (model, root) = try makeLauncher(plugins: [
            (name: "cursor", titles: cursorTitles, delay: 0),
            (name: "apps", titles: appsTitles, delay: 0),
        ])
        defer { try? FileManager.default.removeItem(at: root) }

        model.prepareForDisplay()
        await waitUntil { model.candidates.map(\.title) == cursorTitles }

        let appsIndex = try #require(model.tabs.firstIndex { $0.manifest.name == "apps" })
        model.selectTab(at: appsIndex)
        await waitUntil { model.candidates.count == 5 }

        let titles = model.candidates.map(\.title)
        #expect(titles == appsTitles)
        #expect(Array(cursorTitles.prefix(5)) != titles)
    }

    @Test func switchingTabsThenFilteringUsesNewPluginMatches() async throws {
        let cursorTitles = (0..<8).map { "Cursor-\($0)" }
        let appsTitles = (0..<5).map { "Apps-\($0)" }
        let (model, root) = try makeLauncher(plugins: [
            (name: "cursor", titles: cursorTitles, delay: 0),
            (name: "apps", titles: appsTitles, delay: 0),
        ])
        defer { try? FileManager.default.removeItem(at: root) }

        model.prepareForDisplay()
        await waitUntil { model.candidates.map(\.title) == cursorTitles }

        let appsIndex = try #require(model.tabs.firstIndex { $0.manifest.name == "apps" })
        model.selectTab(at: appsIndex)
        await waitUntil { model.candidates.count == 5 }

        model.query = "Apps-4"
        await waitUntil { model.candidates.count == 1 }

        let titles = model.candidates.map(\.title)
        #expect(titles == ["Apps-4"])
        #expect(titles != ["Cursor-0"])
    }

    @Test func slowerPreviousTabSearchDoesNotOverwriteNewTabResults() async throws {
        let (model, root) = try makeLauncher(plugins: [
            (name: "cursor", titles: ["Cursor-0", "Cursor-1"], delay: 0.4),
            (name: "apps", titles: ["Apps-0"], delay: 0),
        ])
        defer { try? FileManager.default.removeItem(at: root) }

        model.prepareForDisplay()
        try? await Task.sleep(for: .milliseconds(50))

        let appsIndex = try #require(model.tabs.firstIndex { $0.manifest.name == "apps" })
        model.selectTab(at: appsIndex)
        await waitUntil { model.candidates.map(\.title) == ["Apps-0"] }

        try? await Task.sleep(for: .milliseconds(500))
        let titles = model.candidates.map(\.title)
        #expect(titles == ["Apps-0"])
    }

    @Test func hostedLauncherViewRowsMatchFilteredCandidates() async throws {
        let cursorTitles = (0..<8).map { "Cursor-\($0)" }
        let (model, root) = try makeLauncher(plugins: [
            (name: "cursor", titles: cursorTitles, delay: 0),
        ])
        defer { try? FileManager.default.removeItem(at: root) }

        let (hosting, window) = hostedLauncher(model)
        defer { window.orderOut(nil) }

        model.prepareForDisplay()
        await waitUntil { model.candidates.count == 8 }
        layoutHost(hosting)

        model.query = "Cursor-7"
        await waitUntil { model.candidates.map(\.title) == ["Cursor-7"] }
        layoutHost(hosting)

        let rendered = try ocrRowTitles(in: hosting, prefixes: ["Cursor-"])
        #expect(model.candidates.map(\.title) == ["Cursor-7"])
        #expect(rendered == ["Cursor-7"])
        #expect(!rendered.contains("Cursor-0"))
    }

    @Test func hostedLauncherViewAppsToCursorShowsRenderedCursorTitles() async throws {
        let appsTitles = (0..<12).map { "Apps-\($0)" }
        let cursorTitles = (0..<3).map { "Cursor-\($0)" }
        let (model, root) = try makeLauncher(plugins: [
            (name: "apps", titles: appsTitles, delay: 0),
            (name: "cursor", titles: cursorTitles, delay: 0.05),
        ])
        defer { try? FileManager.default.removeItem(at: root) }

        model.prepareForDisplay()
        await waitUntil { model.candidates.map(\.title) == appsTitles }

        let (hosting, window) = hostedLauncher(model)
        defer { window.orderOut(nil) }
        layoutHost(hosting)

        let appsRendered = try ocrRowTitles(in: hosting, prefixes: ["Apps-", "Cursor-"])
        #expect(appsRendered.contains("Apps-0"))
        #expect(!appsRendered.contains(where: { $0.hasPrefix("Cursor-") }))

        let scrollBefore = firstSubview(in: hosting, typeNameContains: "HostingScrollView")
        let cursorIndex = try #require(model.tabs.firstIndex { $0.manifest.name == "cursor" })
        model.selectTab(at: cursorIndex)
        #expect(model.candidates.isEmpty)

        await waitUntil { model.candidates.map(\.title) == cursorTitles }
        layoutHost(hosting)
        layoutHost(hosting)

        let rendered = try ocrRowTitles(in: hosting, prefixes: ["Apps-", "Cursor-"])
        let scrollAfter = firstSubview(in: hosting, typeNameContains: "HostingScrollView")

        #expect(model.candidates.map(\.title) == cursorTitles)
        #expect(rendered == cursorTitles)
        #expect(!rendered.contains(where: { $0.hasPrefix("Apps-") }))
        #expect(scrollBefore != nil)
        #expect(scrollAfter != nil)
        #expect(scrollBefore !== scrollAfter)
    }

    @Test func hostedLauncherViewRowsMatchAfterTabSwitchAndFilter() async throws {
        let cursorTitles = (0..<8).map { "Cursor-\($0)" }
        let appsTitles = (0..<5).map { "Apps-\($0)" }
        let (model, root) = try makeLauncher(plugins: [
            (name: "cursor", titles: cursorTitles, delay: 0),
            (name: "apps", titles: appsTitles, delay: 0),
        ])
        defer { try? FileManager.default.removeItem(at: root) }

        model.prepareForDisplay()
        await waitUntil { model.candidates.map(\.title) == cursorTitles }

        let (hosting, window) = hostedLauncher(model)
        defer { window.orderOut(nil) }
        layoutHost(hosting)

        let appsIndex = try #require(model.tabs.firstIndex { $0.manifest.name == "apps" })
        model.selectTab(at: appsIndex)
        #expect(model.candidates.isEmpty)

        await waitUntil { model.candidates.map(\.title) == appsTitles }
        layoutHost(hosting)
        #expect(try ocrRowTitles(in: hosting, prefixes: ["Apps-", "Cursor-"]) == appsTitles)

        model.query = "Apps-4"
        await waitUntil { model.candidates.map(\.title) == ["Apps-4"] }
        layoutHost(hosting)

        let rendered = try ocrRowTitles(in: hosting, prefixes: ["Apps-", "Cursor-"])
        #expect(rendered == ["Apps-4"])
        #expect(!rendered.contains(where: { $0.hasPrefix("Cursor-") }))
    }

    @Test func selectTabClearsCandidatesImmediately() async throws {
        let (model, root) = try makeLauncher(plugins: [
            (name: "cursor", titles: ["Cursor-0", "Cursor-1"], delay: 0),
            (name: "apps", titles: ["Apps-0"], delay: 0.4),
        ])
        defer { try? FileManager.default.removeItem(at: root) }

        model.prepareForDisplay()
        await waitUntil { model.candidates.map(\.title) == ["Cursor-0", "Cursor-1"] }

        let appsIndex = try #require(model.tabs.firstIndex { $0.manifest.name == "apps" })
        model.selectTab(at: appsIndex)
        #expect(model.candidates.isEmpty)
        #expect(model.selectedTabIndex == appsIndex)
        await waitUntil { model.candidates.map(\.title) == ["Apps-0"] }
    }

    @Test func leftAndRightArrowKeysSwitchTabs() async throws {
        let (model, root) = try makeLauncher(plugins: [
            (name: "apps", titles: ["Apps-0"], delay: 0),
            (name: "cursor", titles: ["Cursor-0"], delay: 0),
        ])
        defer { try? FileManager.default.removeItem(at: root) }

        model.prepareForDisplay()
        await waitUntil { !model.candidates.isEmpty }
        let start = model.selectedTabIndex
        let expectedRight = (start + 1) % model.tabs.count

        #expect(LauncherKeyBinding.resolve(keyDown(code: 124), tabModifier: .command) == .adjacentTab(1))
        #expect(LauncherKeyBinding.resolve(keyDown(code: 123), tabModifier: .command) == .adjacentTab(-1))
        #expect(LauncherKeyBinding.resolve(keyDown(code: 125), tabModifier: .command) == .moveSelection(1))
        #expect(LauncherKeyBinding.resolve(keyDown(code: 126), tabModifier: .command) == .moveSelection(-1))
        #expect(LauncherKeyBinding.resolve(keyDown(code: 36), tabModifier: .command) == .confirm)
        #expect(LauncherKeyBinding.resolve(keyDown(code: 53), tabModifier: .command) == .hide)
        #expect(
            LauncherKeyBinding.resolve(keyDown(code: 124, modifiers: [.command, .function]), tabModifier: .command)
                == nil
        )
        #expect(
            LauncherKeyBinding.resolve(keyDown(code: 18, modifiers: .command, characters: "1"), tabModifier: .command)
                == .selectTab(0)
        )

        guard let right = LauncherKeyBinding.resolve(keyDown(code: 124), tabModifier: model.tabModifier),
              case .adjacentTab(let delta) = right
        else {
            Issue.record("right arrow should switch tabs")
            return
        }
        model.selectAdjacentTab(delta: delta)
        #expect(model.selectedTabIndex == expectedRight)

        guard let left = LauncherKeyBinding.resolve(keyDown(code: 123), tabModifier: model.tabModifier),
              case .adjacentTab(let back) = left
        else {
            Issue.record("left arrow should switch tabs")
            return
        }
        model.selectAdjacentTab(delta: back)
        #expect(model.selectedTabIndex == start)
    }
}

@MainActor
private func hostedLauncher(_ model: LauncherModel) -> (NSHostingView<LauncherView>, NSWindow) {
    _ = NSApplication.shared
    let hosting = NSHostingView(rootView: LauncherView(model: model))
    hosting.frame = NSRect(x: 0, y: 0, width: 560, height: 420)
    let window = NSWindow(
        contentRect: hosting.frame,
        styleMask: [.titled],
        backing: .buffered,
        defer: false
    )
    window.contentView = hosting
    window.orderFront(nil)
    return (hosting, window)
}

@MainActor
private func layoutHost(_ hosting: NSView) {
    hosting.layoutSubtreeIfNeeded()
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.08))
}

@MainActor
private func firstSubview(in view: NSView, typeNameContains: String) -> NSView? {
    if String(describing: type(of: view)).contains(typeNameContains) {
        return view
    }
    for child in view.subviews {
        if let match = firstSubview(in: child, typeNameContains: typeNameContains) {
            return match
        }
    }
    return nil
}

private func keyDown(
    code: UInt16,
    modifiers: NSEvent.ModifierFlags = .function,
    characters: String = ""
) -> NSEvent {
    NSEvent.keyEvent(
        with: .keyDown,
        location: .zero,
        modifierFlags: modifiers,
        timestamp: 0,
        windowNumber: 0,
        context: nil,
        characters: characters,
        charactersIgnoringModifiers: characters,
        isARepeat: false,
        keyCode: code
    )!
}

@MainActor
private func ocrRowTitles(in view: NSView, prefixes: [String]) throws -> [String] {
    try ocrStrings(in: view).filter { value in
        prefixes.contains { value.hasPrefix($0) }
    }
}

@MainActor
private func ocrStrings(in view: NSView) throws -> [String] {
    view.layoutSubtreeIfNeeded()
    let bounds = view.bounds
    guard let rep = view.bitmapImageRepForCachingDisplay(in: bounds) else {
        return []
    }
    view.cacheDisplay(in: bounds, to: rep)
    guard let cgImage = rep.cgImage else { return [] }

    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    try handler.perform([request])
    var unique: [String] = []
    for value in (request.results ?? []).compactMap({ $0.topCandidates(1).first?.string }) {
        if !unique.contains(value) {
            unique.append(value)
        }
    }
    return unique
}
