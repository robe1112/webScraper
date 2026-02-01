//
//  FileStorage.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import Foundation

/// File-based implementation of StorageProvider
/// Uses JSON files for storage - simple and human-readable
@MainActor
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
        let data = try encoder.encode(item)
        let url = fileURL(for: item)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    try data.write(to: url)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: StorageError.saveFailed(error))
                }
            }
        }
    }
    
    func fetch<T: Codable & Identifiable>(predicate: NSPredicate?) async throws -> [T] {
        let directory = directoryForType(T.self)
        let allItems: [T] = try await withCheckedThrowingContinuation { continuation in
            queue.async {
                let fm = FileManager.default
                let dec = JSONDecoder()
                dec.dateDecodingStrategy = .iso8601
                do {
                    let files = try fm.contentsOfDirectory(
                        at: directory,
                        includingPropertiesForKeys: nil
                    ).filter { $0.pathExtension == "json" }
                    
                    var results: [T] = []
                    for file in files {
                        let data = try Data(contentsOf: file)
                        let item = try dec.decode(T.self, from: data)
                        results.append(item)
                    }
                    continuation.resume(returning: results)
                } catch {
                    continuation.resume(throwing: StorageError.fetchFailed(error))
                }
            }
        }
        // Apply predicate filter on MainActor (NSPredicate is not Sendable)
        guard let predicate = predicate else { return allItems }
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        return allItems.filter { item in
            guard let data = try? enc.encode(item),
                  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return false
            }
            return predicate.evaluate(with: dict)
        }
    }
    
    func fetchById<T: Codable & Identifiable>(_ id: T.ID, type: T.Type) async throws -> T? {
        let url = fileURL(for: id, type: type)
        return try await withCheckedThrowingContinuation { continuation in
            let urlCopy = url
            queue.async {
                let fm = FileManager.default
                guard fm.fileExists(atPath: urlCopy.path) else {
                    continuation.resume(returning: nil)
                    return
                }
                do {
                    let data = try Data(contentsOf: urlCopy)
                    let dec = JSONDecoder()
                    dec.dateDecodingStrategy = .iso8601
                    let item = try dec.decode(T.self, from: data)
                    continuation.resume(returning: item)
                } catch {
                    continuation.resume(throwing: StorageError.fetchFailed(error))
                }
            }
        }
    }
    
    func delete<T: Codable & Identifiable>(_ item: T) async throws {
        let url = fileURL(for: item)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let urlCopy = url
            queue.async {
                let fm = FileManager.default
                do {
                    if fm.fileExists(atPath: urlCopy.path) {
                        try fm.removeItem(at: urlCopy)
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
        let baseDir = baseDirectory
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                let fm = FileManager.default
                do {
                    if fm.fileExists(atPath: baseDir.path) {
                        try fm.removeItem(at: baseDir)
                    }
                    if !fm.fileExists(atPath: baseDir.path) {
                        try? fm.createDirectory(at: baseDir, withIntermediateDirectories: true)
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: StorageError.fileSystemError(error))
                }
            }
        }
    }
    
    func export(to url: URL) async throws {
        let baseDir = baseDirectory
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                let fm = FileManager.default
                do {
                    if fm.fileExists(atPath: url.path) {
                        try fm.removeItem(at: url)
                    }
                    try fm.copyItem(at: baseDir, to: url)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: StorageError.exportFailed(error))
                }
            }
        }
    }
    
    func `import`(from url: URL) async throws {
        let baseDir = baseDirectory
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                let fm = FileManager.default
                do {
                    if fm.fileExists(atPath: baseDir.path) {
                        try fm.removeItem(at: baseDir)
                    }
                    try fm.copyItem(at: url, to: baseDir)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: StorageError.importFailed(error))
                }
            }
        }
    }
}
