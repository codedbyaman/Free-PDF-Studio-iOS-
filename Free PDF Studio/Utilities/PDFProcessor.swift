import Foundation
import PDFKit

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Errors

enum PDFProcessorError: LocalizedError {
    case emptyInput
    case invalidDocument(URL)
    case noPageSelected
    case imageConversionFailed
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .emptyInput:               return "No input provided."
        case .invalidDocument(let u):   return "Cannot open: \(u.lastPathComponent)"
        case .noPageSelected:           return "Select at least one page."
        case .imageConversionFailed:    return "Failed to convert image to PDF."
        case .saveFailed:               return "Failed to save the document."
        }
    }
}

// MARK: - Core PDF Processor

enum PDFProcessor {

    // MARK: Merge

    nonisolated static func merge(urls: [URL]) throws -> PDFDocument {
        guard !urls.isEmpty else { throw PDFProcessorError.emptyInput }
        let merged = PDFDocument()
        for url in urls {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            guard let doc = PDFDocument(url: url) else {
                throw PDFProcessorError.invalidDocument(url)
            }
            for i in 0..<doc.pageCount {
                if let page = doc.page(at: i) {
                    merged.insert(page, at: merged.pageCount)
                }
            }
        }
        return merged
    }

    // MARK: Split

    nonisolated static func split(
        document: PDFDocument,
        keepingIndices indices: IndexSet
    ) throws -> PDFDocument {
        guard !indices.isEmpty else { throw PDFProcessorError.noPageSelected }
        let result = PDFDocument()
        for i in indices.sorted() where i < document.pageCount {
            if let page = document.page(at: i) {
                result.insert(page, at: result.pageCount)
            }
        }
        return result
    }

    // MARK: Images → PDF

    nonisolated static func imagesToPDF(images: [PlatformImage]) throws -> PDFDocument {
        guard !images.isEmpty else { throw PDFProcessorError.emptyInput }
        let doc = PDFDocument()
        for (idx, image) in images.enumerated() {
            guard let page = PDFPage(image: image) else {
                throw PDFProcessorError.imageConversionFailed
            }
            doc.insert(page, at: idx)
        }
        return doc
    }

    // MARK: Save to Temp

    nonisolated static func saveToTemp(_ document: PDFDocument, name: String = "output") -> URL? {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)_\(Int(Date().timeIntervalSince1970)).pdf")
        return document.write(to: tmp) ? tmp : nil
    }

    // MARK: Add Text Annotation

    nonisolated static func addTextAnnotation(
        to page: PDFPage,
        text: String,
        at bounds: CGRect,
        fontSize: CGFloat = 14
    ) {
        let annotation = PDFAnnotation(bounds: bounds, forType: .freeText, withProperties: nil)
        annotation.contents = text
        #if canImport(UIKit)
        annotation.font = UIFont.systemFont(ofSize: fontSize)
        annotation.fontColor = .black
        #elseif canImport(AppKit)
        annotation.font = NSFont.systemFont(ofSize: fontSize)
        annotation.fontColor = .black
        #endif
        annotation.color = .clear
        let border = PDFBorder()
        border.lineWidth = 0
        annotation.border = border
        page.addAnnotation(annotation)
    }
}
