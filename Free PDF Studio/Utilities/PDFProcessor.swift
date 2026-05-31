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

    // MARK: Flatten (rasterize pages + annotations into image-based PDF)

    /// Renders every page — including all annotations — to a bitmap image at `scale`×
    /// resolution, then reassembles them into a new PDF. The original text content
    /// stream is replaced by pixels, so no underlying text survives.
    nonisolated static func flattenDocument(_ document: PDFDocument, scale: CGFloat = 2.0) -> PDFDocument {
        let result = PDFDocument()
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            let mediaBox = page.bounds(for: .mediaBox)
            let renderSize = CGSize(width: mediaBox.width * scale, height: mediaBox.height * scale)

            #if canImport(UIKit)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0  // We handle DPI via `scale`
            let renderer = UIGraphicsImageRenderer(size: renderSize, format: format)
            let image = renderer.image { ctx in
                let cgCtx = ctx.cgContext
                // White background
                cgCtx.setFillColor(UIColor.white.cgColor)
                cgCtx.fill(CGRect(origin: .zero, size: renderSize))
                // UIKit contexts have top-left origin; PDF uses bottom-left — flip Y
                cgCtx.translateBy(x: 0, y: renderSize.height)
                cgCtx.scaleBy(x: scale, y: -scale)
                page.draw(with: .mediaBox, to: cgCtx)
            }
            #elseif canImport(AppKit)
            let image = NSImage(size: renderSize)
            image.lockFocus()
            if let cgCtx = NSGraphicsContext.current?.cgContext {
                cgCtx.setFillColor(NSColor.white.cgColor)
                cgCtx.fill(CGRect(origin: .zero, size: renderSize))
                cgCtx.saveGState()
                cgCtx.scaleBy(x: scale, y: scale)
                page.draw(with: .mediaBox, to: cgCtx)
                cgCtx.restoreGState()
            }
            image.unlockFocus()
            #endif

            if let flatPage = PDFPage(image: image) {
                // Preserve original media box dimensions in PDF points
                flatPage.setBounds(mediaBox, for: .mediaBox)
                result.insert(flatPage, at: result.pageCount)
            }
        }
        return result
    }

    // MARK: Add Text Annotation

    nonisolated static func addTextAnnotation(
        to page: PDFPage,
        text: String,
        at bounds: CGRect,
        fontName: String = "Helvetica",
        fontSize: CGFloat = 12,
        colorHex: String = "000000",
        coverBounds: CGRect? = nil
    ) {
        // Parse hex color
        var hexVal: UInt64 = 0
        Scanner(string: colorHex).scanHexInt64(&hexVal)
        let r = CGFloat((hexVal >> 16) & 0xFF) / 255
        let g = CGFloat((hexVal >> 8)  & 0xFF) / 255
        let b = CGFloat( hexVal        & 0xFF) / 255

        // White-out original text if replacing
        if let cover = coverBounds {
            let whiteOut = PDFAnnotation(bounds: cover, forType: .freeText, withProperties: nil)
            whiteOut.contents = " "
            whiteOut.color = .white
            #if canImport(UIKit)
            whiteOut.fontColor = .white
            whiteOut.font = UIFont.systemFont(ofSize: 1)
            #elseif canImport(AppKit)
            whiteOut.fontColor = .white
            whiteOut.font = NSFont.systemFont(ofSize: 1)
            #endif
            let noBorder = PDFBorder()
            noBorder.lineWidth = 0
            whiteOut.border = noBorder
            page.addAnnotation(whiteOut)
        }

        // Add replacement / new text
        let annotation = PDFAnnotation(bounds: bounds, forType: .freeText, withProperties: nil)
        annotation.contents = text
        #if canImport(UIKit)
        annotation.font = UIFont(name: fontName, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
        annotation.fontColor = UIColor(red: r, green: g, blue: b, alpha: 1)
        #elseif canImport(AppKit)
        annotation.font = NSFont(name: fontName, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
        annotation.fontColor = NSColor(red: r, green: g, blue: b, alpha: 1)
        #endif
        annotation.color = .clear
        let border = PDFBorder()
        border.lineWidth = 0
        annotation.border = border
        page.addAnnotation(annotation)
    }
}
