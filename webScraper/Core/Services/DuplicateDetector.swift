//
//  DuplicateDetector.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import Foundation
import CryptoKit

/// Detects and manages duplicate files using hash-based comparison
actor DuplicateDetector {
    
    // MARK: - Types
    
    struct DuplicateReport {
        var totalFiles: Int
        var uniqueFiles: Int
        var duplicateFiles: Int
        var duplicateGroups: [DuplicateGroup]
        var totalSize: Int64
        var duplicateSize: Int64
        var potentialSavings: Int64
    }
    
    // MARK: - Properties
    
    private var hashIndex: [String: [UUID]] = [:]  // hash -> file IDs
    private var fileHashes: [UUID: String] = [:]   // file ID -> hash
    private var duplicateGroups: [UUID: DuplicateGroup] = [:]
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Public Methods
    
    /// Register a file's hash
    func registerFile(id: UUID, hash: String, fileSize: Int64) -> DuplicateCheckResult {
        // Check if hash already exists
        if var existingIds = hashIndex[hash] {
            // This is a duplicate
            existingIds.append(id)
            hashIndex[hash] = existingIds
            fileHashes[id] = hash
            
            // Update or create duplicate group
            let originalId = existingIds[0]
            updateDuplicateGroup(hash: hash, fileIds: existingIds, fileSize: fileSize)
            
            return DuplicateCheckResult(
                isDuplicate: true,
                originalFileId: originalId,
                duplicateGroupId: duplicateGroups.values.first(where: { $0.hash == hash })?.id
            )
        } else {
            // New unique file
            hashIndex[hash] = [id]
            fileHashes[id] = hash
            
            return DuplicateCheckResult(
                isDuplicate: false,
                originalFileId: nil,
                duplicateGroupId: nil
            )
        }
    }
    
    /// Check if a hash already exists (before downloading)
    func checkHash(_ hash: String) -> Bool {
        hashIndex[hash] != nil
    }
    
    /// Get file IDs with the same hash
    func getFilesWithHash(_ hash: String) -> [UUID] {
        hashIndex[hash] ?? []
    }
    
    /// Get hash for a file
    func getHash(for fileId: UUID) -> String? {
        fileHashes[fileId]
    }
    
    /// Remove a file from the index
    func removeFile(id: UUID) {
        guard let hash = fileHashes[id] else { return }
        
        fileHashes.removeValue(forKey: id)
        
        if var ids = hashIndex[hash] {
            ids.removeAll { $0 == id }
            if ids.isEmpty {
                hashIndex.removeValue(forKey: hash)
                // Remove duplicate group if no longer needed
                if let group = duplicateGroups.values.first(where: { $0.hash == hash }) {
                    duplicateGroups.removeValue(forKey: group.id)
                }
            } else {
                hashIndex[hash] = ids
                // Update duplicate group
                if let group = duplicateGroups.values.first(where: { $0.hash == hash }) {
                    var updatedGroup = group
                    updatedGroup.fileIds = ids
                    updatedGroup.duplicateCount = ids.count - 1
                    duplicateGroups[group.id] = updatedGroup
                }
            }
        }
    }
    
    /// Get all duplicate groups
    func getDuplicateGroups() -> [DuplicateGroup] {
        Array(duplicateGroups.values)
    }
    
    /// Get duplicate group by ID
    func getDuplicateGroup(id: UUID) -> DuplicateGroup? {
        duplicateGroups[id]
    }
    
    /// Generate a full duplicate report
    func generateReport() -> DuplicateReport {
        let groups = Array(duplicateGroups.values)
        let totalFiles = fileHashes.count
        let duplicateFiles = groups.reduce(0) { $0 + $1.duplicateCount }
        let uniqueFiles = totalFiles - duplicateFiles
        let totalSize = groups.reduce(Int64(0)) { $0 + $1.totalSize }
        let potentialSavings = groups.reduce(Int64(0)) { $0 + $1.potentialSavings }
        
        return DuplicateReport(
            totalFiles: totalFiles,
            uniqueFiles: uniqueFiles,
            duplicateFiles: duplicateFiles,
            duplicateGroups: groups,
            totalSize: totalSize,
            duplicateSize: potentialSavings,
            potentialSavings: potentialSavings
        )
    }
    
    /// Clear all data
    func clear() {
        hashIndex.removeAll()
        fileHashes.removeAll()
        duplicateGroups.removeAll()
    }
    
    // MARK: - Static Hash Methods
    
    /// Compute SHA-256 hash for file data
    static func computeSHA256(data: Data) -> String {
        SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Compute SHA-256 hash for a file at URL
    static func computeSHA256(fileURL: URL) throws -> String {
        let data = try Data(contentsOf: fileURL)
        return computeSHA256(data: data)
    }
    
    /// Compute MD5 hash for file data
    static func computeMD5(data: Data) -> String {
        Insecure.MD5.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Compute MD5 hash for a file at URL
    static func computeMD5(fileURL: URL) throws -> String {
        let data = try Data(contentsOf: fileURL)
        return computeMD5(data: data)
    }
    
    /// Compute both hashes for a file
    static func computeHashes(fileURL: URL) throws -> (sha256: String, md5: String) {
        let data = try Data(contentsOf: fileURL)
        return (computeSHA256(data: data), computeMD5(data: data))
    }
    
    /// Streaming hash computation for large files
    static func computeSHA256Streaming(fileURL: URL, bufferSize: Int = 1024 * 1024) throws -> String {
        let fileHandle = try FileHandle(forReadingFrom: fileURL)
        defer { try? fileHandle.close() }
        
        var hasher = SHA256()
        
        while autoreleasepool(invoking: {
            let data = fileHandle.readData(ofLength: bufferSize)
            if data.isEmpty {
                return false
            }
            hasher.update(data: data)
            return true
        }) {}
        
        return hasher.finalize().compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Private Methods
    
    private func updateDuplicateGroup(hash: String, fileIds: [UUID], fileSize: Int64) {
        // Find existing group or create new one
        if let existingGroup = duplicateGroups.values.first(where: { $0.hash == hash }) {
            var group = existingGroup
            group.fileIds = fileIds
            group.duplicateCount = fileIds.count - 1
            group.totalSize = fileSize * Int64(fileIds.count)
            duplicateGroups[group.id] = group
        } else {
            let group = DuplicateGroup(
                hash: hash,
                fileIds: fileIds,
                originalFileId: fileIds[0],
                totalSize: fileSize * Int64(fileIds.count),
                duplicateCount: fileIds.count - 1
            )
            duplicateGroups[group.id] = group
        }
    }
}

// MARK: - Supporting Types

struct DuplicateCheckResult {
    let isDuplicate: Bool
    let originalFileId: UUID?
    let duplicateGroupId: UUID?
}
