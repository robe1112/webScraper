//
//  DownloadedFile.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import Foundation

/// Represents a downloaded file from a scrape job
/// Tracks metadata, location, and duplicate status
struct DownloadedFile: Identifiable, Codable, Hashable {
    let id: UUID
    let jobId: UUID
    let projectId: UUID
    
    // Source information
    let sourceURL: String
    let sourcePageURL: String?
    
    // Local storage
    var localPath: String
    var fileName: String
    var fileExtension: String
    
    // File metadata
    var fileSize: Int64
    var mimeType: String?
    var fileType: FileType
    
    // Hash for duplicate detection
    var sha256Hash: String?
    var md5Hash: String?
    
    // Duplicate management
    var isDuplicate: Bool
    var duplicateGroupId: UUID?
    var originalFileId: UUID?  // If this is a duplicate, points to original
    
    // Basic metadata (extracted without Analysis Pack)
    var basicMetadata: BasicFileMetadata
    
    // User organization
    var tags: [String]
    var notes: String?
    var isFavorite: Bool
    
    // Status
    var downloadStatus: DownloadStatus
    var errorMessage: String?
    
    // Timestamps
    let downloadedAt: Date
    var modifiedAt: Date?
    
    init(
        id: UUID = UUID(),
        jobId: UUID,
        projectId: UUID,
        sourceURL: String,
        sourcePageURL: String? = nil,
        localPath: String,
        fileName: String,
        fileExtension: String,
        fileSize: Int64 = 0,
        mimeType: String? = nil,
        fileType: FileType = .other,
        sha256Hash: String? = nil,
        md5Hash: String? = nil,
        isDuplicate: Bool = false,
        duplicateGroupId: UUID? = nil,
        originalFileId: UUID? = nil,
        basicMetadata: BasicFileMetadata = BasicFileMetadata(),
        tags: [String] = [],
        notes: String? = nil,
        isFavorite: Bool = false,
        downloadStatus: DownloadStatus = .pending,
        errorMessage: String? = nil,
        downloadedAt: Date = Date(),
        modifiedAt: Date? = nil
    ) {
        self.id = id
        self.jobId = jobId
        self.projectId = projectId
        self.sourceURL = sourceURL
        self.sourcePageURL = sourcePageURL
        self.localPath = localPath
        self.fileName = fileName
        self.fileExtension = fileExtension
        self.fileSize = fileSize
        self.mimeType = mimeType
        self.fileType = fileType
        self.sha256Hash = sha256Hash
        self.md5Hash = md5Hash
        self.isDuplicate = isDuplicate
        self.duplicateGroupId = duplicateGroupId
        self.originalFileId = originalFileId
        self.basicMetadata = basicMetadata
        self.tags = tags
        self.notes = notes
        self.isFavorite = isFavorite
        self.downloadStatus = downloadStatus
        self.errorMessage = errorMessage
        self.downloadedAt = downloadedAt
        self.modifiedAt = modifiedAt
    }
    
    /// Human-readable file size
    nonisolated var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    /// Full file path URL
    var fileURL: URL? {
        URL(fileURLWithPath: localPath)
    }
}

/// Download status
enum DownloadStatus: String, Codable {
    case pending = "Pending"
    case downloading = "Downloading"
    case completed = "Completed"
    case failed = "Failed"
    case cancelled = "Cancelled"
    case skipped = "Skipped"  // e.g., duplicate or filtered out
    
    var icon: String {
        switch self {
        case .pending: return "clock"
        case .downloading: return "arrow.down.circle"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.circle.fill"
        case .cancelled: return "xmark.circle"
        case .skipped: return "forward.circle"
        }
    }
}

/// Basic metadata that can be extracted without Analysis Pack
struct BasicFileMetadata: Codable, Hashable {
    // Common
    var creationDate: Date?
    var modificationDate: Date?
    
    // PDF
    var pdfPageCount: Int?
    var pdfTitle: String?
    var pdfAuthor: String?
    
    // Images
    var imageWidth: Int?
    var imageHeight: Int?
    var imageColorSpace: String?
    
    // Audio/Video
    var mediaDuration: TimeInterval?
    
    init(
        creationDate: Date? = nil,
        modificationDate: Date? = nil,
        pdfPageCount: Int? = nil,
        pdfTitle: String? = nil,
        pdfAuthor: String? = nil,
        imageWidth: Int? = nil,
        imageHeight: Int? = nil,
        imageColorSpace: String? = nil,
        mediaDuration: TimeInterval? = nil
    ) {
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.pdfPageCount = pdfPageCount
        self.pdfTitle = pdfTitle
        self.pdfAuthor = pdfAuthor
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.imageColorSpace = imageColorSpace
        self.mediaDuration = mediaDuration
    }
    
    /// Image dimensions as string
    var imageDimensions: String? {
        guard let width = imageWidth, let height = imageHeight else { return nil }
        return "\(width) × \(height)"
    }
    
    /// Formatted duration
    var formattedDuration: String? {
        guard let duration = mediaDuration else { return nil }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration)
    }
}

/// Group of duplicate files
struct DuplicateGroup: Identifiable, Codable {
    let id: UUID
    let hash: String
    var fileIds: [UUID]
    var originalFileId: UUID
    var totalSize: Int64
    var duplicateCount: Int
    
    init(
        id: UUID = UUID(),
        hash: String,
        fileIds: [UUID] = [],
        originalFileId: UUID,
        totalSize: Int64 = 0,
        duplicateCount: Int = 0
    ) {
        self.id = id
        self.hash = hash
        self.fileIds = fileIds
        self.originalFileId = originalFileId
        self.totalSize = totalSize
        self.duplicateCount = duplicateCount
    }
    
    /// Space that would be saved by removing duplicates
    var potentialSavings: Int64 {
        guard duplicateCount > 0, fileIds.count > 1 else { return 0 }
        // Total size minus one copy
        return totalSize - (totalSize / Int64(fileIds.count))
    }
}
