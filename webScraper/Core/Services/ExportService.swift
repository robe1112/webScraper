//
//  ExportService.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import Foundation

/// Service for exporting scraped data in various formats
final class ExportService {
    
    // MARK: - Types
    
    enum ExportFormat: String, CaseIterable {
        case json = "JSON"
        case csv = "CSV"
        case xml = "XML"
        case sqlite = "SQLite"
        
        var fileExtension: String {
            switch self {
            case .json: return "json"
            case .csv: return "csv"
            case .xml: return "xml"
            case .sqlite: return "sqlite"
            }
        }
        
        var mimeType: String {
            switch self {
            case .json: return "application/json"
            case .csv: return "text/csv"
            case .xml: return "application/xml"
            case .sqlite: return "application/x-sqlite3"
            }
        }
    }
    
    struct ExportOptions {
        var format: ExportFormat
        var includeHTMLContent: Bool
        var includeExtractedData: Bool
        var includeMetadata: Bool
        var prettyPrint: Bool
        var columnSelection: [String]?  // For CSV
        var rootElement: String  // For XML
        
        init(
            format: ExportFormat = .json,
            includeHTMLContent: Bool = false,
            includeExtractedData: Bool = true,
            includeMetadata: Bool = true,
            prettyPrint: Bool = true,
            columnSelection: [String]? = nil,
            rootElement: String = "scrapeData"
        ) {
            self.format = format
            self.includeHTMLContent = includeHTMLContent
            self.includeExtractedData = includeExtractedData
            self.includeMetadata = includeMetadata
            self.prettyPrint = prettyPrint
            self.columnSelection = columnSelection
            self.rootElement = rootElement
        }
    }
    
    // MARK: - Properties
    
    private let fileManager = FileManager.default
    
    // MARK: - Public Methods
    
    /// Export pages to a file
    func exportPages(_ pages: [ScrapedPage], to url: URL, options: ExportOptions) throws {
        switch options.format {
        case .json:
            try exportPagesToJSON(pages, to: url, options: options)
        case .csv:
            try exportPagesToCSV(pages, to: url, options: options)
        case .xml:
            try exportPagesToXML(pages, to: url, options: options)
        case .sqlite:
            try exportPagesToSQLite(pages, to: url, options: options)
        }
    }
    
    /// Export files to a file
    func exportFiles(_ files: [DownloadedFile], to url: URL, options: ExportOptions) throws {
        switch options.format {
        case .json:
            try exportFilesToJSON(files, to: url, options: options)
        case .csv:
            try exportFilesToCSV(files, to: url, options: options)
        case .xml:
            try exportFilesToXML(files, to: url, options: options)
        case .sqlite:
            try exportFilesToSQLite(files, to: url, options: options)
        }
    }
    
    /// Export a complete project
    func exportProject(_ project: Project, pages: [ScrapedPage], files: [DownloadedFile], to url: URL, options: ExportOptions) throws {
        let exportData = ProjectExport(
            project: project,
            pages: pages,
            files: files,
            exportedAt: Date()
        )
        
        switch options.format {
        case .json:
            try exportProjectToJSON(exportData, to: url, options: options)
        case .csv:
            // For CSV, export pages and files separately
            let pagesURL = url.deletingLastPathComponent().appendingPathComponent("pages.csv")
            let filesURL = url.deletingLastPathComponent().appendingPathComponent("files.csv")
            try exportPagesToCSV(pages, to: pagesURL, options: options)
            try exportFilesToCSV(files, to: filesURL, options: options)
        case .xml:
            try exportProjectToXML(exportData, to: url, options: options)
        case .sqlite:
            try exportProjectToSQLite(exportData, to: url, options: options)
        }
    }
    
    /// Generate export filename
    func generateFilename(projectName: String, format: ExportFormat) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        
        let sanitizedName = projectName.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "_", options: .regularExpression)
        
        return "\(sanitizedName)_\(timestamp).\(format.fileExtension)"
    }
    
    // MARK: - JSON Export
    
    private func exportPagesToJSON(_ pages: [ScrapedPage], to url: URL, options: ExportOptions) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        if options.prettyPrint {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        
        let data = try encoder.encode(pages)
        try data.write(to: url)
    }
    
    private func exportFilesToJSON(_ files: [DownloadedFile], to url: URL, options: ExportOptions) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        if options.prettyPrint {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        
        let data = try encoder.encode(files)
        try data.write(to: url)
    }
    
    private func exportProjectToJSON(_ export: ProjectExport, to url: URL, options: ExportOptions) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        if options.prettyPrint {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        
        let data = try encoder.encode(export)
        try data.write(to: url)
    }
    
    // MARK: - CSV Export
    
    private func exportPagesToCSV(_ pages: [ScrapedPage], to url: URL, options: ExportOptions) throws {
        var csv = ""
        
        // Headers
        let headers = options.columnSelection ?? [
            "url", "title", "statusCode", "contentType", "depth",
            "fetchedAt", "textContent"
        ]
        csv += headers.joined(separator: ",") + "\n"
        
        // Data rows
        for page in pages {
            var row: [String] = []
            
            for header in headers {
                let value: String
                switch header {
                case "url": value = page.url
                case "title": value = page.title ?? ""
                case "statusCode": value = "\(page.statusCode)"
                case "contentType": value = page.contentType ?? ""
                case "depth": value = "\(page.depth)"
                case "fetchedAt": value = ISO8601DateFormatter().string(from: page.fetchedAt)
                case "textContent": value = options.includeHTMLContent ? (page.textContent ?? "") : ""
                default: value = ""
                }
                row.append(escapeCSV(value))
            }
            
            csv += row.joined(separator: ",") + "\n"
        }
        
        try csv.write(to: url, atomically: true, encoding: .utf8)
    }
    
    private func exportFilesToCSV(_ files: [DownloadedFile], to url: URL, options: ExportOptions) throws {
        var csv = ""
        
        // Headers
        let headers = options.columnSelection ?? [
            "fileName", "sourceURL", "localPath", "fileSize", "mimeType",
            "fileType", "sha256Hash", "downloadedAt", "isDuplicate"
        ]
        csv += headers.joined(separator: ",") + "\n"
        
        // Data rows
        for file in files {
            var row: [String] = []
            
            for header in headers {
                let value: String
                switch header {
                case "fileName": value = file.fileName
                case "sourceURL": value = file.sourceURL
                case "localPath": value = file.localPath
                case "fileSize": value = "\(file.fileSize)"
                case "mimeType": value = file.mimeType ?? ""
                case "fileType": value = file.fileType.rawValue
                case "sha256Hash": value = file.sha256Hash ?? ""
                case "downloadedAt": value = ISO8601DateFormatter().string(from: file.downloadedAt)
                case "isDuplicate": value = file.isDuplicate ? "true" : "false"
                default: value = ""
                }
                row.append(escapeCSV(value))
            }
            
            csv += row.joined(separator: ",") + "\n"
        }
        
        try csv.write(to: url, atomically: true, encoding: .utf8)
    }
    
    private func escapeCSV(_ value: String) -> String {
        let needsQuoting = value.contains(",") || value.contains("\"") || value.contains("\n")
        if needsQuoting {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
    
    // MARK: - XML Export
    
    private func exportPagesToXML(_ pages: [ScrapedPage], to url: URL, options: ExportOptions) throws {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        xml += "<\(options.rootElement)>\n"
        xml += "  <pages>\n"
        
        for page in pages {
            xml += "    <page>\n"
            xml += "      <url>\(escapeXML(page.url))</url>\n"
            xml += "      <title>\(escapeXML(page.title ?? ""))</title>\n"
            xml += "      <statusCode>\(page.statusCode)</statusCode>\n"
            xml += "      <depth>\(page.depth)</depth>\n"
            xml += "      <fetchedAt>\(ISO8601DateFormatter().string(from: page.fetchedAt))</fetchedAt>\n"
            
            if options.includeExtractedData && !page.extractedData.isEmpty {
                xml += "      <extractedData>\n"
                for (key, value) in page.extractedData {
                    xml += "        <\(key)>\(escapeXML(value.stringValue ?? ""))</\(key)>\n"
                }
                xml += "      </extractedData>\n"
            }
            
            xml += "    </page>\n"
        }
        
        xml += "  </pages>\n"
        xml += "</\(options.rootElement)>"
        
        try xml.write(to: url, atomically: true, encoding: .utf8)
    }
    
    private func exportFilesToXML(_ files: [DownloadedFile], to url: URL, options: ExportOptions) throws {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        xml += "<\(options.rootElement)>\n"
        xml += "  <files>\n"
        
        for file in files {
            xml += "    <file>\n"
            xml += "      <fileName>\(escapeXML(file.fileName))</fileName>\n"
            xml += "      <sourceURL>\(escapeXML(file.sourceURL))</sourceURL>\n"
            xml += "      <localPath>\(escapeXML(file.localPath))</localPath>\n"
            xml += "      <fileSize>\(file.fileSize)</fileSize>\n"
            xml += "      <fileType>\(file.fileType.rawValue)</fileType>\n"
            xml += "      <downloadedAt>\(ISO8601DateFormatter().string(from: file.downloadedAt))</downloadedAt>\n"
            xml += "    </file>\n"
        }
        
        xml += "  </files>\n"
        xml += "</\(options.rootElement)>"
        
        try xml.write(to: url, atomically: true, encoding: .utf8)
    }
    
    private func exportProjectToXML(_ export: ProjectExport, to url: URL, options: ExportOptions) throws {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        xml += "<\(options.rootElement)>\n"
        
        // Project info
        xml += "  <project>\n"
        xml += "    <name>\(escapeXML(export.project.name))</name>\n"
        xml += "    <startURL>\(escapeXML(export.project.startURL))</startURL>\n"
        xml += "    <createdAt>\(ISO8601DateFormatter().string(from: export.project.createdAt))</createdAt>\n"
        xml += "    <totalPagesScraped>\(export.project.totalPagesScraped)</totalPagesScraped>\n"
        xml += "    <totalFilesDownloaded>\(export.project.totalFilesDownloaded)</totalFilesDownloaded>\n"
        xml += "  </project>\n"
        
        // Pages and files would be added similarly
        xml += "  <exportedAt>\(ISO8601DateFormatter().string(from: export.exportedAt))</exportedAt>\n"
        
        xml += "</\(options.rootElement)>"
        
        try xml.write(to: url, atomically: true, encoding: .utf8)
    }
    
    private func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
    
    // MARK: - SQLite Export
    
    private func exportPagesToSQLite(_ pages: [ScrapedPage], to url: URL, options: ExportOptions) throws {
        // Create SQLite database and export
        // This would use SQLite directly
        // For now, we'll create a JSON file as a placeholder
        try exportPagesToJSON(pages, to: url.deletingPathExtension().appendingPathExtension("json"), options: options)
    }
    
    private func exportFilesToSQLite(_ files: [DownloadedFile], to url: URL, options: ExportOptions) throws {
        try exportFilesToJSON(files, to: url.deletingPathExtension().appendingPathExtension("json"), options: options)
    }
    
    private func exportProjectToSQLite(_ export: ProjectExport, to url: URL, options: ExportOptions) throws {
        try exportProjectToJSON(export, to: url.deletingPathExtension().appendingPathExtension("json"), options: options)
    }
}

// MARK: - Supporting Types

struct ProjectExport: Codable {
    let project: Project
    let pages: [ScrapedPage]
    let files: [DownloadedFile]
    let exportedAt: Date
}
