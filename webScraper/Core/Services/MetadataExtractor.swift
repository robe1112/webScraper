//
//  MetadataExtractor.swift
//  webScraper
//
//  Created by Rob Evans on 1/31/26.
//

import Foundation
import PDFKit
import AVFoundation
import CoreGraphics
import ImageIO

/// Extracts basic metadata from downloaded files
/// Core functionality without Analysis Pack features
final class MetadataExtractor {
    
    // MARK: - Properties
    
    private let fileManager = FileManager.default
    
    // MARK: - Public Methods
    
    /// Extract metadata from a file
    func extractMetadata(from fileURL: URL) async -> BasicFileMetadata {
        var metadata = BasicFileMetadata()
        
        // Get basic file attributes
        if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path) {
            metadata.creationDate = attributes[.creationDate] as? Date
            metadata.modificationDate = attributes[.modificationDate] as? Date
        }
        
        // Determine file type and extract type-specific metadata
        let ext = fileURL.pathExtension.lowercased()
        
        if ext == "pdf" {
            await extractPDFMetadata(from: fileURL, into: &metadata)
        } else if ["jpg", "jpeg", "png", "gif", "webp", "tiff", "bmp", "heic"].contains(ext) {
            extractImageMetadata(from: fileURL, into: &metadata)
        } else if ["mp3", "m4a", "wav", "aac", "flac", "ogg"].contains(ext) {
            await extractAudioMetadata(from: fileURL, into: &metadata)
        } else if ["mp4", "m4v", "mov", "avi", "mkv", "webm"].contains(ext) {
            await extractVideoMetadata(from: fileURL, into: &metadata)
        }
        
        return metadata
    }
    
    /// Extract metadata from multiple files
    func extractMetadata(from fileURLs: [URL]) async -> [URL: BasicFileMetadata] {
        await withTaskGroup(of: (URL, BasicFileMetadata).self) { group in
            for url in fileURLs {
                group.addTask {
                    let metadata = await self.extractMetadata(from: url)
                    return (url, metadata)
                }
            }
            
            var results: [URL: BasicFileMetadata] = [:]
            for await (url, metadata) in group {
                results[url] = metadata
            }
            return results
        }
    }
    
    // MARK: - PDF Extraction
    
    private func extractPDFMetadata(from url: URL, into metadata: inout BasicFileMetadata) async {
        guard let document = PDFDocument(url: url) else { return }
        
        metadata.pdfPageCount = document.pageCount
        
        if let attributes = document.documentAttributes {
            metadata.pdfTitle = attributes[PDFDocumentAttribute.titleAttribute] as? String
            metadata.pdfAuthor = attributes[PDFDocumentAttribute.authorAttribute] as? String
        }
    }
    
    // MARK: - Image Extraction
    
    private func extractImageMetadata(from url: URL, into metadata: inout BasicFileMetadata) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return }
        
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return }
        
        // Basic dimensions
        metadata.imageWidth = properties[kCGImagePropertyPixelWidth] as? Int
        metadata.imageHeight = properties[kCGImagePropertyPixelHeight] as? Int
        metadata.imageColorSpace = properties[kCGImagePropertyColorModel] as? String
    }
    
    // MARK: - Audio Extraction
    
    private func extractAudioMetadata(from url: URL, into metadata: inout BasicFileMetadata) async {
        let asset = AVURLAsset(url: url)
        
        do {
            let duration = try await asset.load(.duration)
            metadata.mediaDuration = CMTimeGetSeconds(duration)
        } catch {
            // Duration not available
        }
    }
    
    // MARK: - Video Extraction
    
    private func extractVideoMetadata(from url: URL, into metadata: inout BasicFileMetadata) async {
        let asset = AVURLAsset(url: url)
        
        do {
            let duration = try await asset.load(.duration)
            metadata.mediaDuration = CMTimeGetSeconds(duration)
        } catch {
            // Duration not available
        }
    }
}
