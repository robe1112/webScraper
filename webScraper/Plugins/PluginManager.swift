//
//  PluginManager.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import SwiftUI
import Combine

/// Manages plugin lifecycle, registration, and coordination
@MainActor
final class PluginManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var registeredPlugins: [String: any PluginProtocol] = [:]
    @Published private(set) var activePlugins: [String: any PluginProtocol] = [:]
    @Published private(set) var pluginErrors: [String: Error] = [:]
    
    // MARK: - Dependencies
    
    private let featureFlags: FeatureFlags
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(featureFlags: FeatureFlags) {
        self.featureFlags = featureFlags
        setupBindings()
    }
    
    // MARK: - Plugin Registration
    
    /// Register a plugin with the manager
    func register<P: PluginProtocol>(_ plugin: P) {
        let identifier = type(of: plugin).identifier
        registeredPlugins[identifier] = plugin
    }
    
    /// Unregister a plugin
    func unregister(identifier: String) {
        if activePlugins[identifier] != nil {
            Task { @MainActor in
                deactivatePlugin(identifier: identifier)
            }
        }
        registeredPlugins.removeValue(forKey: identifier)
    }
    
    // MARK: - Plugin Activation
    
    /// Activate a plugin by identifier
    func activatePlugin(identifier: String) {
        guard let plugin = registeredPlugins[identifier] else {
            pluginErrors[identifier] = PluginError.notFound
            return
        }
        
        // Check dependencies
        let dependencies = type(of: plugin).dependencies
        for dependency in dependencies {
            if activePlugins[dependency] == nil {
                pluginErrors[identifier] = PluginError.dependencyNotActive(dependency)
                return
            }
        }
        
        Task {
            do {
                try await plugin.activate()
                activePlugins[identifier] = plugin
                pluginErrors.removeValue(forKey: identifier)
            } catch {
                pluginErrors[identifier] = error
            }
        }
    }
    
    /// Deactivate a plugin by identifier
    func deactivatePlugin(identifier: String) {
        guard let plugin = activePlugins[identifier] else { return }
        
        // Check if other plugins depend on this one
        let dependents = activePlugins.filter { (_, p) in
            type(of: p).dependencies.contains(identifier)
        }
        
        // Deactivate dependents first
        for (dependentId, _) in dependents {
            deactivatePlugin(identifier: dependentId)
        }
        
        Task {
            do {
                try await plugin.deactivate()
                activePlugins.removeValue(forKey: identifier)
            } catch {
                pluginErrors[identifier] = error
            }
        }
    }
    
    // MARK: - Plugin Access
    
    /// Get an active plugin by identifier
    func plugin(identifier: String) -> (any PluginProtocol)? {
        activePlugins[identifier]
    }
    
    /// Get all active plugins
    func allActivePlugins() -> [any PluginProtocol] {
        Array(activePlugins.values)
    }
    
    /// Check if a plugin is active
    func isActive(identifier: String) -> Bool {
        activePlugins[identifier] != nil
    }
    
    // MARK: - UI Aggregation
    
    /// Get all toolbar items from active plugins
    func aggregateToolbarItems() -> [PluginToolbarItem] {
        activePlugins.values.flatMap { $0.toolbarItems() }
    }
    
    /// Get all sidebar sections from active plugins
    func aggregateSidebarSections() -> [PluginSidebarSection] {
        activePlugins.values.flatMap { $0.sidebarSections() }
    }
    
    /// Get all context menu items from active plugins
    func aggregateContextMenuItems(for context: PluginContext) -> [PluginMenuItem] {
        activePlugins.values.flatMap { $0.contextMenuItems(for: context) }
    }
    
    // MARK: - Processing Coordination
    
    /// Process a file through all active plugins
    func processFile(_ file: DownloadedFile) async -> [ProcessedFileResult] {
        var results: [ProcessedFileResult] = []
        
        for plugin in activePlugins.values {
            do {
                if let result = try await plugin.processFile(file) {
                    results.append(result)
                }
            } catch {
                // Log error but continue with other plugins
                print("Plugin error processing file: \(error)")
            }
        }
        
        return results
    }
    
    /// Enrich metadata through all active plugins
    func enrichMetadata(_ metadata: BasicFileMetadata, for file: DownloadedFile) async -> EnrichedMetadata? {
        var enriched: EnrichedMetadata?
        
        for plugin in activePlugins.values {
            do {
                if let result = try await plugin.enrichMetadata(metadata, for: file) {
                    // Merge results
                    if enriched == nil {
                        enriched = result
                    } else {
                        // Merge fields (later plugins override earlier ones) - copy to avoid overlapping access
                        var merged = enriched!
                        merged.summary = result.summary ?? merged.summary
                        merged.keywords = result.keywords ?? merged.keywords
                        merged.entities = result.entities ?? merged.entities
                        merged.exifData = result.exifData ?? merged.exifData
                        merged.pdfMetadata = result.pdfMetadata ?? merged.pdfMetadata
                        merged.audioMetadata = result.audioMetadata ?? merged.audioMetadata
                        merged.videoMetadata = result.videoMetadata ?? merged.videoMetadata
                        enriched = merged
                    }
                }
            } catch {
                print("Plugin error enriching metadata: \(error)")
            }
        }
        
        return enriched
    }
    
    /// Process a page through all active plugins
    func processPage(_ page: ScrapedPage) async -> [ProcessedPageResult] {
        var results: [ProcessedPageResult] = []
        
        for plugin in activePlugins.values {
            do {
                if let result = try await plugin.processPage(page) {
                    results.append(result)
                }
            } catch {
                print("Plugin error processing page: \(error)")
            }
        }
        
        return results
    }
    
    // MARK: - Lifecycle
    
    /// Initialize all enabled plugins on app launch
    func initializePlugins() async {
        for (identifier, plugin) in registeredPlugins {
            // Check feature flags to determine if plugin should be active
            let shouldActivate: Bool
            switch identifier {
            case "com.webScraper.analysisPack":
                shouldActivate = featureFlags.analysisPackEnabled
            case "com.webScraper.intelligencePack":
                shouldActivate = featureFlags.intelligencePackEnabled
            default:
                shouldActivate = false
            }
            
            if shouldActivate {
                do {
                    try await plugin.initialize()
                    try await plugin.activate()
                    activePlugins[identifier] = plugin
                } catch {
                    pluginErrors[identifier] = error
                }
            }
        }
    }
    
    /// Cleanup all plugins before app termination
    func cleanupPlugins() async {
        for (identifier, plugin) in activePlugins {
            do {
                try await plugin.cleanup()
                try await plugin.deactivate()
            } catch {
                pluginErrors[identifier] = error
            }
        }
        activePlugins.removeAll()
    }
    
    // MARK: - Private
    
    private func setupBindings() {
        // React to feature flag changes
        featureFlags.$analysisPackEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                if enabled {
                    self?.activatePlugin(identifier: "com.webScraper.analysisPack")
                } else {
                    self?.deactivatePlugin(identifier: "com.webScraper.analysisPack")
                }
            }
            .store(in: &cancellables)
        
        featureFlags.$intelligencePackEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                if enabled {
                    self?.activatePlugin(identifier: "com.webScraper.intelligencePack")
                } else {
                    self?.deactivatePlugin(identifier: "com.webScraper.intelligencePack")
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Plugin Errors

enum PluginError: LocalizedError {
    case notFound
    case dependencyNotActive(String)
    case activationFailed(Error)
    case deactivationFailed(Error)
    case processingFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Plugin not found"
        case .dependencyNotActive(let dep):
            return "Required plugin '\(dep)' is not active"
        case .activationFailed(let error):
            return "Failed to activate plugin: \(error.localizedDescription)"
        case .deactivationFailed(let error):
            return "Failed to deactivate plugin: \(error.localizedDescription)"
        case .processingFailed(let error):
            return "Plugin processing failed: \(error.localizedDescription)"
        }
    }
}
