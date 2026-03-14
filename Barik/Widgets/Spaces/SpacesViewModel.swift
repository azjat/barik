import AppKit
import Combine
import Foundation

class SpacesViewModel: ObservableObject {
    @Published var spaces: [AnySpace] = []
    private var timer: Timer?
    private var provider: AnySpacesProvider?
    private var isLoading = false

    init() {
        let runningApps = NSWorkspace.shared.runningApplications.compactMap {
            $0.localizedName?.lowercased()
        }
        if runningApps.contains("aerospace") {
            provider = AnySpacesProvider(AerospaceSpacesProvider())
        } else {
            provider = nil
        }
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) {
            [weak self] _ in
            self?.loadSpaces()
        }
        loadSpaces()
    }

    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func loadSpaces() {
        guard !isLoading else { return }
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self,
                let provider = self.provider,
                let spaces = provider.getSpacesWithWindows()
            else {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.isLoading = false
                    guard !self.spaces.isEmpty else { return }
                    self.spaces = []
                }
                return
            }
            let sortedSpaces = spaces.sorted { $0.id < $1.id }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isLoading = false
                guard self.spaces != sortedSpaces else { return }
                self.spaces = sortedSpaces
            }
        }
    }

    func switchToSpace(_ space: AnySpace, needWindowFocus: Bool = false) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.provider?.focusSpace(
                spaceId: space.id, needWindowFocus: needWindowFocus)
        }
    }

    func switchToWindow(_ window: AnyWindow) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.provider?.focusWindow(windowId: String(window.id))
        }
    }
}

class IconCache {
    static let shared = IconCache()
    private let cache = NSCache<NSString, NSImage>()
    private var bundleURLCache: [String: URL] = [:]
    private var lastBundleURLRefresh: Date = .distantPast

    private init() {}

    func icon(for appName: String) -> NSImage? {
        if let cached = cache.object(forKey: appName as NSString) {
            return cached
        }
        let workspace = NSWorkspace.shared
        if let bundleURL = resolvedBundleURL(for: appName) {
            let icon = workspace.icon(forFile: bundleURL.path)
            cache.setObject(icon, forKey: appName as NSString)
            return icon
        }
        return nil
    }

    private func resolvedBundleURL(for appName: String) -> URL? {
        if let url = bundleURLCache[appName] {
            return url
        }
        refreshBundleURLCacheIfNeeded()
        return bundleURLCache[appName]
    }

    private func refreshBundleURLCacheIfNeeded() {
        let now = Date()
        guard now.timeIntervalSince(lastBundleURLRefresh) > 2.0 else { return }
        lastBundleURLRefresh = now
        var newCache: [String: URL] = [:]
        for app in NSWorkspace.shared.runningApplications {
            if let name = app.localizedName, let url = app.bundleURL {
                newCache[name] = url
            }
        }
        bundleURLCache = newCache
    }
}
