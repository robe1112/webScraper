//
//  DiffEngine.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import Foundation
import CryptoKit

/// Tracks changes between page snapshots over time
/// Supports text-based and structural HTML diffing
actor DiffEngine {
    
    // MARK: - Types
    
    struct Snapshot: Codable, Identifiable {
        let id: UUID
        let pageURL: String
        let capturedAt: Date
        let contentHash: String
        let htmlContent: String?  // Optionally store full content
        let textContent: String
        let title: String?
        var compressedContent: Data?  // Compressed for storage efficiency
    }
    
    struct DiffResult {
        let oldSnapshot: Snapshot
        let newSnapshot: Snapshot
        let hasChanges: Bool
        let changePercentage: Double
        let addedLines: [String]
        let removedLines: [String]
        let modifiedSections: [ModifiedSection]
        let summary: String
    }
    
    struct ModifiedSection {
        let location: Int  // Line number
        let oldContent: String
        let newContent: String
        let changeType: ChangeType
    }
    
    enum ChangeType {
        case added
        case removed
        case modified
    }
    
    struct WatchRule: Codable, Identifiable {
        let id: UUID
        var pageURL: String
        var selector: String?  // Optional CSS selector to watch specific element
        var keywords: [String]  // Keywords to monitor
        var changeThreshold: Double  // Minimum % change to trigger alert (0-100)
        var isEnabled: Bool
        var lastChecked: Date?
        var lastChangeDetected: Date?
    }
    
    // MARK: - Properties
    
    private var snapshots: [String: [Snapshot]] = [:]  // URL -> snapshots (sorted by date)
    private var watchRules: [UUID: WatchRule] = [:]
    private let maxSnapshotsPerPage: Int
    
    // MARK: - Initialization
    
    init(maxSnapshotsPerPage: Int = 100) {
        self.maxSnapshotsPerPage = maxSnapshotsPerPage
    }
    
    // MARK: - Snapshot Management
    
    /// Create a new snapshot
    func createSnapshot(url: String, htmlContent: String, textContent: String, title: String?) -> Snapshot {
        let contentHash = computeHash(textContent)
        
        let snapshot = Snapshot(
            id: UUID(),
            pageURL: url,
            capturedAt: Date(),
            contentHash: contentHash,
            htmlContent: nil,  // Don't store full HTML by default
            textContent: textContent,
            title: title,
            compressedContent: compressContent(htmlContent)
        )
        
        // Add to history
        var pageSnapshots = snapshots[url] ?? []
        pageSnapshots.append(snapshot)
        
        // Limit history size
        if pageSnapshots.count > maxSnapshotsPerPage {
            pageSnapshots = Array(pageSnapshots.suffix(maxSnapshotsPerPage))
        }
        
        snapshots[url] = pageSnapshots
        
        return snapshot
    }
    
    /// Get all snapshots for a URL
    func getSnapshots(for url: String) -> [Snapshot] {
        snapshots[url] ?? []
    }
    
    /// Get the latest snapshot for a URL
    func getLatestSnapshot(for url: String) -> Snapshot? {
        snapshots[url]?.last
    }
    
    /// Get snapshot by ID
    func getSnapshot(id: UUID) -> Snapshot? {
        for pageSnapshots in snapshots.values {
            if let snapshot = pageSnapshots.first(where: { $0.id == id }) {
                return snapshot
            }
        }
        return nil
    }
    
    /// Delete old snapshots based on retention policy
    func pruneSnapshots(olderThan date: Date) {
        for (url, pageSnapshots) in snapshots {
            let filtered = pageSnapshots.filter { $0.capturedAt >= date }
            if filtered.isEmpty {
                snapshots.removeValue(forKey: url)
            } else {
                snapshots[url] = filtered
            }
        }
    }
    
    // MARK: - Diff Operations
    
    /// Compare two snapshots
    func diff(old: Snapshot, new: Snapshot) -> DiffResult {
        // Quick check using hash
        if old.contentHash == new.contentHash {
            return DiffResult(
                oldSnapshot: old,
                newSnapshot: new,
                hasChanges: false,
                changePercentage: 0,
                addedLines: [],
                removedLines: [],
                modifiedSections: [],
                summary: "No changes detected"
            )
        }
        
        // Perform line-by-line diff
        let oldLines = old.textContent.components(separatedBy: .newlines)
        let newLines = new.textContent.components(separatedBy: .newlines)
        
        let (added, removed, modified) = computeLineDiff(oldLines: oldLines, newLines: newLines)
        
        // Calculate change percentage
        let totalLines = max(oldLines.count, newLines.count)
        let changedLines = added.count + removed.count + modified.count
        let changePercentage = totalLines > 0 ? Double(changedLines) / Double(totalLines) * 100 : 0
        
        // Generate summary
        let summary = generateSummary(added: added.count, removed: removed.count, modified: modified.count)
        
        return DiffResult(
            oldSnapshot: old,
            newSnapshot: new,
            hasChanges: true,
            changePercentage: changePercentage,
            addedLines: added,
            removedLines: removed,
            modifiedSections: modified,
            summary: summary
        )
    }
    
    /// Compare latest snapshot with previous
    func diffLatest(for url: String) -> DiffResult? {
        let pageSnapshots = snapshots[url] ?? []
        guard pageSnapshots.count >= 2 else { return nil }
        
        let old = pageSnapshots[pageSnapshots.count - 2]
        let new = pageSnapshots[pageSnapshots.count - 1]
        
        return diff(old: old, new: new)
    }
    
    /// Check if content has changed since last snapshot
    func hasChanged(url: String, newContent: String) -> Bool {
        guard let latest = getLatestSnapshot(for: url) else {
            return true  // No previous snapshot means it's new
        }
        
        let newHash = computeHash(newContent)
        return latest.contentHash != newHash
    }
    
    // MARK: - Watch Rules
    
    /// Add a watch rule
    func addWatchRule(_ rule: WatchRule) {
        watchRules[rule.id] = rule
    }
    
    /// Update a watch rule
    func updateWatchRule(_ rule: WatchRule) {
        watchRules[rule.id] = rule
    }
    
    /// Remove a watch rule
    func removeWatchRule(id: UUID) {
        watchRules.removeValue(forKey: id)
    }
    
    /// Get all watch rules
    func getWatchRules() -> [WatchRule] {
        Array(watchRules.values)
    }
    
    /// Get watch rules for a URL
    func getWatchRules(for url: String) -> [WatchRule] {
        watchRules.values.filter { $0.pageURL == url }
    }
    
    /// Check if changes trigger any watch rules
    func checkWatchRules(url: String, newContent: String) -> [WatchRuleAlert] {
        let rules = getWatchRules(for: url)
        var alerts: [WatchRuleAlert] = []
        
        for rule in rules where rule.isEnabled {
            var triggered = false
            var reason = ""
            
            // Check keywords
            for keyword in rule.keywords {
                if newContent.localizedCaseInsensitiveContains(keyword) {
                    // Check if keyword is new
                    if let latest = getLatestSnapshot(for: url),
                       !latest.textContent.localizedCaseInsensitiveContains(keyword) {
                        triggered = true
                        reason = "New keyword detected: \(keyword)"
                        break
                    }
                }
            }
            
            // Check change threshold
            if !triggered, let latest = getLatestSnapshot(for: url) {
                let oldHash = latest.contentHash
                let newHash = computeHash(newContent)
                
                if oldHash != newHash {
                    let diff = self.diff(old: latest, new: Snapshot(
                        id: UUID(),
                        pageURL: url,
                        capturedAt: Date(),
                        contentHash: newHash,
                        htmlContent: nil,
                        textContent: newContent,
                        title: nil,
                        compressedContent: nil
                    ))
                    
                    if diff.changePercentage >= rule.changeThreshold {
                        triggered = true
                        reason = String(format: "Change threshold exceeded: %.1f%% (threshold: %.1f%%)",
                                       diff.changePercentage, rule.changeThreshold)
                    }
                }
            }
            
            if triggered {
                alerts.append(WatchRuleAlert(
                    ruleId: rule.id,
                    ruleName: rule.selector ?? rule.pageURL,
                    url: url,
                    reason: reason,
                    detectedAt: Date()
                ))
                
                // Update rule last change detected
                var updatedRule = rule
                updatedRule.lastChangeDetected = Date()
                watchRules[rule.id] = updatedRule
            }
        }
        
        return alerts
    }
    
    // MARK: - Private Methods
    
    private func computeHash(_ content: String) -> String {
        let data = Data(content.utf8)
        return SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func compressContent(_ content: String) -> Data? {
        guard let data = content.data(using: .utf8) else { return nil }
        return try? (data as NSData).compressed(using: .lzfse) as Data
    }
    
    private func decompressContent(_ data: Data) -> String? {
        guard let decompressed = try? (data as NSData).decompressed(using: .lzfse) as Data else {
            return nil
        }
        return String(data: decompressed, encoding: .utf8)
    }
    
    private func computeLineDiff(oldLines: [String], newLines: [String]) -> (added: [String], removed: [String], modified: [ModifiedSection]) {
        var added: [String] = []
        var removed: [String] = []
        var modified: [ModifiedSection] = []
        
        let oldSet = Set(oldLines)
        let newSet = Set(newLines)
        
        // Find removed lines
        for line in oldLines where !newSet.contains(line) {
            removed.append(line)
        }
        
        // Find added lines
        for line in newLines where !oldSet.contains(line) {
            added.append(line)
        }
        
        // Simple modification detection (lines at same position that changed)
        let minCount = min(oldLines.count, newLines.count)
        for i in 0..<minCount {
            if oldLines[i] != newLines[i] {
                modified.append(ModifiedSection(
                    location: i,
                    oldContent: oldLines[i],
                    newContent: newLines[i],
                    changeType: .modified
                ))
            }
        }
        
        return (added, removed, modified)
    }
    
    private func generateSummary(added: Int, removed: Int, modified: Int) -> String {
        var parts: [String] = []
        
        if added > 0 {
            parts.append("\(added) line\(added == 1 ? "" : "s") added")
        }
        if removed > 0 {
            parts.append("\(removed) line\(removed == 1 ? "" : "s") removed")
        }
        if modified > 0 {
            parts.append("\(modified) line\(modified == 1 ? "" : "s") modified")
        }
        
        if parts.isEmpty {
            return "No significant changes"
        }
        
        return parts.joined(separator: ", ")
    }
}

// MARK: - Supporting Types

struct WatchRuleAlert: Identifiable {
    let id = UUID()
    let ruleId: UUID
    let ruleName: String
    let url: String
    let reason: String
    let detectedAt: Date
}
