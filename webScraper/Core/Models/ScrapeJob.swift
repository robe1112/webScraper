//
//  ScrapeJob.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import Foundation

/// Represents a single scraping job/session
/// A project can have multiple jobs (different scrape sessions)
struct ScrapeJob: Identifiable, Codable, Hashable {
    let id: UUID
    let projectId: UUID
    var startURL: String
    var status: JobStatus
    var configuration: JobConfiguration
    
    // Progress tracking
    var progress: JobProgress
    
    // Timing
    let createdAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var pausedAt: Date?
    
    // Results
    var pagesScraped: Int
    var filesDownloaded: Int
    var errorsEncountered: Int
    var bytesDownloaded: Int64
    
    // Schedule (optional)
    var schedule: JobSchedule?
    
    init(
        id: UUID = UUID(),
        projectId: UUID,
        startURL: String,
        status: JobStatus = .pending,
        configuration: JobConfiguration = JobConfiguration(),
        progress: JobProgress = JobProgress(),
        createdAt: Date = Date(),
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        pausedAt: Date? = nil,
        pagesScraped: Int = 0,
        filesDownloaded: Int = 0,
        errorsEncountered: Int = 0,
        bytesDownloaded: Int64 = 0,
        schedule: JobSchedule? = nil
    ) {
        self.id = id
        self.projectId = projectId
        self.startURL = startURL
        self.status = status
        self.configuration = configuration
        self.progress = progress
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.pausedAt = pausedAt
        self.pagesScraped = pagesScraped
        self.filesDownloaded = filesDownloaded
        self.errorsEncountered = errorsEncountered
        self.bytesDownloaded = bytesDownloaded
        self.schedule = schedule
    }
}

/// Job execution status
enum JobStatus: String, Codable, CaseIterable {
    case pending = "Pending"
    case queued = "Queued"
    case running = "Running"
    case paused = "Paused"
    case completed = "Completed"
    case failed = "Failed"
    case cancelled = "Cancelled"
    
    var isActive: Bool {
        switch self {
        case .running, .queued:
            return true
        default:
            return false
        }
    }
    
    var icon: String {
        switch self {
        case .pending: return "clock"
        case .queued: return "list.bullet"
        case .running: return "play.circle.fill"
        case .paused: return "pause.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }
}

/// Job-specific configuration (can override project settings)
struct JobConfiguration: Codable, Hashable {
    var maxDepth: Int?
    var maxPages: Int?
    var enableJavaScript: Bool?
    var followExternalLinks: Bool?
    var requestDelayMs: Int?
    var maxConcurrentRequests: Int?
    var extractionRules: [ExtractionRule]
    var downloadFileTypes: [FileType]
    
    init(
        maxDepth: Int? = nil,
        maxPages: Int? = nil,
        enableJavaScript: Bool? = nil,
        followExternalLinks: Bool? = nil,
        requestDelayMs: Int? = nil,
        maxConcurrentRequests: Int? = nil,
        extractionRules: [ExtractionRule] = [],
        downloadFileTypes: [FileType] = FileType.allCases
    ) {
        self.maxDepth = maxDepth
        self.maxPages = maxPages
        self.enableJavaScript = enableJavaScript
        self.followExternalLinks = followExternalLinks
        self.requestDelayMs = requestDelayMs
        self.maxConcurrentRequests = maxConcurrentRequests
        self.extractionRules = extractionRules
        self.downloadFileTypes = downloadFileTypes
    }
}

/// Real-time progress tracking
struct JobProgress: Codable, Hashable {
    var totalURLsDiscovered: Int
    var urlsProcessed: Int
    var urlsInQueue: Int
    var currentURL: String?
    var currentPhase: JobPhase
    var estimatedTimeRemaining: TimeInterval?
    
    init(
        totalURLsDiscovered: Int = 0,
        urlsProcessed: Int = 0,
        urlsInQueue: Int = 0,
        currentURL: String? = nil,
        currentPhase: JobPhase = .initializing,
        estimatedTimeRemaining: TimeInterval? = nil
    ) {
        self.totalURLsDiscovered = totalURLsDiscovered
        self.urlsProcessed = urlsProcessed
        self.urlsInQueue = urlsInQueue
        self.currentURL = currentURL
        self.currentPhase = currentPhase
        self.estimatedTimeRemaining = estimatedTimeRemaining
    }
    
    var percentComplete: Double {
        guard totalURLsDiscovered > 0 else { return 0 }
        return Double(urlsProcessed) / Double(totalURLsDiscovered) * 100
    }
}

/// Current phase of job execution
enum JobPhase: String, Codable {
    case initializing = "Initializing"
    case fetchingRobotsTxt = "Checking robots.txt"
    case crawling = "Crawling"
    case downloading = "Downloading files"
    case extracting = "Extracting data"
    case finalizing = "Finalizing"
    case complete = "Complete"
}

/// Schedule for recurring jobs
struct JobSchedule: Codable, Hashable {
    var isEnabled: Bool
    var frequency: ScheduleFrequency
    var time: Date  // Time of day to run
    var daysOfWeek: [Int]  // 1-7, Sunday = 1
    var lastRun: Date?
    var nextRun: Date?
    
    init(
        isEnabled: Bool = false,
        frequency: ScheduleFrequency = .daily,
        time: Date = Date(),
        daysOfWeek: [Int] = [1, 2, 3, 4, 5, 6, 7],
        lastRun: Date? = nil,
        nextRun: Date? = nil
    ) {
        self.isEnabled = isEnabled
        self.frequency = frequency
        self.time = time
        self.daysOfWeek = daysOfWeek
        self.lastRun = lastRun
        self.nextRun = nextRun
    }
}

enum ScheduleFrequency: String, Codable, CaseIterable {
    case hourly = "Hourly"
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case custom = "Custom"
}

/// File type categories for download filtering
enum FileType: String, Codable, CaseIterable {
    case image = "Images"
    case pdf = "PDFs"
    case document = "Documents"
    case audio = "Audio"
    case video = "Video"
    case archive = "Archives"
    case other = "Other"
    
    var extensions: [String] {
        switch self {
        case .image:
            return ["jpg", "jpeg", "png", "gif", "webp", "svg", "bmp", "tiff"]
        case .pdf:
            return ["pdf"]
        case .document:
            return ["doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf", "odt"]
        case .audio:
            return ["mp3", "wav", "aac", "flac", "ogg", "m4a"]
        case .video:
            return ["mp4", "mov", "avi", "mkv", "webm", "wmv", "m4v"]
        case .archive:
            return ["zip", "rar", "7z", "tar", "gz", "bz2"]
        case .other:
            return []
        }
    }
}
