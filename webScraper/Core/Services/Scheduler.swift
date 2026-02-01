//
//  Scheduler.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import Foundation
import Combine
import UserNotifications

/// Manages scheduled and recurring scrape jobs
/// Supports cron-like scheduling with background execution
@MainActor
final class Scheduler: ObservableObject {
    
    // MARK: - Types
    
    struct ScheduledJob: Identifiable, Codable {
        let id: UUID
        var projectId: UUID
        var name: String
        var schedule: JobSchedule
        var isEnabled: Bool
        var lastRunAt: Date?
        var nextRunAt: Date?
        var lastRunStatus: RunStatus?
        var runCount: Int
        
        enum RunStatus: String, Codable {
            case success
            case failed
            case cancelled
        }
    }
    
    // MARK: - Published Properties
    
    @Published private(set) var scheduledJobs: [ScheduledJob] = []
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var currentlyRunningJobId: UUID?
    
    // MARK: - Properties
    
    private var timers: [UUID: Timer] = [:]
    private var cancellables = Set<AnyCancellable>()
    private let storageKey = "scheduler.jobs"
    
    // Callback for running a job
    var onRunJob: ((UUID) async throws -> Void)?
    
    // MARK: - Initialization
    
    init() {
        loadJobs()
        scheduleAllJobs()
        requestNotificationPermission()
    }
    
    // MARK: - Public Methods
    
    /// Add a scheduled job
    func addJob(_ job: ScheduledJob) {
        scheduledJobs.append(job)
        saveJobs()
        
        if job.isEnabled {
            scheduleJob(job)
        }
    }
    
    /// Update a scheduled job
    func updateJob(_ job: ScheduledJob) {
        guard let index = scheduledJobs.firstIndex(where: { $0.id == job.id }) else { return }
        
        // Cancel existing timer
        timers[job.id]?.invalidate()
        timers.removeValue(forKey: job.id)
        
        scheduledJobs[index] = job
        saveJobs()
        
        if job.isEnabled {
            scheduleJob(job)
        }
    }
    
    /// Remove a scheduled job
    func removeJob(id: UUID) {
        timers[id]?.invalidate()
        timers.removeValue(forKey: id)
        
        scheduledJobs.removeAll { $0.id == id }
        saveJobs()
    }
    
    /// Enable/disable a job
    func setJobEnabled(id: UUID, enabled: Bool) {
        guard var job = scheduledJobs.first(where: { $0.id == id }) else { return }
        
        job.isEnabled = enabled
        updateJob(job)
    }
    
    /// Manually trigger a job
    func triggerJob(id: UUID) {
        guard let job = scheduledJobs.first(where: { $0.id == id }) else { return }
        
        Task {
            await runJob(job)
        }
    }
    
    /// Get the next run time for a job
    func getNextRunTime(for schedule: JobSchedule) -> Date? {
        calculateNextRunTime(schedule: schedule)
    }
    
    /// Get all jobs for a project
    func getJobs(forProject projectId: UUID) -> [ScheduledJob] {
        scheduledJobs.filter { $0.projectId == projectId }
    }
    
    // MARK: - Private Methods
    
    private func loadJobs() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let jobs = try? JSONDecoder().decode([ScheduledJob].self, from: data) else {
            return
        }
        scheduledJobs = jobs
    }
    
    private func saveJobs() {
        guard let data = try? JSONEncoder().encode(scheduledJobs) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
    
    private func scheduleAllJobs() {
        for job in scheduledJobs where job.isEnabled {
            scheduleJob(job)
        }
    }
    
    private func scheduleJob(_ job: ScheduledJob) {
        guard let nextRun = calculateNextRunTime(schedule: job.schedule) else { return }
        
        // Update next run time
        if var updatedJob = scheduledJobs.first(where: { $0.id == job.id }),
           let index = scheduledJobs.firstIndex(where: { $0.id == job.id }) {
            updatedJob.nextRunAt = nextRun
            scheduledJobs[index] = updatedJob
        }
        
        // Schedule timer
        let timeInterval = nextRun.timeIntervalSinceNow
        guard timeInterval > 0 else {
            // Run immediately if past due
            Task {
                await runJob(job)
            }
            return
        }
        
        let timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.runJob(job)
            }
        }
        
        timers[job.id] = timer
    }
    
    private func runJob(_ job: ScheduledJob) async {
        guard !isRunning else { return }
        
        isRunning = true
        currentlyRunningJobId = job.id
        
        // Update job status
        var updatedJob = job
        updatedJob.lastRunAt = Date()
        updatedJob.runCount += 1
        
        do {
            // Call the job runner
            try await onRunJob?(job.projectId)
            
            updatedJob.lastRunStatus = .success
            sendNotification(title: "Scrape Completed", body: "Job '\(job.name)' completed successfully")
            
        } catch {
            updatedJob.lastRunStatus = .failed
            sendNotification(title: "Scrape Failed", body: "Job '\(job.name)' failed: \(error.localizedDescription)")
        }
        
        isRunning = false
        currentlyRunningJobId = nil
        
        // Schedule next run
        if updatedJob.isEnabled {
            updatedJob.nextRunAt = calculateNextRunTime(schedule: updatedJob.schedule)
            updateJob(updatedJob)
        } else {
            updateJob(updatedJob)
        }
    }
    
    private func calculateNextRunTime(schedule: JobSchedule) -> Date? {
        guard schedule.isEnabled else { return nil }
        
        let calendar = Calendar.current
        let now = Date()
        
        // Get time components from schedule
        let timeComponents = calendar.dateComponents([.hour, .minute], from: schedule.time)
        
        switch schedule.frequency {
        case .hourly:
            // Next hour at the same minute
            var components = calendar.dateComponents([.year, .month, .day, .hour], from: now)
            components.minute = timeComponents.minute
            
            guard var nextDate = calendar.date(from: components) else { return nil }
            
            if nextDate <= now {
                nextDate = calendar.date(byAdding: .hour, value: 1, to: nextDate) ?? nextDate
            }
            return nextDate
            
        case .daily:
            // Same time tomorrow (or today if not yet)
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = timeComponents.hour
            components.minute = timeComponents.minute
            
            guard var nextDate = calendar.date(from: components) else { return nil }
            
            if nextDate <= now {
                nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate) ?? nextDate
            }
            return nextDate
            
        case .weekly:
            // Find next matching day of week
            var nextDate = now
            let targetDays = Set(schedule.daysOfWeek)
            
            for _ in 0..<8 {  // Check up to 8 days ahead
                let weekday = calendar.component(.weekday, from: nextDate)
                
                if targetDays.contains(weekday) {
                    var components = calendar.dateComponents([.year, .month, .day], from: nextDate)
                    components.hour = timeComponents.hour
                    components.minute = timeComponents.minute
                    
                    if let candidate = calendar.date(from: components), candidate > now {
                        return candidate
                    }
                }
                
                nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate) ?? nextDate
            }
            return nil
            
        case .monthly:
            // Same day next month
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = timeComponents.hour
            components.minute = timeComponents.minute
            
            guard var nextDate = calendar.date(from: components) else { return nil }
            
            if nextDate <= now {
                nextDate = calendar.date(byAdding: .month, value: 1, to: nextDate) ?? nextDate
            }
            return nextDate
            
        case .custom:
            // Custom would need more complex cron parsing
            // For now, default to daily
            return calculateNextRunTime(schedule: JobSchedule(
                isEnabled: true,
                frequency: .daily,
                time: schedule.time
            ))
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
    
    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}
