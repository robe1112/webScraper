//
//  AppState.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import SwiftUI
import Combine

/// Central application state manager
/// Coordinates between all components and manages global state
@MainActor
final class AppState: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Currently selected project
    @Published var selectedProject: Project?
    
    /// Currently selected scrape job
    @Published var selectedJob: ScrapeJob?
    
    /// Global loading state
    @Published var isLoading: Bool = false
    
    /// Global error state
    @Published var currentError: AppError?
    
    /// Navigation state
    @Published var selectedSidebarItem: SidebarItem = .projects
    
    /// Active downloads count
    @Published var activeDownloads: Int = 0
    
    /// Active scrape jobs count
    @Published var activeJobs: Int = 0
    
    // MARK: - Dependencies
    
    /// Feature flags for optional packs
    let featureFlags: FeatureFlags
    
    /// Plugin manager for optional feature packs
    let pluginManager: PluginManager
    
    /// Storage provider
    private(set) var storageProvider: StorageProvider
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        featureFlags: FeatureFlags? = nil,
        storageProvider: StorageProvider? = nil
    ) {
        // Create defaults in init body (main actor) to avoid isolation issues with default params
        self.featureFlags = featureFlags ?? FeatureFlags()
        self.pluginManager = PluginManager(featureFlags: self.featureFlags)
        self.storageProvider = storageProvider ?? CoreDataStorage()
        
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    /// Switch storage provider (per-project flexibility)
    func switchStorageProvider(to provider: StorageProvider) {
        self.storageProvider = provider
    }
    
    /// Load all projects
    func loadProjects() async throws -> [Project] {
        isLoading = true
        defer { isLoading = false }
        
        return try await storageProvider.fetch(predicate: nil)
    }
    
    /// Create a new project
    func createProject(name: String, url: String) async throws -> Project {
        let project = Project(
            id: UUID(),
            name: name,
            startURL: url,
            createdAt: Date(),
            settings: ProjectSettings()
        )
        
        try await storageProvider.save(project)
        selectedProject = project
        
        return project
    }
    
    /// Delete a project
    func deleteProject(_ project: Project) async throws {
        try await storageProvider.delete(project)
        if selectedProject?.id == project.id {
            selectedProject = nil
        }
    }
    
    /// Show error to user
    func showError(_ error: AppError) {
        currentError = error
    }
    
    /// Dismiss current error
    func dismissError() {
        currentError = nil
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Observe feature flag changes
        featureFlags.$analysisPackEnabled
            .sink { [weak self] enabled in
                if enabled {
                    self?.pluginManager.activatePlugin(identifier: "com.webScraper.analysisPack")
                } else {
                    self?.pluginManager.deactivatePlugin(identifier: "com.webScraper.analysisPack")
                }
            }
            .store(in: &cancellables)
        
        featureFlags.$intelligencePackEnabled
            .sink { [weak self] enabled in
                if enabled {
                    self?.pluginManager.activatePlugin(identifier: "com.webScraper.intelligencePack")
                } else {
                    self?.pluginManager.deactivatePlugin(identifier: "com.webScraper.intelligencePack")
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Supporting Types

enum SidebarItem: String, CaseIterable, Identifiable {
    case projects = "Projects"
    case activeJobs = "Active Jobs"
    case downloads = "Downloads"
    case siteMap = "Site Map"
    case diff = "Changes"
    case schedule = "Schedule"
    case settings = "Settings"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .projects: return "folder"
        case .activeJobs: return "play.circle"
        case .downloads: return "arrow.down.circle"
        case .siteMap: return "map"
        case .diff: return "doc.badge.clock"
        case .schedule: return "calendar"
        case .settings: return "gear"
        }
    }
}

struct AppError: Identifiable, Error {
    let id = UUID()
    let title: String
    let message: String
    let underlyingError: Error?
    
    init(title: String, message: String, underlyingError: Error? = nil) {
        self.title = title
        self.message = message
        self.underlyingError = underlyingError
    }
}
