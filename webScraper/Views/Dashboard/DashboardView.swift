//
//  DashboardView.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import SwiftUI
import Charts

/// Statistics dashboard showing project and job metrics
struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var timeRange: TimeRange = .week
    @State private var projects: [Project] = []
    @State private var recentJobs: [ScrapeJob] = []
    
    enum TimeRange: String, CaseIterable {
        case day = "24h"
        case week = "7d"
        case month = "30d"
        case all = "All"
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Time range picker
                Picker("Time Range", selection: $timeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                
                // Overview cards
                overviewSection
                
                // Charts section
                chartsSection
                
                // Recent activity
                recentActivitySection
                
                // Storage section
                storageSection
            }
            .padding()
        }
        .navigationTitle("Dashboard")
        .task {
            await loadData()
        }
    }
    
    // MARK: - Overview Section
    
    private var overviewSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            DashboardCard(
                title: "Projects",
                value: "\(projects.count)",
                icon: "folder.fill",
                color: .blue
            )
            
            DashboardCard(
                title: "Pages Scraped",
                value: formatNumber(totalPagesScraped),
                icon: "doc.text.fill",
                color: .green
            )
            
            DashboardCard(
                title: "Files Downloaded",
                value: formatNumber(totalFilesDownloaded),
                icon: "arrow.down.circle.fill",
                color: .purple
            )
            
            DashboardCard(
                title: "Total Storage",
                value: formatBytes(totalStorageBytes),
                icon: "internaldrive.fill",
                color: .orange
            )
        }
    }
    
    // MARK: - Charts Section
    
    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Activity")
                .font(.headline)
            
            HStack(spacing: 24) {
                // Pages over time chart
                VStack(alignment: .leading) {
                    Text("Pages Scraped")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Chart {
                        ForEach(mockChartData, id: \.date) { item in
                            BarMark(
                                x: .value("Date", item.date, unit: .day),
                                y: .value("Pages", item.pages)
                            )
                            .foregroundStyle(.blue.gradient)
                        }
                    }
                    .frame(height: 150)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                
                // Files over time chart
                VStack(alignment: .leading) {
                    Text("Files Downloaded")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Chart {
                        ForEach(mockChartData, id: \.date) { item in
                            LineMark(
                                x: .value("Date", item.date, unit: .day),
                                y: .value("Files", item.files)
                            )
                            .foregroundStyle(.purple)
                            
                            AreaMark(
                                x: .value("Date", item.date, unit: .day),
                                y: .value("Files", item.files)
                            )
                            .foregroundStyle(.purple.opacity(0.2))
                        }
                    }
                    .frame(height: 150)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    // MARK: - Recent Activity Section
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Jobs")
                    .font(.headline)
                
                Spacer()
                
                Button("View All") {
                    appState.selectedSidebarItem = .activeJobs
                }
                .buttonStyle(.link)
            }
            
            if recentJobs.isEmpty {
                ContentUnavailableView(
                    "No Recent Jobs",
                    systemImage: "clock",
                    description: Text("Jobs you run will appear here")
                )
                .frame(height: 150)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(recentJobs.prefix(5)) { job in
                        RecentJobRow(job: job)
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Storage Section
    
    private var storageSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Storage by Type")
                .font(.headline)
            
            HStack(spacing: 24) {
                // Pie chart
                Chart(storageByType, id: \.type) { item in
                    SectorMark(
                        angle: .value("Size", item.size),
                        innerRadius: .ratio(0.5),
                        angularInset: 1
                    )
                    .foregroundStyle(by: .value("Type", item.type))
                    .cornerRadius(4)
                }
                .frame(width: 200, height: 200)
                
                // Legend
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(storageByType, id: \.type) { item in
                        HStack {
                            Circle()
                                .fill(item.color)
                                .frame(width: 12, height: 12)
                            
                            Text(item.type)
                            
                            Spacer()
                            
                            Text(formatBytes(item.size))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: 200)
                
                Spacer()
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Helper Properties
    
    private var totalPagesScraped: Int {
        projects.reduce(0) { $0 + $1.totalPagesScraped }
    }
    
    private var totalFilesDownloaded: Int {
        projects.reduce(0) { $0 + $1.totalFilesDownloaded }
    }
    
    private var totalStorageBytes: Int64 {
        projects.reduce(0) { $0 + $1.totalSizeBytes }
    }
    
    private var mockChartData: [ChartDataPoint] {
        let calendar = Calendar.current
        var data: [ChartDataPoint] = []
        
        for i in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!
            data.append(ChartDataPoint(
                date: date,
                pages: Int.random(in: 10...100),
                files: Int.random(in: 5...50)
            ))
        }
        
        return data.reversed()
    }
    
    private var storageByType: [StorageItem] {
        [
            StorageItem(type: "PDFs", size: Int64.random(in: 100_000_000...500_000_000), color: .red),
            StorageItem(type: "Images", size: Int64.random(in: 50_000_000...200_000_000), color: .blue),
            StorageItem(type: "Documents", size: Int64.random(in: 10_000_000...100_000_000), color: .green),
            StorageItem(type: "Audio", size: Int64.random(in: 20_000_000...80_000_000), color: .orange),
            StorageItem(type: "Video", size: Int64.random(in: 200_000_000...1_000_000_000), color: .purple)
        ]
    }
    
    // MARK: - Helper Methods
    
    private func loadData() async {
        do {
            projects = try await appState.loadProjects()
        } catch {
            // Handle error
        }
    }
    
    private func formatNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000)
        } else if number >= 1_000 {
            return String(format: "%.1fK", Double(number) / 1_000)
        }
        return "\(number)"
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - Supporting Views

struct DashboardCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct RecentJobRow: View {
    let job: ScrapeJob
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: job.status.icon)
                .foregroundStyle(colorForStatus(job.status))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(job.startURL)
                    .lineLimit(1)
                
                Text(job.startedAt?.formatted(date: .abbreviated, time: .shortened) ?? "Not started")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(job.pagesScraped) pages")
                    .font(.caption)
                
                Text("\(job.filesDownloaded) files")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func colorForStatus(_ status: JobStatus) -> Color {
        switch status {
        case .completed: return .green
        case .failed: return .red
        case .running: return .blue
        case .paused: return .orange
        default: return .secondary
        }
    }
}

// MARK: - Supporting Types

private struct ChartDataPoint {
    let date: Date
    let pages: Int
    let files: Int
}

private struct StorageItem {
    let type: String
    let size: Int64
    let color: Color
}

// MARK: - Preview

#Preview {
    DashboardView()
        .environmentObject(AppState())
}
