//
//  RateLimiter.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import Foundation

/// Rate limiter for controlling request frequency
/// Supports per-domain limits and adaptive throttling
actor RateLimiter {
    
    // MARK: - Configuration
    
    struct Configuration {
        var defaultDelayMs: Int
        var maxConcurrentRequests: Int
        var perDomainLimits: [String: Int]  // domain -> delay in ms
        var adaptiveThrottling: Bool
        var maxRetryDelay: Int
        
        init(
            defaultDelayMs: Int = 1000,
            maxConcurrentRequests: Int = 4,
            perDomainLimits: [String: Int] = [:],
            adaptiveThrottling: Bool = true,
            maxRetryDelay: Int = 30000
        ) {
            self.defaultDelayMs = defaultDelayMs
            self.maxConcurrentRequests = maxConcurrentRequests
            self.perDomainLimits = perDomainLimits
            self.adaptiveThrottling = adaptiveThrottling
            self.maxRetryDelay = maxRetryDelay
        }
    }
    
    // MARK: - Properties
    
    private var configuration: Configuration
    private var lastRequestTime: [String: Date] = [:]  // domain -> last request time
    private var activeRequests: [String: Int] = [:]  // domain -> active count
    private var domainDelays: [String: Int] = [:]  // adaptive delays per domain
    private var errorCounts: [String: Int] = [:]  // for adaptive throttling
    
    // MARK: - Initialization
    
    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }
    
    // MARK: - Public Methods
    
    /// Update configuration
    func updateConfiguration(_ config: Configuration) {
        self.configuration = config
    }
    
    /// Wait for rate limit before making a request
    /// Returns true if request can proceed, false if should abort
    func waitForSlot(url: URL) async -> Bool {
        guard let domain = url.host else { return true }
        
        // Check concurrent request limit
        let active = activeRequests[domain] ?? 0
        if active >= configuration.maxConcurrentRequests {
            // Wait for a slot to open
            try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
            return await waitForSlot(url: url)
        }
        
        // Calculate required delay
        let delay = getDelay(for: domain)
        
        // Check time since last request
        if let lastTime = lastRequestTime[domain] {
            let elapsed = Date().timeIntervalSince(lastTime) * 1000  // ms
            let remainingDelay = Double(delay) - elapsed
            
            if remainingDelay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(remainingDelay * 1_000_000))
            }
        }
        
        // Record request
        lastRequestTime[domain] = Date()
        activeRequests[domain] = active + 1
        
        return true
    }
    
    /// Mark a request as completed
    func requestCompleted(url: URL, statusCode: Int, responseTime: TimeInterval) {
        guard let domain = url.host else { return }
        
        // Decrement active count
        let active = activeRequests[domain] ?? 1
        activeRequests[domain] = max(0, active - 1)
        
        // Adaptive throttling
        if configuration.adaptiveThrottling {
            updateAdaptiveDelay(domain: domain, statusCode: statusCode, responseTime: responseTime)
        }
    }
    
    /// Get current delay for a domain
    func getDelay(for domain: String) -> Int {
        // Check per-domain override
        if let customDelay = configuration.perDomainLimits[domain] {
            return customDelay
        }
        
        // Check adaptive delay
        if let adaptiveDelay = domainDelays[domain] {
            return adaptiveDelay
        }
        
        return configuration.defaultDelayMs
    }
    
    /// Reset rate limiter state
    func reset() {
        lastRequestTime.removeAll()
        activeRequests.removeAll()
        domainDelays.removeAll()
        errorCounts.removeAll()
    }
    
    /// Get statistics
    func getStats() -> RateLimiterStats {
        RateLimiterStats(
            activeDomains: activeRequests.keys.count,
            totalActiveRequests: activeRequests.values.reduce(0, +),
            domainDelays: domainDelays,
            errorCounts: errorCounts
        )
    }
    
    // MARK: - Private Methods
    
    private func updateAdaptiveDelay(domain: String, statusCode: Int, responseTime: TimeInterval) {
        let currentDelay = domainDelays[domain] ?? configuration.defaultDelayMs
        
        switch statusCode {
        case 200..<300:
            // Success - gradually reduce delay
            errorCounts[domain] = 0
            let newDelay = max(configuration.defaultDelayMs, Int(Double(currentDelay) * 0.9))
            domainDelays[domain] = newDelay
            
        case 429:  // Too Many Requests
            // Significantly increase delay
            let errors = (errorCounts[domain] ?? 0) + 1
            errorCounts[domain] = errors
            let multiplier = min(Double(errors), 5.0)
            let newDelay = min(configuration.maxRetryDelay, Int(Double(currentDelay) * (1.5 + multiplier * 0.5)))
            domainDelays[domain] = newDelay
            
        case 500..<600:
            // Server error - moderate increase
            let errors = (errorCounts[domain] ?? 0) + 1
            errorCounts[domain] = errors
            let newDelay = min(configuration.maxRetryDelay, Int(Double(currentDelay) * 1.5))
            domainDelays[domain] = newDelay
            
        default:
            break
        }
        
        // Also consider response time
        if responseTime > 5.0 {  // Slow response
            let newDelay = min(configuration.maxRetryDelay, Int(Double(currentDelay) * 1.2))
            domainDelays[domain] = newDelay
        }
    }
}

// MARK: - Statistics

struct RateLimiterStats {
    let activeDomains: Int
    let totalActiveRequests: Int
    let domainDelays: [String: Int]
    let errorCounts: [String: Int]
}
