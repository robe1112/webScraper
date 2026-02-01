//
//  FileListView.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import SwiftUI

/// View for displaying and managing downloaded files
struct FileListView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var files: [DownloadedFile] = []
    @State private var searchText = ""
    @State private var sortOrder: SortOrder = .dateDesc
    @State private var filterType: FileType? = nil
    @State private var selectedFiles: Set<UUID> = []
    @State private var showDuplicatesOnly = false
    
    enum SortOrder: String, CaseIterable {
        case nameAsc = "Name (A-Z)"
        case nameDesc = "Name (Z-A)"
        case dateAsc = "Date (Oldest)"
        case dateDesc = "Date (Newest)"
        case sizeAsc = "Size (Smallest)"
        case sizeDesc = "Size (Largest)"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            filterToolbar
            
            Divider()
            
            // File list
            if filteredFiles.isEmpty {
                emptyState
            } else {
                fileTable
            }
            
            Divider()
            
            // Status bar
            statusBar
        }
        .navigationTitle("Downloads")
    }
    
    // MARK: - Filter Toolbar
    
    private var filterToolbar: some View {
        HStack(spacing: 12) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search files...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .frame(maxWidth: 250)
            
            // File type filter
            Picker("Type", selection: $filterType) {
                Text("All Types").tag(nil as FileType?)
                Divider()
                ForEach(FileType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type as FileType?)
                }
            }
            .frame(width: 140)
            
            // Sort order
            Picker("Sort", selection: $sortOrder) {
                ForEach(SortOrder.allCases, id: \.self) { order in
                    Text(order.rawValue).tag(order)
                }
            }
            .frame(width: 150)
            
            // Duplicates toggle
            Toggle("Duplicates Only", isOn: $showDuplicatesOnly)
            
            Spacer()
            
            // Actions
            Button(action: {}) {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .disabled(selectedFiles.isEmpty)
        }
        .padding()
    }
    
    // MARK: - File Table
    
    private var fileTable: some View {
        Table(of: DownloadedFile.self, selection: $selectedFiles) {
            TableColumn("") { file in
                Image(systemName: iconForFileType(file.fileType))
                    .foregroundStyle(colorForFileType(file.fileType))
            }
            .width(30)
            
            TableColumn("Name", value: \.fileName)
                .width(min: 150, ideal: 200)
            
            TableColumn("Type", value: \.fileType.rawValue)
                .width(80)
            
            TableColumn("Size") { file in
                Text(file.formattedSize)
            }
            .width(80)
            
            TableColumn("Downloaded") { file in
                Text(file.downloadedAt.formatted(date: .abbreviated, time: .shortened))
            }
            .width(150)
            
            TableColumn("Status") { file in
                HStack(spacing: 4) {
                    Image(systemName: file.downloadStatus.icon)
                        .foregroundStyle(colorForStatus(file.downloadStatus))
                    
                    if file.isDuplicate {
                        Image(systemName: "doc.on.doc")
                            .foregroundStyle(.orange)
                            .help("Duplicate file")
                    }
                }
            }
            .width(60)
        } rows: {
            ForEach(filteredFiles) { file in
                TableRow(file)
                    .contextMenu {
                        fileContextMenu(for: file)
                    }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        ContentUnavailableView(
            searchText.isEmpty ? "No Downloads" : "No Results",
            systemImage: searchText.isEmpty ? "arrow.down.circle" : "magnifyingglass",
            description: Text(searchText.isEmpty 
                ? "Downloaded files will appear here" 
                : "No files match your search")
        )
    }
    
    // MARK: - Status Bar
    
    private var statusBar: some View {
        HStack {
            Text("\(filteredFiles.count) files")
            
            Divider()
                .frame(height: 12)
            
            Text(totalSizeFormatted)
            
            if !selectedFiles.isEmpty {
                Divider()
                    .frame(height: 12)
                
                Text("\(selectedFiles.count) selected")
            }
            
            Spacer()
            
            if showDuplicatesOnly {
                Text("\(duplicateCount) duplicates")
                    .foregroundStyle(.orange)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private func fileContextMenu(for file: DownloadedFile) -> some View {
        Button("Open") {
            if let url = file.fileURL {
                NSWorkspace.shared.open(url)
            }
        }
        
        Button("Show in Finder") {
            if let url = file.fileURL {
                NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
            }
        }
        
        Divider()
        
        Button("Copy URL") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(file.sourceURL, forType: .string)
        }
        
        Button("Copy Path") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(file.localPath, forType: .string)
        }
        
        Divider()
        
        if appState.featureFlags.analysisPackEnabled {
            Button("Generate Summary") {
                // Trigger AI summary
            }
            
            Button("Extract Text (OCR)") {
                // Trigger OCR
            }
            
            Divider()
        }
        
        Button("Delete", role: .destructive) {
            // Delete file
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredFiles: [DownloadedFile] {
        var result = files
        
        // Filter by type
        if let filterType = filterType {
            result = result.filter { $0.fileType == filterType }
        }
        
        // Filter duplicates
        if showDuplicatesOnly {
            result = result.filter { $0.isDuplicate }
        }
        
        // Search
        if !searchText.isEmpty {
            result = result.filter {
                $0.fileName.localizedCaseInsensitiveContains(searchText) ||
                $0.sourceURL.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort
        switch sortOrder {
        case .nameAsc:
            result.sort { $0.fileName < $1.fileName }
        case .nameDesc:
            result.sort { $0.fileName > $1.fileName }
        case .dateAsc:
            result.sort { $0.downloadedAt < $1.downloadedAt }
        case .dateDesc:
            result.sort { $0.downloadedAt > $1.downloadedAt }
        case .sizeAsc:
            result.sort { $0.fileSize < $1.fileSize }
        case .sizeDesc:
            result.sort { $0.fileSize > $1.fileSize }
        }
        
        return result
    }
    
    private var totalSizeFormatted: String {
        let total = filteredFiles.reduce(Int64(0)) { $0 + $1.fileSize }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }
    
    private var duplicateCount: Int {
        files.filter { $0.isDuplicate }.count
    }
    
    // MARK: - Helper Methods
    
    private func iconForFileType(_ type: FileType) -> String {
        switch type {
        case .image: return "photo"
        case .pdf: return "doc.richtext"
        case .document: return "doc"
        case .audio: return "waveform"
        case .video: return "film"
        case .archive: return "archivebox"
        case .other: return "doc"
        }
    }
    
    private func colorForFileType(_ type: FileType) -> Color {
        switch type {
        case .image: return .blue
        case .pdf: return .red
        case .document: return .orange
        case .audio: return .purple
        case .video: return .pink
        case .archive: return .yellow
        case .other: return .gray
        }
    }
    
    private func colorForStatus(_ status: DownloadStatus) -> Color {
        switch status {
        case .completed: return .green
        case .failed: return .red
        case .downloading: return .blue
        case .pending: return .orange
        case .cancelled: return .gray
        case .skipped: return .purple
        }
    }
}

// MARK: - Preview

#Preview {
    FileListView()
        .environmentObject(AppState())
}
