//
//  GlobalSettings.swift
//  webScraper
//
//  Created by Rob Evans on 2/1/26.
//

import SwiftUI
import Combine

/// Global application settings that persist across sessions
/// These are app-wide defaults; per-project settings override these
@MainActor
final class GlobalSettings: ObservableObject {
    
    // MARK: - Scraping Defaults
    
    @Published var defaultUserAgent: String = "WebScraperBot/1.0" {
        didSet { UserDefaults.standard.set(defaultUserAgent, forKey: Keys.userAgent) }
    }
    
    @Published var defaultRespectRobotsTxt: Bool = true {
        didSet { UserDefaults.standard.set(defaultRespectRobotsTxt, forKey: Keys.respectRobots) }
    }
    
    @Published var defaultEnableJavaScript: Bool = true {
        didSet { UserDefaults.standard.set(defaultEnableJavaScript, forKey: Keys.enableJS) }
    }
    
    @Published var defaultRequestDelayMs: Int = 1000 {
        didSet { UserDefaults.standard.set(defaultRequestDelayMs, forKey: Keys.requestDelay) }
    }
    
    @Published var defaultMaxConcurrentRequests: Int = 4 {
        didSet { UserDefaults.standard.set(defaultMaxConcurrentRequests, forKey: Keys.maxConcurrent) }
    }
    
    // MARK: - Download Defaults
    
    @Published var downloadLocation: URL = GlobalSettings.defaultDownloadLocation {
        didSet { UserDefaults.standard.set(downloadLocation.path, forKey: Keys.downloadPath) }
    }
    
    @Published var defaultDownloadImages: Bool = true {
        didSet { UserDefaults.standard.set(defaultDownloadImages, forKey: Keys.downloadImages) }
    }
    
    @Published var defaultDownloadPDFs: Bool = true {
        didSet { UserDefaults.standard.set(defaultDownloadPDFs, forKey: Keys.downloadPDFs) }
    }
    
    @Published var defaultDownloadDocuments: Bool = true {
        didSet { UserDefaults.standard.set(defaultDownloadDocuments, forKey: Keys.downloadDocs) }
    }
    
    @Published var defaultDownloadAudio: Bool = false {
        didSet { UserDefaults.standard.set(defaultDownloadAudio, forKey: Keys.downloadAudio) }
    }
    
    @Published var defaultDownloadVideo: Bool = false {
        didSet { UserDefaults.standard.set(defaultDownloadVideo, forKey: Keys.downloadVideo) }
    }
    
    // MARK: - Storage Default
    
    @Published var defaultStorageType: StorageType = .coreData {
        didSet { UserDefaults.standard.set(defaultStorageType.rawValue, forKey: Keys.storageType) }
    }
    
    // MARK: - Initialization
    
    init() {
        // Load is called from AppState after init
    }
    
    func loadFromDefaults() {
        let defaults = UserDefaults.standard
        
        defaultUserAgent = defaults.string(forKey: Keys.userAgent) ?? "WebScraperBot/1.0"
        defaultRespectRobotsTxt = defaults.object(forKey: Keys.respectRobots) as? Bool ?? true
        defaultEnableJavaScript = defaults.object(forKey: Keys.enableJS) as? Bool ?? true
        defaultRequestDelayMs = defaults.object(forKey: Keys.requestDelay) as? Int ?? 1000
        defaultMaxConcurrentRequests = defaults.object(forKey: Keys.maxConcurrent) as? Int ?? 4
        
        if let path = defaults.string(forKey: Keys.downloadPath) {
            downloadLocation = URL(fileURLWithPath: path)
        } else {
            downloadLocation = GlobalSettings.defaultDownloadLocation
        }
        
        defaultDownloadImages = defaults.object(forKey: Keys.downloadImages) as? Bool ?? true
        defaultDownloadPDFs = defaults.object(forKey: Keys.downloadPDFs) as? Bool ?? true
        defaultDownloadDocuments = defaults.object(forKey: Keys.downloadDocs) as? Bool ?? true
        defaultDownloadAudio = defaults.object(forKey: Keys.downloadAudio) as? Bool ?? false
        defaultDownloadVideo = defaults.object(forKey: Keys.downloadVideo) as? Bool ?? false
        
        if let storageRaw = defaults.string(forKey: Keys.storageType),
           let storage = StorageType(rawValue: storageRaw) {
            defaultStorageType = storage
        }
    }
    
    // MARK: - Reset
    
    func resetToDefaults() {
        defaultUserAgent = "WebScraperBot/1.0"
        defaultRespectRobotsTxt = true
        defaultEnableJavaScript = true
        defaultRequestDelayMs = 1000
        defaultMaxConcurrentRequests = 4
        downloadLocation = GlobalSettings.defaultDownloadLocation
        defaultDownloadImages = true
        defaultDownloadPDFs = true
        defaultDownloadDocuments = true
        defaultDownloadAudio = false
        defaultDownloadVideo = false
        defaultStorageType = .coreData
    }
    
    // MARK: - Keys
    
    private enum Keys {
        static let userAgent = "globalSettings.userAgent"
        static let respectRobots = "globalSettings.respectRobots"
        static let enableJS = "globalSettings.enableJS"
        static let requestDelay = "globalSettings.requestDelay"
        static let maxConcurrent = "globalSettings.maxConcurrent"
        static let downloadPath = "globalSettings.downloadPath"
        static let downloadImages = "globalSettings.downloadImages"
        static let downloadPDFs = "globalSettings.downloadPDFs"
        static let downloadDocs = "globalSettings.downloadDocs"
        static let downloadAudio = "globalSettings.downloadAudio"
        static let downloadVideo = "globalSettings.downloadVideo"
        static let storageType = "globalSettings.storageType"
    }
    
    // MARK: - Static
    
    static var defaultDownloadLocation: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("webScraper")
            .appendingPathComponent("Downloads")
    }
}
