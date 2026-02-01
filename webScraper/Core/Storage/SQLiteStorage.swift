//
//  SQLiteStorage.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import Foundation
import SQLite3

/// SQLite implementation of StorageProvider
/// Lightweight and portable, good for simple storage needs
@MainActor
final class SQLiteStorage: StorageProvider {
    
    // MARK: - Properties
    
    /// SQLite handle - nonisolated(unsafe) to allow use from queue.async Sendable closures
    private nonisolated(unsafe) var db: OpaquePointer?
    private let dbPath: String
    private let queue = DispatchQueue(label: "com.webScraper.sqlite", qos: .userInitiated)
    
    // Table names for each type
    private let tableNames: [String: String] = [
        "Project": "projects",
        "ScrapeJob": "scrape_jobs",
        "ScrapedPage": "scraped_pages",
        "DownloadedFile": "downloaded_files",
        "SiteNode": "site_nodes",
        "ExtractionRule": "extraction_rules"
    ]
    
    // MARK: - Initialization
    
    init(databaseName: String = "webScraper.sqlite") {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        dbPath = documentsPath.appendingPathComponent(databaseName).path
        
        openDatabase()
        createTables()
    }
    
    deinit {
        sqlite3_close(db)
    }
    
    // MARK: - Database Setup
    
    private func openDatabase() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("Error opening database: \(String(cString: sqlite3_errmsg(db)))")
        }
    }
    
    private func createTables() {
        for tableName in tableNames.values {
            let createSQL = """
                CREATE TABLE IF NOT EXISTS \(tableName) (
                    id TEXT PRIMARY KEY,
                    json_data TEXT NOT NULL,
                    created_at REAL NOT NULL,
                    updated_at REAL NOT NULL
                )
            """
            executeSQL(createSQL)
        }
    }
    
    private func executeSQL(_ sql: String) {
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) != SQLITE_DONE {
                print("SQL execution error: \(String(cString: sqlite3_errmsg(db)))")
            }
        }
        sqlite3_finalize(statement)
    }
    
    // MARK: - StorageProvider Implementation
    
    func save<T: Codable & Identifiable>(_ item: T) async throws {
        let tableName = self.tableName(for: T.self)
        let dbPointer = db
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    let data = try JSONEncoder().encode(item)
                    guard let jsonString = String(data: data, encoding: .utf8) else {
                        throw StorageError.invalidData
                    }
                    let now = Date().timeIntervalSince1970
                    
                    let sql = """
                        INSERT OR REPLACE INTO \(tableName) (id, json_data, created_at, updated_at)
                        VALUES (?, ?, COALESCE((SELECT created_at FROM \(tableName) WHERE id = ?), ?), ?)
                    """
                    
                    var statement: OpaquePointer?
                    if sqlite3_prepare_v2(dbPointer, sql, -1, &statement, nil) == SQLITE_OK {
                        let idString = "\(item.id)"
                        sqlite3_bind_text(statement, 1, idString, -1, nil)
                        sqlite3_bind_text(statement, 2, jsonString, -1, nil)
                        sqlite3_bind_text(statement, 3, idString, -1, nil)
                        sqlite3_bind_double(statement, 4, now)
                        sqlite3_bind_double(statement, 5, now)
                        
                        if sqlite3_step(statement) != SQLITE_DONE {
                            sqlite3_finalize(statement)
                            throw StorageError.saveFailed(NSError(domain: "SQLite", code: -1))
                        }
                    }
                    sqlite3_finalize(statement)
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func fetch<T: Codable & Identifiable>(predicate: NSPredicate?) async throws -> [T] {
        let tableName = self.tableName(for: T.self)
        let whereClause = predicate.map { " WHERE \(self.predicateToSQL($0))" } ?? ""
        let sql = "SELECT json_data FROM \(tableName)\(whereClause)"
        let dbPointer = db
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                var statement: OpaquePointer?
                var results: [T] = []
                if sqlite3_prepare_v2(dbPointer, sql, -1, &statement, nil) == SQLITE_OK {
                    while sqlite3_step(statement) == SQLITE_ROW {
                        if let jsonText = sqlite3_column_text(statement, 0) {
                            let jsonString = String(cString: jsonText)
                            if let data = jsonString.data(using: .utf8),
                               let item = try? JSONDecoder().decode(T.self, from: data) {
                                results.append(item)
                            }
                        }
                    }
                }
                sqlite3_finalize(statement)
                continuation.resume(returning: results)
            }
        }
    }
    
    func fetchById<T: Codable & Identifiable>(_ id: T.ID, type: T.Type) async throws -> T? {
        let tableName = self.tableName(for: T.self)
        let sql = "SELECT json_data FROM \(tableName) WHERE id = ?"
        let dbPointer = db
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                var statement: OpaquePointer?
                var result: T?
                if sqlite3_prepare_v2(dbPointer, sql, -1, &statement, nil) == SQLITE_OK {
                    sqlite3_bind_text(statement, 1, "\(id)", -1, nil)
                    
                    if sqlite3_step(statement) == SQLITE_ROW {
                        if let jsonText = sqlite3_column_text(statement, 0) {
                            let jsonString = String(cString: jsonText)
                            if let data = jsonString.data(using: .utf8) {
                                result = try? JSONDecoder().decode(T.self, from: data)
                            }
                        }
                    }
                }
                sqlite3_finalize(statement)
                
                continuation.resume(returning: result)
            }
        }
    }
    
    func delete<T: Codable & Identifiable>(_ item: T) async throws {
        let tableName = self.tableName(for: T.self)
        let sql = "DELETE FROM \(tableName) WHERE id = ?"
        let dbPointer = db
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                var statement: OpaquePointer?
                if sqlite3_prepare_v2(dbPointer, sql, -1, &statement, nil) == SQLITE_OK {
                    sqlite3_bind_text(statement, 1, "\(item.id)", -1, nil)
                    
                    if sqlite3_step(statement) != SQLITE_DONE {
                        sqlite3_finalize(statement)
                        continuation.resume(throwing: StorageError.deleteFailed(NSError(domain: "SQLite", code: -1)))
                        return
                    }
                }
                sqlite3_finalize(statement)
                
                continuation.resume()
            }
        }
    }
    
    func deleteWhere<T: Codable & Identifiable>(type: T.Type, predicate: NSPredicate) async throws {
        let tableName = self.tableName(for: T.self)
        let whereSQL = self.predicateToSQL(predicate)
        let sql = "DELETE FROM \(tableName) WHERE \(whereSQL)"
        let dbPointer = db
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                var statement: OpaquePointer?
                if sqlite3_prepare_v2(dbPointer, sql, -1, &statement, nil) == SQLITE_OK {
                    sqlite3_step(statement)
                }
                sqlite3_finalize(statement)
                continuation.resume()
            }
        }
    }
    
    func update<T: Codable & Identifiable>(_ item: T) async throws {
        try await save(item)
    }
    
    func count<T: Codable & Identifiable>(type: T.Type, predicate: NSPredicate?) async throws -> Int {
        let tableName = self.tableName(for: T.self)
        let whereClause = predicate.map { " WHERE \(self.predicateToSQL($0))" } ?? ""
        let sql = "SELECT COUNT(*) FROM \(tableName)\(whereClause)"
        let dbPointer = db
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                var statement: OpaquePointer?
                var count = 0
                if sqlite3_prepare_v2(dbPointer, sql, -1, &statement, nil) == SQLITE_OK {
                    if sqlite3_step(statement) == SQLITE_ROW {
                        count = Int(sqlite3_column_int(statement, 0))
                    }
                }
                sqlite3_finalize(statement)
                continuation.resume(returning: count)
            }
        }
    }
    
    func observe<T: Codable & Identifiable>(type: T.Type, predicate: NSPredicate?) -> AsyncStream<[T]> {
        AsyncStream { continuation in
            Task {
                // Initial fetch
                do {
                    let items: [T] = try await self.fetch(predicate: predicate)
                    continuation.yield(items)
                } catch {
                    // Continue without yielding
                }
                
                // SQLite doesn't have built-in change notifications
                // For now, just yield the initial result
                // A production implementation would use polling or external notifications
            }
        }
    }
    
    func clearAll() async throws {
        let tableNamesToClear = tableNames.values.map { $0 }
        let dbPointer = db
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                for tableName in tableNamesToClear {
                    var statement: OpaquePointer?
                    let sql = "DELETE FROM \(tableName)"
                    if sqlite3_prepare_v2(dbPointer, sql, -1, &statement, nil) == SQLITE_OK {
                        sqlite3_step(statement)
                    }
                    sqlite3_finalize(statement)
                }
                continuation.resume()
            }
        }
    }
    
    func export(to url: URL) async throws {
        // Copy database file
        try FileManager.default.copyItem(atPath: dbPath, toPath: url.path)
    }
    
    func `import`(from url: URL) async throws {
        // Replace database file
        sqlite3_close(db)
        try FileManager.default.removeItem(atPath: dbPath)
        try FileManager.default.copyItem(atPath: url.path, toPath: dbPath)
        openDatabase()
    }
    
    // MARK: - Private Methods
    
    private func tableName<T>(for type: T.Type) -> String {
        let typeName = String(describing: type)
        return tableNames[typeName] ?? typeName.lowercased() + "s"
    }
    
    private func predicateToSQL(_ predicate: NSPredicate) -> String {
        // Simplified predicate conversion
        // This handles basic cases; a production implementation would be more robust
        let predicateString = predicate.predicateFormat
        
        // Convert NSPredicate format to SQL
        let sql = predicateString
            .replacingOccurrences(of: "==", with: "=")
            .replacingOccurrences(of: "CONTAINS", with: "LIKE")
            .replacingOccurrences(of: "BEGINSWITH", with: "LIKE")
        
        // Handle JSON field access (simplified)
        // In production, you'd use json_extract()
        if sql.contains("id =") {
            // ID is stored as a separate column
            return sql
        }
        
        return sql
    }
}
