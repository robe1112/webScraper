//
//  ErrorRecovery.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import Foundation

/// Handles error recovery and crash resilience
final class ErrorRecovery {
    
    // MARK: - Types
    
    struct RecoveryState: Codable {
        var projectId: UUID?
        var jobId: UUID?
        var lastProcessedURL: String?
        var pendingURLs: [String]
        var processedURLCount: Int
        var downloadedFileCount: Int
        var lastSaveTime: Date
        var wasInterrupted: Bool
    }
    
    enum RecoveryAction {
        case resume(RecoveryState)
        case restart
        case ignore
    }
    
    // MARK: - Properties
    
    private let fileManager = FileManager.default
    private let recoveryDirectory: URL
    private let stateFileName = "recovery_state.json"
    private var currentState: RecoveryState?
    private var saveTimer: Timer?
    
    // MARK: - Initialization
    
    init() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        recoveryDirectory = documentsURL.appendingPathComponent("webScraper/Recovery")
        
        try? fileManager.createDirectory(at: recoveryDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - State Management
    
    /// Check if there's a recovery state available
    func hasRecoveryState() -> Bool {
        let stateURL = recoveryDirectory.appendingPathComponent(stateFileName)
        return fileManager.fileExists(atPath: stateURL.path)
    }
    
    /// Load recovery state if available
    func loadRecoveryState() -> RecoveryState? {
        let stateURL = recoveryDirectory.appendingPathComponent(stateFileName)
        
        guard let data = try? Data(contentsOf: stateURL),
              let state = try? JSONDecoder().decode(RecoveryState.self, from: data) else {
            return nil
        }
        
        return state
    }
    
    /// Save current recovery state
    func saveRecoveryState(_ state: RecoveryState) {
        currentState = state
        
        let stateURL = recoveryDirectory.appendingPathComponent(stateFileName)
        
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: stateURL)
        } catch {
            print("Failed to save recovery state: \(error)")
        }
    }
    
    /// Clear recovery state (called on successful completion)
    func clearRecoveryState() {
        currentState = nil
        
        let stateURL = recoveryDirectory.appendingPathComponent(stateFileName)
        try? fileManager.removeItem(at: stateURL)
    }
    
    /// Start automatic state saving
    func startAutoSave(interval: TimeInterval = 30) {
        stopAutoSave()
        
        saveTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let state = self?.currentState else { return }
            var updatedState = state
            updatedState.lastSaveTime = Date()
            self?.saveRecoveryState(updatedState)
        }
    }
    
    /// Stop automatic state saving
    func stopAutoSave() {
        saveTimer?.invalidate()
        saveTimer = nil
    }
    
    // MARK: - Job Recovery
    
    /// Create initial recovery state for a job
    func beginJob(projectId: UUID, jobId: UUID, startURL: String) {
        let state = RecoveryState(
            projectId: projectId,
            jobId: jobId,
            lastProcessedURL: nil,
            pendingURLs: [startURL],
            processedURLCount: 0,
            downloadedFileCount: 0,
            lastSaveTime: Date(),
            wasInterrupted: false
        )
        
        saveRecoveryState(state)
        startAutoSave()
    }
    
    /// Update recovery state during job execution
    func updateProgress(
        lastURL: String,
        pendingURLs: [String],
        processedCount: Int,
        downloadedCount: Int
    ) {
        guard var state = currentState else { return }
        
        state.lastProcessedURL = lastURL
        state.pendingURLs = pendingURLs
        state.processedURLCount = processedCount
        state.downloadedFileCount = downloadedCount
        state.lastSaveTime = Date()
        
        currentState = state
    }
    
    /// Mark job as completed
    func completeJob() {
        stopAutoSave()
        clearRecoveryState()
    }
    
    /// Mark job as interrupted (for clean pause/stop)
    func markInterrupted() {
        guard var state = currentState else { return }
        state.wasInterrupted = true
        saveRecoveryState(state)
    }
    
    // MARK: - Error Handling
    
    /// Determine recovery action based on state
    func determineRecoveryAction() -> RecoveryAction {
        guard let state = loadRecoveryState() else {
            return .restart
        }
        
        // Check how old the state is
        let hoursSinceLastSave = Date().timeIntervalSince(state.lastSaveTime) / 3600
        
        if hoursSinceLastSave > 24 {
            // State is too old, start fresh
            clearRecoveryState()
            return .restart
        }
        
        // Check if there's meaningful progress to recover
        if state.processedURLCount > 10 || state.downloadedFileCount > 5 {
            return .resume(state)
        }
        
        // Not enough progress, restart
        return .restart
    }
    
    /// Handle a recoverable error during crawling
    func handleError(_ error: Error, for url: URL) -> ErrorAction {
        // Categorize error
        let category = categorizeError(error)
        
        switch category {
        case .transient:
            // Retry with exponential backoff
            return .retry(delay: 5.0)
            
        case .permanent:
            // Skip this URL
            return .skip
            
        case .rateLimit:
            // Wait longer and retry
            return .retry(delay: 60.0)
            
        case .authentication:
            // Need user intervention
            return .pause(reason: "Authentication required")
            
        case .serverError:
            // Retry a few times, then skip
            return .retry(delay: 10.0, maxAttempts: 3)
            
        case .unknown:
            // Log and skip
            return .skip
        }
    }
    
    // MARK: - Private Methods
    
    private func categorizeError(_ error: Error) -> ErrorCategory {
        let nsError = error as NSError
        
        // Network errors
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorTimedOut,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorNotConnectedToInternet:
                return .transient
                
            case NSURLErrorUserAuthenticationRequired:
                return .authentication
                
            case NSURLErrorBadURL,
                 NSURLErrorUnsupportedURL,
                 NSURLErrorFileDoesNotExist:
                return .permanent
                
            default:
                return .unknown
            }
        }
        
        // HTTP errors
        if let httpError = error as? FetchError {
            switch httpError {
            case .httpError(let statusCode):
                switch statusCode {
                case 429:
                    return .rateLimit
                case 401, 403:
                    return .authentication
                case 404, 410:
                    return .permanent
                case 500...599:
                    return .serverError
                default:
                    return .unknown
                }
            case .timeout:
                return .transient
            default:
                return .unknown
            }
        }
        
        return .unknown
    }
}

// MARK: - Supporting Types

enum ErrorCategory {
    case transient      // Temporary, retry soon
    case permanent      // Won't work, skip
    case rateLimit      // Too many requests
    case authentication // Need credentials
    case serverError    // Server problem
    case unknown        // Can't categorize
}

enum ErrorAction {
    case retry(delay: TimeInterval, maxAttempts: Int = 5)
    case skip
    case pause(reason: String)
    case abort(reason: String)
}

// MARK: - Crash Recovery

extension ErrorRecovery {
    
    /// Call this on app launch to check for crash recovery
    func checkForCrashRecovery() -> CrashRecoveryResult? {
        guard let state = loadRecoveryState() else {
            return nil
        }
        
        // If there's a state but job wasn't marked as interrupted,
        // it likely crashed
        if !state.wasInterrupted {
            return CrashRecoveryResult(
                projectId: state.projectId,
                jobId: state.jobId,
                processedURLs: state.processedURLCount,
                downloadedFiles: state.downloadedFileCount,
                pendingURLs: state.pendingURLs.count,
                lastURL: state.lastProcessedURL
            )
        }
        
        return nil
    }
    
    struct CrashRecoveryResult {
        let projectId: UUID?
        let jobId: UUID?
        let processedURLs: Int
        let downloadedFiles: Int
        let pendingURLs: Int
        let lastURL: String?
        
        var description: String {
            """
            A previous scraping session was interrupted.
            
            Progress:
            - URLs processed: \(processedURLs)
            - Files downloaded: \(downloadedFiles)
            - URLs remaining: \(pendingURLs)
            
            Would you like to resume from where it left off?
            """
        }
    }
}
