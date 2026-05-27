import Foundation
import PDFKit
import SwiftUI

#if canImport(UIKit)
import UIKit
/// Platform-unified image type (UIImage on iOS/visionOS).
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
/// Platform-unified image type (NSImage on macOS).
typealias PlatformImage = NSImage
#endif

// MARK: - PDF Item

/// Represents a user-selected PDF file.
struct PDFItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL

    var displayName: String {
        url.deletingPathExtension().lastPathComponent
    }

    var pageCount: Int {
        PDFDocument(url: url)?.pageCount ?? 0
    }

    static func == (lhs: PDFItem, rhs: PDFItem) -> Bool { lhs.id == rhs.id }
}

// MARK: - Text Annotation

/// A user-added text overlay on a PDF page.
struct TextAnnotationData: Identifiable, Equatable {
    let id = UUID()
    var text: String
    /// Position in PDF-page coordinate space (origin bottom-left).
    var pagePoint: CGPoint
    var fontSize: CGFloat = 14
    var pageIndex: Int

    static func == (lhs: TextAnnotationData, rhs: TextAnnotationData) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Tool Definition

/// Describes one of the four home-screen tools.
struct PDFTool: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let gradient: [Color]
}

extension PDFTool {
    static let allTools: [PDFTool] = [
        PDFTool(
            title: "Edit PDF",
            subtitle: "Modify text & add annotations",
            icon: "pencil.line",
            gradient: SectionPalette.edit
        ),
        PDFTool(
            title: "Merge PDF",
            subtitle: "Combine multiple documents",
            icon: "arrow.triangle.merge",
            gradient: SectionPalette.merge
        ),
        PDFTool(
            title: "Split PDF",
            subtitle: "Extract specific pages",
            icon: "scissors",
            gradient: SectionPalette.split
        ),
        PDFTool(
            title: "Photos to PDF",
            subtitle: "Convert images to document",
            icon: "photo.stack",
            gradient: SectionPalette.photos
        )
    ]
}
