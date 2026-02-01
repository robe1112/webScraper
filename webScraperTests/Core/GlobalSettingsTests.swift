//
//  GlobalSettingsTests.swift
//  webScraperTests
//
//  Unit tests for GlobalSettings - verify persistence and defaults
//  Follows Arrange-Act-Assert pattern per .cursor/rules
//

import Testing
import Foundation
@testable import webScraper

@Suite("GlobalSettings Tests")
struct GlobalSettingsTests {

    @MainActor
    @Test("Default values are sensible")
    func defaultValues() throws {
        // Arrange
        let settings = GlobalSettings()

        // Assert - verify defaults without loading from UserDefaults
        #expect(settings.defaultUserAgent == "WebScraperBot/1.0")
        #expect(settings.defaultRespectRobotsTxt == true)
        #expect(settings.defaultEnableJavaScript == true)
        #expect(settings.defaultRequestDelayMs == 1000)
        #expect(settings.defaultMaxConcurrentRequests == 4)
        #expect(settings.defaultDownloadImages == true)
        #expect(settings.defaultDownloadPDFs == true)
        #expect(settings.defaultDownloadDocuments == true)
        #expect(settings.defaultDownloadAudio == false)
        #expect(settings.defaultDownloadVideo == false)
        #expect(settings.defaultStorageType == .coreData)
    }

    @MainActor
    @Test("Reset restores default values")
    func resetToDefaults() throws {
        // Arrange
        let settings = GlobalSettings()
        settings.defaultUserAgent = "CustomAgent/2.0"
        settings.defaultRespectRobotsTxt = false
        settings.defaultEnableJavaScript = false
        settings.defaultRequestDelayMs = 5000
        settings.defaultMaxConcurrentRequests = 10
        settings.defaultDownloadImages = false
        settings.defaultStorageType = .sqlite

        // Act
        settings.resetToDefaults()

        // Assert
        #expect(settings.defaultUserAgent == "WebScraperBot/1.0")
        #expect(settings.defaultRespectRobotsTxt == true)
        #expect(settings.defaultEnableJavaScript == true)
        #expect(settings.defaultRequestDelayMs == 1000)
        #expect(settings.defaultMaxConcurrentRequests == 4)
        #expect(settings.defaultDownloadImages == true)
        #expect(settings.defaultStorageType == .coreData)
    }

    @MainActor
    @Test("Default download location is in Documents")
    func defaultDownloadLocation() throws {
        // Arrange & Act
        let location = GlobalSettings.defaultDownloadLocation

        // Assert
        #expect(location.path.contains("Documents"))
        #expect(location.path.contains("webScraper"))
        #expect(location.path.contains("Downloads"))
    }

    @MainActor
    @Test("Settings can be modified")
    func settingsModifiable() throws {
        // Arrange
        let settings = GlobalSettings()

        // Act
        settings.defaultUserAgent = "TestAgent/1.0"
        settings.defaultRequestDelayMs = 2000
        settings.defaultMaxConcurrentRequests = 8

        // Assert
        #expect(settings.defaultUserAgent == "TestAgent/1.0")
        #expect(settings.defaultRequestDelayMs == 2000)
        #expect(settings.defaultMaxConcurrentRequests == 8)
    }
}

@Suite("FeatureFlags Tests")
struct FeatureFlagsTests {

    @Test("Default feature flags are disabled after reset")
    func defaultFlagsDisabled() throws {
        // Arrange
        let flags = FeatureFlags()
        
        // Act - reset to get clean state (UserDefaults may have persisted values)
        flags.resetToDefaults()

        // Assert - packs should be disabled by default
        #expect(flags.analysisPackEnabled == false)
        #expect(flags.intelligencePackEnabled == false)
        #expect(flags.experimentalFeaturesEnabled == false)
    }

    @Test("Default AI settings favor local models after reset")
    func defaultAISettings() throws {
        // Arrange
        let flags = FeatureFlags()
        
        // Act - reset to get clean state
        flags.resetToDefaults()

        // Assert
        #expect(flags.localLLMEnabled == true)
        #expect(flags.cloudLLMEnabled == false)
        #expect(flags.preferLocalModels == true)
    }

    @Test("Enable Analysis Pack sets flag")
    func enableAnalysisPack() throws {
        // Arrange
        let flags = FeatureFlags()
        flags.resetToDefaults()

        // Act
        flags.enableAnalysisPack()

        // Assert
        #expect(flags.analysisPackEnabled == true)
        #expect(flags.canOCR == true)
        #expect(flags.canSearch == true)
    }

    @Test("Enable Intelligence Pack also enables Analysis Pack")
    func enableIntelligencePackEnablesAnalysis() throws {
        // Arrange
        let flags = FeatureFlags()
        flags.resetToDefaults()
        #expect(flags.analysisPackEnabled == false)

        // Act
        flags.enableIntelligencePack()

        // Assert
        #expect(flags.analysisPackEnabled == true)
        #expect(flags.intelligencePackEnabled == true)
        #expect(flags.canExtractEntities == true)
        #expect(flags.canRAGChat == true)
    }

    @Test("Disable Analysis Pack also disables Intelligence Pack")
    func disableAnalysisPackDisablesIntelligence() throws {
        // Arrange
        let flags = FeatureFlags()
        flags.resetToDefaults()
        flags.enableIntelligencePack()
        #expect(flags.intelligencePackEnabled == true)

        // Act
        flags.disableAnalysisPack()

        // Assert
        #expect(flags.analysisPackEnabled == false)
        #expect(flags.intelligencePackEnabled == false)
        #expect(flags.canExtractEntities == false)
    }

    @Test("Intelligence Pack features require Analysis Pack")
    func intelligenceFeaturesRequireAnalysis() throws {
        // Arrange
        let flags = FeatureFlags()
        flags.resetToDefaults()
        // Enable intelligence but not analysis (directly set the property)
        flags.analysisPackEnabled = false
        flags.intelligencePackEnabled = true

        // Assert - features should still be disabled because analysis is off
        #expect(flags.canExtractEntities == false)
        #expect(flags.canRAGChat == false)
        #expect(flags.canBuildKnowledgeGraph == false)
    }

    @Test("Reset restores all defaults")
    func resetToDefaults() throws {
        // Arrange
        let flags = FeatureFlags()
        flags.enableIntelligencePack()
        flags.cloudLLMEnabled = true
        flags.experimentalFeaturesEnabled = true
        flags.maxMemoryUsageMB = 16384

        // Act
        flags.resetToDefaults()

        // Assert
        #expect(flags.analysisPackEnabled == false)
        #expect(flags.intelligencePackEnabled == false)
        #expect(flags.cloudLLMEnabled == false)
        #expect(flags.experimentalFeaturesEnabled == false)
        #expect(flags.maxMemoryUsageMB == 8192)
    }

    @Test("Recommended memory limit is reasonable")
    func recommendedMemoryLimit() throws {
        // Arrange & Act
        let recommended = FeatureFlags.recommendedMemoryLimit()

        // Assert - should be at least 4GB and in MB
        #expect(recommended >= 4096)
        #expect(recommended % 1024 == 0)  // Should be in GB increments
    }
}
