import AppKit
import Combine
import Foundation
import SummonKit

@MainActor
final class LauncherModel: ObservableObject {
    @Published var query: String = "" {
        didSet {
            if query != oldValue {
                scheduleSearch(debounce: true)
            }
        }
    }
    @Published private(set) var tabs: [LoadedPlugin] = []
    @Published private(set) var selectedTabIndex: Int = 0
    @Published private(set) var candidates: [Candidate] = []
    @Published var selectedCandidateIndex: Int = 0
    @Published private(set) var config: AppConfig = .default

    var onRequestClose: (() -> Void)?

    private var inFlight: Task<Void, Never>?
    private var bundledPluginsDirectory: URL?
    private var userPluginsDirectory: URL
    private var configURL: URL

    init(
        bundledPluginsDirectory: URL? = Bundle.main.resourceURL?.appendingPathComponent("plugins"),
        userPluginsDirectory: URL = ConfigLoader.defaultUserPluginsDirectory,
        configURL: URL = ConfigLoader.defaultConfigURL
    ) {
        self.bundledPluginsDirectory = bundledPluginsDirectory
        self.userPluginsDirectory = userPluginsDirectory
        self.configURL = configURL
        reload()
    }

    var selectedPlugin: LoadedPlugin? {
        guard tabs.indices.contains(selectedTabIndex) else { return nil }
        return tabs[selectedTabIndex]
    }

    var selectedCandidate: Candidate? {
        guard candidates.indices.contains(selectedCandidateIndex) else { return nil }
        return candidates[selectedCandidateIndex]
    }

    var tabModifier: Hotkey.Modifier {
        (try? HotkeyParser.parseModifiers(config.tabModifier)) ?? .command
    }

    var parsedHotkey: Hotkey {
        (try? HotkeyParser.parse(config.hotkey))
            ?? Hotkey(
                modifiers: .command,
                key: Hotkey.Key(name: "d", carbonKeyCode: 0x02)
            )
    }

    func reload() {
        config = ConfigLoader.load(from: configURL)
        let loaded = PluginLoader.load(
            bundledDirectory: bundledPluginsDirectory,
            userDirectory: userPluginsDirectory
        )
        let previousName = selectedPlugin?.manifest.name
        tabs = PluginResolver.tabs(from: loaded, orderedBy: config.tabs)
        if let previousName, let index = tabs.firstIndex(where: { $0.manifest.name == previousName }) {
            selectedTabIndex = index
        } else {
            selectedTabIndex = 0
        }
    }

    func prepareForDisplay() {
        reload()
        selectedCandidateIndex = 0
        if query.isEmpty {
            scheduleSearch(debounce: false)
        } else {
            query = ""
        }
    }

    func selectTab(at index: Int) {
        guard tabs.indices.contains(index), selectedTabIndex != index else { return }
        candidates = []
        selectedCandidateIndex = 0
        selectedTabIndex = index
        scheduleSearch(debounce: false)
    }

    func selectAdjacentTab(delta: Int) {
        guard !tabs.isEmpty else { return }
        let count = tabs.count
        let wrapped = ((selectedTabIndex + delta) % count + count) % count
        selectTab(at: wrapped)
    }

    func moveSelection(offset: Int) {
        guard !candidates.isEmpty else { return }
        let next = selectedCandidateIndex + offset
        selectedCandidateIndex = min(max(next, 0), candidates.count - 1)
    }

    func confirm() {
        guard let plugin = selectedPlugin, let candidate = selectedCandidate else { return }
        inFlight?.cancel()
        inFlight = Task { @MainActor in
            do {
                let status = try await PluginProcess.action(plugin: plugin, candidate: candidate)
                if status == 0 {
                    self.onRequestClose?()
                } else {
                    NSLog("summon: action exited with status %d", status)
                }
            } catch is CancellationError {
                return
            } catch {
                NSLog("summon: action failed: \(error)")
            }
        }
    }

    private func scheduleSearch(debounce: Bool) {
        inFlight?.cancel()
        inFlight = Task { @MainActor in
            if debounce {
                try? await Task.sleep(nanoseconds: 100_000_000)
                guard !Task.isCancelled else { return }
            }
            await self.performSearch()
        }
    }

    private func performSearch() async {
        guard let plugin = selectedPlugin else {
            candidates = []
            selectedCandidateIndex = 0
            return
        }
        let query = self.query
        do {
            let items = try await PluginProcess.search(plugin: plugin, query: query)
            guard !Task.isCancelled else { return }
            candidates = items
            selectedCandidateIndex = items.isEmpty ? 0 : min(selectedCandidateIndex, items.count - 1)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            NSLog("summon: search failed: \(error)")
            candidates = []
            selectedCandidateIndex = 0
        }
    }
}
