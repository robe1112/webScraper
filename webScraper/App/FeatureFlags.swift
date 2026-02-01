//
//  FeatureFlags.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import SwiftUI
import Combine

/// Manages feature flags for optional packs and experimental features
/// Enables modular architecture where users only pay for features they need
final class FeatureFlags: ObservableObject {
    
    // MARK: - Pack Enablement
    
    /// Analysis Pack: OCR, search, viewers, AI summarization
    @Published var analysisPackEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(analysisPackEnabled, forKey: Keys.analysisPack)
        }
    }
    
    /// Intelligence Pack: RAG, knowledge graphs, entity extraction
    @Published var intelligencePackEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(intelligencePackEnabled, forKey: Keys.intelligencePack)
        }
    }
    
    // MARK: - Computed Convenience Properties
    
    // Analysis Pack features
    var canOCR: Bool { analysisPackEnabled }
    var canSearch: Bool { analysisPackEnabled }
    var canSemanticSearch: Bool { analysisPackEnabled }
    var canSummarize: Bool { analysisPackEnabled }
    var canViewDocuments: Bool { analysisPackEnabled }
    var canPlayMedia: Bool { analysisPackEnabled }
    var canExtractAdvancedMetadata: Bool { analysisPackEnabled }
    var canPerceptualHash: Bool { analysisPackEnabled }
    
    // Intelligence Pack features (requires Analysis Pack)
    var canExtractEntities: Bool { intelligencePackEnabled && analysisPackEnabled }
    var canBuildKnowledgeGraph: Bool { intelligencePackEnabled && analysisPackEnabled }
    var canRAGChat: Bool { intelligencePackEnabled && analysisPackEnabled }
    var canDiscoverRelationships: Bool { intelligencePackEnabled && analysisPackEnabled }
    var canDetectAnomalies: Bool { intelligencePackEnabled && analysisPackEnabled }
    var canClusterDocuments: Bool { intelligencePackEnabled && analysisPackEnabled }
    var canCompareDocuments: Bool { intelligencePackEnabled && analysisPackEnabled }
    var canBuildTimeline: Bool { intelligencePackEnabled && analysisPackEnabled }
    
    // MARK: - Experimental Features
    
    @Published var experimentalFeaturesEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(experimentalFeaturesEnabled, forKey: Keys.experimental)
        }
    }
    
    // MARK: - AI Configuration
    
    @Published var localLLMEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(localLLMEnabled, forKey: Keys.localLLM)
        }
    }
    
    @Published var cloudLLMEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(cloudLLMEnabled, forKey: Keys.cloudLLM)
        }
    }
    
    @Published var preferLocalModels: Bool = true {
        didSet {
            UserDefaults.standard.set(preferLocalModels, forKey: Keys.preferLocal)
        }
    }
    
    // MARK: - Memory Management
    
    @Published var maxMemoryUsageMB: Int = 8192 {
        didSet {
            UserDefaults.standard.set(maxMemoryUsageMB, forKey: Keys.maxMemory)
        }
    }
    
    @Published var enableTieredProcessing: Bool = true {
        didSet {
            UserDefaults.standard.set(enableTieredProcessing, forKey: Keys.tieredProcessing)
        }
    }
    
    // MARK: - Initialization
    
    init() {
        loadFromDefaults()
    }
    
    // MARK: - Private
    
    private enum Keys {
        static let analysisPack = "featureFlags.analysisPack"
        static let intelligencePack = "featureFlags.intelligencePack"
        static let experimental = "featureFlags.experimental"
        static let localLLM = "featureFlags.localLLM"
        static let cloudLLM = "featureFlags.cloudLLM"
        static let preferLocal = "featureFlags.preferLocal"
        static let maxMemory = "featureFlags.maxMemory"
        static let tieredProcessing = "featureFlags.tieredProcessing"
    }
    
    private func loadFromDefaults() {
        let defaults = UserDefaults.standard
        
        analysisPackEnabled = defaults.bool(forKey: Keys.analysisPack)
        intelligencePackEnabled = defaults.bool(forKey: Keys.intelligencePack)
        experimentalFeaturesEnabled = defaults.bool(forKey: Keys.experimental)
        localLLMEnabled = defaults.object(forKey: Keys.localLLM) as? Bool ?? true
        cloudLLMEnabled = defaults.bool(forKey: Keys.cloudLLM)
        preferLocalModels = defaults.object(forKey: Keys.preferLocal) as? Bool ?? true
        maxMemoryUsageMB = defaults.object(forKey: Keys.maxMemory) as? Int ?? 8192
        enableTieredProcessing = defaults.object(forKey: Keys.tieredProcessing) as? Bool ?? true
    }
    
    // MARK: - Public Methods
    
    /// Reset all flags to defaults
    func resetToDefaults() {
        analysisPackEnabled = false
        intelligencePackEnabled = false
        experimentalFeaturesEnabled = false
        localLLMEnabled = true
        cloudLLMEnabled = false
        preferLocalModels = true
        maxMemoryUsageMB = 8192
        enableTieredProcessing = true
    }
    
    /// Enable Analysis Pack (validates prerequisites)
    func enableAnalysisPack() {
        analysisPackEnabled = true
    }
    
    /// Enable Intelligence Pack (validates prerequisites)
    func enableIntelligencePack() {
        // Intelligence Pack requires Analysis Pack
        if !analysisPackEnabled {
            analysisPackEnabled = true
        }
        intelligencePackEnabled = true
    }
    
    /// Disable Intelligence Pack
    func disableIntelligencePack() {
        intelligencePackEnabled = false
    }
    
    /// Disable Analysis Pack (also disables Intelligence Pack)
    func disableAnalysisPack() {
        intelligencePackEnabled = false
        analysisPackEnabled = false
    }
    
    /// Get recommended memory limit based on system
    static func recommendedMemoryLimit() -> Int {
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let memoryGB = Int(physicalMemory / 1_073_741_824) // Convert to GB
        
        // Recommend using at most 50% of system memory
        let recommendedGB = max(4, memoryGB / 2)
        return recommendedGB * 1024 // Return in MB
    }
}
