//
//  StorageProtocol.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import Foundation

/// Protocol for storage providers
/// Allows switching between Core Data, SQLite, and file-based storage
protocol StorageProvider {
    
    /// Save an item to storage
    func save<T: Codable & Identifiable>(_ item: T) async throws
    
    /// Save multiple items to storage
    func saveAll<T: Codable & Identifiable>(_ items: [T]) async throws
    
    /// Fetch items matching a predicate
    func fetch<T: Codable & Identifiable>(predicate: NSPredicate?) async throws -> [T]
    
    /// Fetch a single item by ID
    func fetchById<T: Codable & Identifiable>(_ id: T.ID, type: T.Type) async throws -> T?
    
    /// Delete an item from storage
    func delete<T: Codable & Identifiable>(_ item: T) async throws
    
    /// Delete multiple items
    func deleteAll<T: Codable & Identifiable>(_ items: [T]) async throws
    
    /// Delete all items of a type matching a predicate
    func deleteWhere<T: Codable & Identifiable>(type: T.Type, predicate: NSPredicate) async throws
    
    /// Update an existing item
    func update<T: Codable & Identifiable>(_ item: T) async throws
    
    /// Count items matching a predicate
    func count<T: Codable & Identifiable>(type: T.Type, predicate: NSPredicate?) async throws -> Int
    
    /// Observe changes to items (returns an async stream)
    func observe<T: Codable & Identifiable>(type: T.Type, predicate: NSPredicate?) -> AsyncStream<[T]>
    
    /// Begin a transaction
    func beginTransaction() async throws
    
    /// Commit a transaction
    func commitTransaction() async throws
    
    /// Rollback a transaction
    func rollbackTransaction() async throws
    
    /// Clear all data
    func clearAll() async throws
    
    /// Export data to a file
    func export(to url: URL) async throws
    
    /// Import data from a file
    func `import`(from url: URL) async throws
}

// MARK: - Default Implementations

extension StorageProvider {
    
    func saveAll<T: Codable & Identifiable>(_ items: [T]) async throws {
        for item in items {
            try await save(item)
        }
    }
    
    func deleteAll<T: Codable & Identifiable>(_ items: [T]) async throws {
        for item in items {
            try await delete(item)
        }
    }
    
    func beginTransaction() async throws {
        // Default: no-op for providers that don't support transactions
    }
    
    func commitTransaction() async throws {
        // Default: no-op
    }
    
    func rollbackTransaction() async throws {
        // Default: no-op
    }
}

// MARK: - Storage Errors

enum StorageError: LocalizedError {
    case itemNotFound
    case saveFailed(Error)
    case fetchFailed(Error)
    case deleteFailed(Error)
    case updateFailed(Error)
    case transactionFailed(Error)
    case exportFailed(Error)
    case importFailed(Error)
    case invalidData
    case unsupportedType
    case fileSystemError(Error)
    
    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "The requested item was not found"
        case .saveFailed(let error):
            return "Failed to save: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete: \(error.localizedDescription)"
        case .updateFailed(let error):
            return "Failed to update: \(error.localizedDescription)"
        case .transactionFailed(let error):
            return "Transaction failed: \(error.localizedDescription)"
        case .exportFailed(let error):
            return "Export failed: \(error.localizedDescription)"
        case .importFailed(let error):
            return "Import failed: \(error.localizedDescription)"
        case .invalidData:
            return "The data is invalid or corrupted"
        case .unsupportedType:
            return "This type is not supported"
        case .fileSystemError(let error):
            return "File system error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Storage Events

/// Events emitted by storage providers
enum StorageEvent<T> {
    case inserted(T)
    case updated(T)
    case deleted(T)
    case reloaded([T])
}
