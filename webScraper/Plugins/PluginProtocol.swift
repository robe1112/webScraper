//
//  PluginProtocol.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import SwiftUI

/// Protocol that all plugins must implement
/// Enables modular feature packs (Analysis Pack, Intelligence Pack)
protocol PluginProtocol: AnyObject {
    
    // MARK: - Identity
    
    /// Unique identifier for the plugin
    static var identifier: String { get }
    
    /// Human-readable name
    static var name: String { get }
    
    /// Version string
    static var version: String { get }
    
    /// Description of what the plugin provides
    static var description: String { get }
    
    /// Plugin dependencies (other plugin identifiers required)
    static var dependencies: [String] { get }
    
    // MARK: - State
    
    /// Whether the plugin is currently enabled
    var isEnabled: Bool { get }
    
    /// Current status of the plugin
    var status: PluginStatus { get }
    
    // MARK: - Lifecycle
    
    /// Called when the plugin is activated
    func activate() async throws
    
    /// Called when the plugin is deactivated
    func deactivate() async throws
    
    /// Called when the application launches (if plugin was previously enabled)
    func initialize() async throws
    
    /// Called before the application terminates
    func cleanup() async throws
    
    // MARK: - UI Extension Points
    
    /// Toolbar items to add to the main window
    func toolbarItems() -> [PluginToolbarItem]
    
    /// Sidebar sections to add
    func sidebarSections() -> [PluginSidebarSection]
    
    /// Context menu items for a selection
    func contextMenuItems(for context: PluginContext) -> [PluginMenuItem]
    
    /// Settings view for plugin configuration
    func settingsView() -> AnyView?
    
    /// Main content view provided by the plugin
    func contentView(for context: PluginContext) -> AnyView?
    
    // MARK: - Processing Extension Points
    
    /// Process a downloaded file (e.g., OCR, metadata extraction)
    func processFile(_ file: DownloadedFile) async throws -> ProcessedFileResult?
    
    /// Enrich metadata for a file
    func enrichMetadata(_ metadata: BasicFileMetadata, for file: DownloadedFile) async throws -> EnrichedMetadata?
    
    /// Process scraped page content
    func processPage(_ page: ScrapedPage) async throws -> ProcessedPageResult?
}

// MARK: - Default Implementations

extension PluginProtocol {
    static var dependencies: [String] { [] }
    
    func toolbarItems() -> [PluginToolbarItem] { [] }
    func sidebarSections() -> [PluginSidebarSection] { [] }
    func contextMenuItems(for context: PluginContext) -> [PluginMenuItem] { [] }
    func settingsView() -> AnyView? { nil }
    func contentView(for context: PluginContext) -> AnyView? { nil }
    
    func processFile(_ file: DownloadedFile) async throws -> ProcessedFileResult? { nil }
    func enrichMetadata(_ metadata: BasicFileMetadata, for file: DownloadedFile) async throws -> EnrichedMetadata? { nil }
    func processPage(_ page: ScrapedPage) async throws -> ProcessedPageResult? { nil }
    
    func initialize() async throws {}
    func cleanup() async throws {}
}

// MARK: - Plugin Status

enum PluginStatus: String {
    case inactive = "Inactive"
    case activating = "Activating"
    case active = "Active"
    case deactivating = "Deactivating"
    case error = "Error"
    
    var icon: String {
        switch self {
        case .inactive: return "circle"
        case .activating: return "circle.dashed"
        case .active: return "checkmark.circle.fill"
        case .deactivating: return "circle.dashed"
        case .error: return "exclamationmark.circle.fill"
        }
    }
}

// MARK: - Plugin Context

/// Context passed to plugins for UI and processing
struct PluginContext {
    let selectedProject: Project?
    let selectedJob: ScrapeJob?
    let selectedFiles: [DownloadedFile]
    let selectedPages: [ScrapedPage]
    let featureFlags: FeatureFlags
    
    init(
        selectedProject: Project? = nil,
        selectedJob: ScrapeJob? = nil,
        selectedFiles: [DownloadedFile] = [],
        selectedPages: [ScrapedPage] = [],
        featureFlags: FeatureFlags = FeatureFlags()
    ) {
        self.selectedProject = selectedProject
        self.selectedJob = selectedJob
        self.selectedFiles = selectedFiles
        self.selectedPages = selectedPages
        self.featureFlags = featureFlags
    }
}

// MARK: - UI Extension Types

struct PluginToolbarItem: Identifiable {
    let id: String
    let title: String
    let icon: String
    let action: () -> Void
    var isEnabled: Bool = true
    var badge: String? = nil
}

struct PluginSidebarSection: Identifiable {
    let id: String
    let title: String
    let icon: String
    let items: [PluginSidebarItem]
    var isExpanded: Bool = true
}

struct PluginSidebarItem: Identifiable {
    let id: String
    let title: String
    let icon: String
    let badge: String?
    let action: () -> Void
}

struct PluginMenuItem: Identifiable {
    let id: String
    let title: String
    let icon: String?
    let shortcut: KeyboardShortcut?
    let action: () -> Void
    var isEnabled: Bool = true
    var isDestructive: Bool = false
}

// MARK: - Processing Results

struct ProcessedFileResult {
    let fileId: UUID
    let extractedText: String?
    let summary: String?
    let additionalMetadata: [String: Any]
    let processingTime: TimeInterval
    let success: Bool
    let errorMessage: String?
}

struct ProcessedPageResult {
    let pageId: UUID
    let entities: [ExtractedEntity]
    let summary: String?
    let additionalData: [String: Any]
    let processingTime: TimeInterval
    let success: Bool
    let errorMessage: String?
}

struct ExtractedEntity: Identifiable, Codable {
    let id: UUID
    let type: EntityType
    let value: String
    let confidence: Double
    let sourceRange: Range<Int>?
    let metadata: [String: String]
    
    init(
        id: UUID = UUID(),
        type: EntityType,
        value: String,
        confidence: Double = 1.0,
        sourceRange: Range<Int>? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.type = type
        self.value = value
        self.confidence = confidence
        self.sourceRange = sourceRange
        self.metadata = metadata
    }
}

enum EntityType: String, Codable, CaseIterable {
    case person = "Person"
    case organization = "Organization"
    case location = "Location"
    case date = "Date"
    case time = "Time"
    case money = "Money"
    case email = "Email"
    case phone = "Phone"
    case url = "URL"
    case custom = "Custom"
}

struct EnrichedMetadata: Codable {
    // Extended EXIF for images
    var exifData: [String: String]?
    
    // Extended PDF metadata
    var pdfMetadata: PDFEnrichedMetadata?
    
    // Audio metadata
    var audioMetadata: AudioEnrichedMetadata?
    
    // Video metadata
    var videoMetadata: VideoEnrichedMetadata?
    
    // AI-generated
    var summary: String?
    var keywords: [String]?
    var entities: [ExtractedEntity]?
    var sentiment: Double?
    var language: String?
}

struct PDFEnrichedMetadata: Codable {
    var title: String?
    var author: String?
    var subject: String?
    var keywords: [String]?
    var creator: String?
    var producer: String?
    var creationDate: Date?
    var modificationDate: Date?
    var pageCount: Int?
    var isEncrypted: Bool?
    var hasSignature: Bool?
    var extractedText: String?
}

struct AudioEnrichedMetadata: Codable {
    var title: String?
    var artist: String?
    var album: String?
    var year: Int?
    var genre: String?
    var duration: TimeInterval?
    var bitrate: Int?
    var sampleRate: Int?
    var channels: Int?
    var codec: String?
}

struct VideoEnrichedMetadata: Codable {
    var title: String?
    var duration: TimeInterval?
    var width: Int?
    var height: Int?
    var frameRate: Double?
    var bitrate: Int?
    var codec: String?
    var audioCodec: String?
    var hasAudio: Bool?
}
