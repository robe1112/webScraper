//
//  FileDownloader.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import Foundation
import CryptoKit
import ImageIO

/// Downloads and manages files from scraped URLs
/// Handles concurrent downloads, progress tracking, and organization
actor FileDownloader {
    
    // MARK: - Configuration
    
    struct Configuration {
        var downloadDirectory: URL
        var maxConcurrentDownloads: Int
        var maxFileSizeMB: Int
        var organizeByType: Bool
        var organizeByDate: Bool
        var preserveOriginalNames: Bool
        var computeHashes: Bool
        var userAgent: String
        
        init(
            downloadDirectory: URL? = nil,
            maxConcurrentDownloads: Int = 4,
            maxFileSizeMB: Int = 500,
            organizeByType: Bool = true,
            organizeByDate: Bool = false,
            preserveOriginalNames: Bool = true,
            computeHashes: Bool = true,
            userAgent: String = "WebScraperBot/1.0"
        ) {
            if let dir = downloadDirectory {
                self.downloadDirectory = dir
            } else {
                let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                self.downloadDirectory = documentsURL.appendingPathComponent("webScraper/Downloads")
            }
            self.maxConcurrentDownloads = maxConcurrentDownloads
            self.maxFileSizeMB = maxFileSizeMB
            self.organizeByType = organizeByType
            self.organizeByDate = organizeByDate
            self.preserveOriginalNames = preserveOriginalNames
            self.computeHashes = computeHashes
            self.userAgent = userAgent
        }
    }
    
    // MARK: - Types
    
    struct DownloadProgress {
        var totalFiles: Int
        var completedFiles: Int
        var failedFiles: Int
        var totalBytes: Int64
        var downloadedBytes: Int64
        var currentDownloads: [DownloadTask]
        
        var percentComplete: Double {
            guard totalFiles > 0 else { return 0 }
            return Double(completedFiles) / Double(totalFiles) * 100
        }
    }
    
    struct DownloadTask: Identifiable {
        let id: UUID
        let url: URL
        let fileName: String
        var progress: Double
        var bytesDownloaded: Int64
        var totalBytes: Int64?
        var status: DownloadStatus
    }
    
    // MARK: - Delegate
    
    protocol DownloaderDelegate: AnyObject {
        func downloader(_ downloader: FileDownloader, didUpdateProgress progress: DownloadProgress) async
        func downloader(_ downloader: FileDownloader, didCompleteDownload file: DownloadedFile) async
        func downloader(_ downloader: FileDownloader, didFailDownload url: URL, error: Error) async
    }
    
    // MARK: - Properties
    
    private var configuration: Configuration
    private var queue: [DownloadRequest] = []
    private var activeTasks: [UUID: URLSessionDownloadTask] = [:]
    private var taskProgress: [UUID: DownloadTask] = [:]
    private var progress: DownloadProgress
    private var isRunning = false
    private var session: URLSession!
    private let fileManager = FileManager.default
    
    weak var delegate: (any DownloaderDelegate)?
    
    // MARK: - Initialization
    
    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        self.progress = DownloadProgress(
            totalFiles: 0,
            completedFiles: 0,
            failedFiles: 0,
            totalBytes: 0,
            downloadedBytes: 0,
            currentDownloads: []
        )
        
        // Create session
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 60
        sessionConfig.timeoutIntervalForResource = 3600  // 1 hour for large files
        self.session = URLSession(configuration: sessionConfig)
        
        // Create download directory
        try? fileManager.createDirectory(at: configuration.downloadDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Public Methods
    
    /// Update configuration
    func updateConfiguration(_ config: Configuration) {
        self.configuration = config
        try? fileManager.createDirectory(at: config.downloadDirectory, withIntermediateDirectories: true)
    }
    
    /// Add a URL to the download queue
    func enqueue(url: URL, projectId: UUID, jobId: UUID, sourcePageURL: URL? = nil) {
        let request = DownloadRequest(
            id: UUID(),
            url: url,
            projectId: projectId,
            jobId: jobId,
            sourcePageURL: sourcePageURL,
            priority: .normal,
            addedAt: Date()
        )
        queue.append(request)
        progress.totalFiles += 1
    }
    
    /// Add multiple URLs to the download queue
    func enqueue(urls: [URL], projectId: UUID, jobId: UUID) {
        for url in urls {
            enqueue(url: url, projectId: projectId, jobId: jobId)
        }
    }
    
    /// Start downloading queued files
    func start() async {
        guard !isRunning else { return }
        isRunning = true
        
        await processQueue()
    }
    
    /// Pause all downloads
    func pause() {
        isRunning = false
        for task in activeTasks.values {
            task.suspend()
        }
    }
    
    /// Resume downloads
    func resume() async {
        isRunning = true
        for task in activeTasks.values {
            task.resume()
        }
        await processQueue()
    }
    
    /// Cancel all downloads
    func cancel() {
        isRunning = false
        for task in activeTasks.values {
            task.cancel()
        }
        activeTasks.removeAll()
        taskProgress.removeAll()
        queue.removeAll()
    }
    
    /// Get current progress
    func getProgress() -> DownloadProgress {
        progress
    }
    
    /// Download a single file and return result
    func download(url: URL, projectId: UUID, jobId: UUID, sourcePageURL: URL? = nil) async throws -> DownloadedFile {
        // Create request
        var request = URLRequest(url: url)
        request.setValue(configuration.userAgent, forHTTPHeaderField: "User-Agent")
        
        // Download
        let (tempURL, response) = try await session.download(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw DownloadError.httpError
        }
        
        // Get file info
        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")
        let contentLength = Int64(httpResponse.value(forHTTPHeaderField: "Content-Length") ?? "") ?? 0
        
        // Determine file type and name
        let fileType = determineFileType(url: url, contentType: contentType)
        let fileName = generateFileName(url: url, contentType: contentType)
        let localPath = generateLocalPath(fileName: fileName, fileType: fileType, projectId: projectId)
        
        // Move file to final location
        try? fileManager.createDirectory(at: localPath.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        if fileManager.fileExists(atPath: localPath.path) {
            try fileManager.removeItem(at: localPath)
        }
        try fileManager.moveItem(at: tempURL, to: localPath)
        
        // Get file size
        let attributes = try fileManager.attributesOfItem(atPath: localPath.path)
        let fileSize = attributes[.size] as? Int64 ?? contentLength
        
        // Compute hashes
        var sha256Hash: String?
        var md5Hash: String?
        
        if configuration.computeHashes {
            let fileData = try Data(contentsOf: localPath)
            sha256Hash = SHA256.hash(data: fileData).compactMap { String(format: "%02x", $0) }.joined()
            md5Hash = Insecure.MD5.hash(data: fileData).compactMap { String(format: "%02x", $0) }.joined()
        }
        
        // Extract basic metadata
        let basicMetadata = await extractBasicMetadata(from: localPath, fileType: fileType)
        
        // Create downloaded file record
        let downloadedFile = DownloadedFile(
            jobId: jobId,
            projectId: projectId,
            sourceURL: url.absoluteString,
            sourcePageURL: sourcePageURL?.absoluteString,
            localPath: localPath.path,
            fileName: fileName,
            fileExtension: localPath.pathExtension,
            fileSize: fileSize,
            mimeType: contentType,
            fileType: fileType,
            sha256Hash: sha256Hash,
            md5Hash: md5Hash,
            basicMetadata: basicMetadata,
            downloadStatus: .completed
        )
        
        return downloadedFile
    }
    
    // MARK: - Private Methods
    
    private func processQueue() async {
        while isRunning && (!queue.isEmpty || !activeTasks.isEmpty) {
            // Start new downloads if under limit
            while activeTasks.count < configuration.maxConcurrentDownloads && !queue.isEmpty {
                let request = queue.removeFirst()
                await startDownload(request)
            }
            
            // Wait a bit before checking again
            try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
        }
    }
    
    private func startDownload(_ request: DownloadRequest) async {
        let taskId = request.id
        
        var urlRequest = URLRequest(url: request.url)
        urlRequest.setValue(configuration.userAgent, forHTTPHeaderField: "User-Agent")
        
        let fileName = generateFileName(url: request.url, contentType: nil)
        
        let task = DownloadTask(
            id: taskId,
            url: request.url,
            fileName: fileName,
            progress: 0,
            bytesDownloaded: 0,
            totalBytes: nil,
            status: .downloading
        )
        
        taskProgress[taskId] = task
        progress.currentDownloads = Array(taskProgress.values)
        
        do {
            let file = try await download(
                url: request.url,
                projectId: request.projectId,
                jobId: request.jobId,
                sourcePageURL: request.sourcePageURL
            )
            
            taskProgress.removeValue(forKey: taskId)
            progress.completedFiles += 1
            progress.currentDownloads = Array(taskProgress.values)
            
            await delegate?.downloader(self, didCompleteDownload: file)
            await delegate?.downloader(self, didUpdateProgress: progress)
            
        } catch {
            taskProgress.removeValue(forKey: taskId)
            progress.failedFiles += 1
            progress.currentDownloads = Array(taskProgress.values)
            
            await delegate?.downloader(self, didFailDownload: request.url, error: error)
            await delegate?.downloader(self, didUpdateProgress: progress)
        }
    }
    
    private func determineFileType(url: URL, contentType: String?) -> FileType {
        let ext = url.pathExtension.lowercased()
        
        // Check by extension
        if ["jpg", "jpeg", "png", "gif", "webp", "svg", "bmp"].contains(ext) {
            return .image
        }
        if ext == "pdf" {
            return .pdf
        }
        if ["doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf"].contains(ext) {
            return .document
        }
        if ["mp3", "wav", "aac", "flac", "ogg", "m4a"].contains(ext) {
            return .audio
        }
        if ["mp4", "mov", "avi", "mkv", "webm", "wmv"].contains(ext) {
            return .video
        }
        if ["zip", "rar", "7z", "tar", "gz"].contains(ext) {
            return .archive
        }
        
        // Check by content type
        if let contentType = contentType?.lowercased() {
            if contentType.contains("image/") { return .image }
            if contentType.contains("application/pdf") { return .pdf }
            if contentType.contains("audio/") { return .audio }
            if contentType.contains("video/") { return .video }
        }
        
        return .other
    }
    
    private func generateFileName(url: URL, contentType: String?) -> String {
        if configuration.preserveOriginalNames {
            let originalName = url.lastPathComponent
            if !originalName.isEmpty && originalName != "/" {
                // Sanitize filename
                let sanitized = originalName.replacingOccurrences(of: "[^a-zA-Z0-9._-]", with: "_", options: .regularExpression)
                return sanitized
            }
        }
        
        // Generate unique filename
        let uuid = UUID().uuidString.prefix(8)
        var ext = url.pathExtension
        
        if ext.isEmpty, let contentType = contentType {
            ext = extensionFromContentType(contentType)
        }
        
        return "\(uuid).\(ext.isEmpty ? "bin" : ext)"
    }
    
    private func generateLocalPath(fileName: String, fileType: FileType, projectId: UUID) -> URL {
        var path = configuration.downloadDirectory
        
        // Add project subfolder
        path = path.appendingPathComponent(projectId.uuidString)
        
        // Organize by type
        if configuration.organizeByType {
            path = path.appendingPathComponent(fileType.rawValue)
        }
        
        // Organize by date
        if configuration.organizeByDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            path = path.appendingPathComponent(formatter.string(from: Date()))
        }
        
        return path.appendingPathComponent(fileName)
    }
    
    private func extensionFromContentType(_ contentType: String) -> String {
        let type = contentType.lowercased()
        
        if type.contains("image/jpeg") { return "jpg" }
        if type.contains("image/png") { return "png" }
        if type.contains("image/gif") { return "gif" }
        if type.contains("image/webp") { return "webp" }
        if type.contains("application/pdf") { return "pdf" }
        if type.contains("audio/mpeg") { return "mp3" }
        if type.contains("audio/wav") { return "wav" }
        if type.contains("video/mp4") { return "mp4" }
        if type.contains("application/zip") { return "zip" }
        if type.contains("text/html") { return "html" }
        if type.contains("text/plain") { return "txt" }
        if type.contains("application/json") { return "json" }
        
        return "bin"
    }
    
    private func extractBasicMetadata(from url: URL, fileType: FileType) async -> BasicFileMetadata {
        var metadata = BasicFileMetadata()
        
        // Get file dates
        if let attributes = try? fileManager.attributesOfItem(atPath: url.path) {
            metadata.creationDate = attributes[.creationDate] as? Date
            metadata.modificationDate = attributes[.modificationDate] as? Date
        }
        
        switch fileType {
        case .pdf:
            // Extract PDF metadata using PDFKit
            await extractPDFMetadata(from: url, into: &metadata)
            
        case .image:
            // Extract image dimensions using ImageIO
            extractImageMetadata(from: url, into: &metadata)
            
        case .audio, .video:
            // Extract duration using AVFoundation
            await extractMediaMetadata(from: url, into: &metadata)
            
        default:
            break
        }
        
        return metadata
    }
    
    private func extractPDFMetadata(from url: URL, into metadata: inout BasicFileMetadata) async {
        // Would use PDFKit here
        // For now, just placeholder
    }
    
    private func extractImageMetadata(from url: URL, into metadata: inout BasicFileMetadata) {
        // Use ImageIO for basic dimensions
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return
        }
        
        metadata.imageWidth = properties[kCGImagePropertyPixelWidth] as? Int
        metadata.imageHeight = properties[kCGImagePropertyPixelHeight] as? Int
        metadata.imageColorSpace = properties[kCGImagePropertyColorModel] as? String
    }
    
    private func extractMediaMetadata(from url: URL, into metadata: inout BasicFileMetadata) async {
        // Would use AVFoundation here
        // For now, just placeholder
    }
}

// MARK: - Supporting Types

private struct DownloadRequest {
    let id: UUID
    let url: URL
    let projectId: UUID
    let jobId: UUID
    let sourcePageURL: URL?
    let priority: DownloadPriority
    let addedAt: Date
}

private enum DownloadPriority {
    case high
    case normal
    case low
}

// MARK: - Errors

enum DownloadError: LocalizedError {
    case httpError
    case fileTooLarge
    case diskFull
    case permissionDenied
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .httpError:
            return "HTTP error during download"
        case .fileTooLarge:
            return "File exceeds maximum size limit"
        case .diskFull:
            return "Insufficient disk space"
        case .permissionDenied:
            return "Permission denied"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
