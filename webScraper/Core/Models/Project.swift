//
//  Project.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import Foundation

/// Represents a web scraping project
/// A project contains configuration, jobs, and downloaded content
struct Project: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var startURL: String
    let createdAt: Date
    var updatedAt: Date?
    var settings: ProjectSettings
    var tags: [String]
    var notes: String
    
    // Statistics (updated after each scrape)
    var totalPagesScraped: Int
    var totalFilesDownloaded: Int
    var totalSizeBytes: Int64
    var lastScrapedAt: Date?
    
    init(
        id: UUID = UUID(),
        name: String,
        startURL: String,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        settings: ProjectSettings = ProjectSettings(),
        tags: [String] = [],
        notes: String = "",
        totalPagesScraped: Int = 0,
        totalFilesDownloaded: Int = 0,
        totalSizeBytes: Int64 = 0,
        lastScrapedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.startURL = startURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.settings = settings
        self.tags = tags
        self.notes = notes
        self.totalPagesScraped = totalPagesScraped
        self.totalFilesDownloaded = totalFilesDownloaded
        self.totalSizeBytes = totalSizeBytes
        self.lastScrapedAt = lastScrapedAt
    }
}

/// Project-level settings
struct ProjectSettings: Codable, Hashable {
    // Storage preference
    var storageType: StorageType
    
    // Crawl settings
    var maxDepth: Int
    var maxPages: Int
    var followExternalLinks: Bool
    var respectRobotsTxt: Bool
    
    // Rate limiting
    var requestDelayMs: Int
    var maxConcurrentRequests: Int
    
    // Content settings
    var enableJavaScript: Bool
    var customUserAgent: String?
    var customHeaders: [String: String]
    
    // Download settings
    var downloadImages: Bool
    var downloadPDFs: Bool
    var downloadDocuments: Bool
    var downloadMedia: Bool
    var maxFileSizeMB: Int
    
    // Filter settings
    var urlWhitelist: [String]
    var urlBlacklist: [String]
    var fileTypeFilter: [String]
    
    init(
        storageType: StorageType = .coreData,
        maxDepth: Int = 5,
        maxPages: Int = 1000,
        followExternalLinks: Bool = false,
        respectRobotsTxt: Bool = true,
        requestDelayMs: Int = 1000,
        maxConcurrentRequests: Int = 4,
        enableJavaScript: Bool = true,
        customUserAgent: String? = nil,
        customHeaders: [String: String] = [:],
        downloadImages: Bool = true,
        downloadPDFs: Bool = true,
        downloadDocuments: Bool = true,
        downloadMedia: Bool = false,
        maxFileSizeMB: Int = 500,
        urlWhitelist: [String] = [],
        urlBlacklist: [String] = [],
        fileTypeFilter: [String] = []
    ) {
        self.storageType = storageType
        self.maxDepth = maxDepth
        self.maxPages = maxPages
        self.followExternalLinks = followExternalLinks
        self.respectRobotsTxt = respectRobotsTxt
        self.requestDelayMs = requestDelayMs
        self.maxConcurrentRequests = maxConcurrentRequests
        self.enableJavaScript = enableJavaScript
        self.customUserAgent = customUserAgent
        self.customHeaders = customHeaders
        self.downloadImages = downloadImages
        self.downloadPDFs = downloadPDFs
        self.downloadDocuments = downloadDocuments
        self.downloadMedia = downloadMedia
        self.maxFileSizeMB = maxFileSizeMB
        self.urlWhitelist = urlWhitelist
        self.urlBlacklist = urlBlacklist
        self.fileTypeFilter = fileTypeFilter
    }
}

/// Storage type preference for project data
enum StorageType: String, Codable, CaseIterable {
    case coreData = "Core Data"
    case sqlite = "SQLite"
    case file = "File-based"
    
    var description: String {
        switch self {
        case .coreData:
            return "Apple's Core Data framework - best for complex queries"
        case .sqlite:
            return "Direct SQLite - lightweight and portable"
        case .file:
            return "JSON/Plist files - simple and human-readable"
        }
    }
}
