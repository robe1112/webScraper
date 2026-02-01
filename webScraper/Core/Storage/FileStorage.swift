//
//  FileStorage.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import Foundation

/// File-based implementation of StorageProvider
/// Uses JSON files for storage - simple and human-readable
final class FileStorage: StorageProvider {
    
    // MARK: - Properties
    
    private let baseDirectory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.webScraper.fileStorage", qos: .userInitiated)
    
    // MARK: - Initialization
    
    init(baseDirectory: URL? = nil) {
        if let baseDirectory = baseDirectory {
            self.baseDirectory = baseDirectory
        } else {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            self.baseDirectory = documentsPath.appendingPathComponent("webScraperData")
        }
        
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        
        createDirectoryIfNeeded()
    }
    
    // MARK: - Directory Management
    
    private func createDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: baseDirectory.path) {
            try? fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        }
    }
    
    private func directoryForType<T>(_ type: T.Type) -> URL {
        let typeName = String(describing: type)
        let directory = baseDirectory.appendingPathComponent(typeName)
        
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        
        return directory
    }
    
    private func fileURL<T: Identifiable>(for item: T) -> URL {
        let directory = directoryForType(T.self)
        return directory.appendingPathComponent("\(item.id).json")
    }
    
    private func fileURL<T>(for id: T.ID, type: T.Type) -> URL where T: Identifiable {
        let directory = directoryForType(T.self)
        return directory.appendingPathComponent("\(id).json")
    }
    
    // MARK: - StorageProvider Implementation
    
    func save<T: Codable & Identifiable>(_ item: T) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    let data = try self.encoder.encode(item)
                    let url = self.fileURL(for: item)
                    try data.write(to: url)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: StorageError.saveFailed(error))
                }
            }
        }
    }
    
    func fetch<T: Codable & Identifiable>(predicate: NSPredicate?) async throws -> [T] {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let directory = self.directoryForType(T.self)
                    let files = try self.fileManager.contentsOfDirectory(
                        at: directory,
                        includingPropertiesForKeys: nil
                    ).filter { $0.pathExtension == "json" }
                    
                    var results: [T] = []
                    
                    for file in files {
                        let data = try Data(contentsOf: file)
                        let item = try self.decoder.decode(T.self, from: data)
                        
                        // Apply predicate filter if provided
                        if let predicate = predicate {
                            // Convert to dictionary for predicate evaluation
                            if let dict = try? JSONSerialization.jsonObject(with: data) as? NSDictionary,
                               predicate.evaluate(with: dict) {
                                results.append(item)
                            }
                        } else {
                            results.append(item)
                        }
                    }
                    
                    continuation.resume(returning: results)
                } catch {
                    continuation.resume(throwing: StorageError.fetchFailed(error))
                }
            }
        }
    }
    
    func fetchById<T: Codable & Identifiable>(_ id: T.ID, type: T.Type) async throws -> T? {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                let url = self.fileURL(for: id, type: type)
                
                guard self.fileManager.fileExists(atPath: url.path) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                do {
                    let data = try Data(contentsOf: url)
                    let item = try self.decoder.decode(T.self, from: data)
                    continuation.resume(returning: item)
                } catch {
                    continuation.resume(throwing: StorageError.fetchFailed(error))
                }
            }
        }
    }
    
    func delete<T: Codable & Identifiable>(_ item: T) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    let url = self.fileURL(for: item)
                    if self.fileManager.fileExists(atPath: url.path) {
                        try self.fileManager.removeItem(at: url)
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: StorageError.deleteFailed(error))
                }
            }
        }
    }
    
    func deleteWhere<T: Codable & Identifiable>(type: T.Type, predicate: NSPredicate) async throws {
        let items: [T] = try await fetch(predicate: predicate)
        for item in items {
            try await delete(item)
        }
    }
    
    func update<T: Codable & Identifiable>(_ item: T) async throws {
        try await save(item)
    }
    
    func count<T: Codable & Identifiable>(type: T.Type, predicate: NSPredicate?) async throws -> Int {
        let items: [T] = try await fetch(predicate: predicate)
        return items.count
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
                
                // Set up file system monitoring
                let directory = self.directoryForType(T.self)
                
                let source = DispatchSource.makeFileSystemObjectSource(
                    fileDescriptor: open(directory.path, O_EVTONLY),
                    eventMask: [.write, .delete, .rename],
                    queue: self.queue
                )
                
                source.setEventHandler {
                    Task {
                        do {
                            let items: [T] = try await self.fetch(predicate: predicate)
                            continuation.yield(items)
                        } catch {
                            // Continue on error
                        }
                    }
                }
                
                source.setCancelHandler {
                    // Cleanup
                }
                
                source.resume()
                
                continuation.onTermination = { _ in
                    source.cancel()
                }
            }
        }
    }
    
    func clearAll() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    if self.fileManager.fileExists(atPath: self.baseDirectory.path) {
                        try self.fileManager.removeItem(at: self.baseDirectory)
                    }
                    self.createDirectoryIfNeeded()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: StorageError.fileSystemError(error))
                }
            }
        }
    }
    
    func export(to url: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    // Create a zip of the base directory
                    // For simplicity, we'll just copy the directory
                    if self.fileManager.fileExists(atPath: url.path) {
                        try self.fileManager.removeItem(at: url)
                    }
                    try self.fileManager.copyItem(at: self.baseDirectory, to: url)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: StorageError.exportFailed(error))
                }
            }
        }
    }
    
    func `import`(from url: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    // Replace base directory with imported data
                    if self.fileManager.fileExists(atPath: self.baseDirectory.path) {
                        try self.fileManager.removeItem(at: self.baseDirectory)
                    }
                    try self.fileManager.copyItem(at: url, to: self.baseDirectory)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: StorageError.importFailed(error))
                }
            }
        }
    }
}
