import Foundation
import PDFKit
import Observation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@Observable
final class EditPDFViewModel {

    // MARK: - State

    var document: PDFDocument?
    var currentPageIndex: Int = 0
    var scaleFactor: CGFloat = 1.0
    var isAnnotationMode: Bool = false
    var annotations: [TextAnnotationData] = []
    var isProcessing: Bool = false
    var errorMessage: String?
    var exportURL: URL?
    var showShareSheet: Bool = false

    // Undo / Redo stacks store snapshots of the annotations array
    private var undoStack: [[TextAnnotationData]] = []
    private var redoStack: [[TextAnnotationData]] = []

    // MARK: - Computed

    var pageCount: Int { document?.pageCount ?? 0 }
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    // MARK: - Document

    func openDocument(url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        if let doc = PDFDocument(url: url) {
            document = doc
            currentPageIndex = 0
            scaleFactor = 1.0
            annotations = []
            undoStack = []
            redoStack = []
            errorMessage = nil
        } else {
            errorMessage = "Could not open the selected file."
        }
        if accessing { url.stopAccessingSecurityScopedResource() }
    }

    // MARK: - Annotations

    func addAnnotation(
        text: String,
        pagePoint: CGPoint,
        pageIndex: Int,
        fontName: String = "Helvetica",
        fontSize: CGFloat = 12,
        colorHex: String = "000000",
        coverBounds: CGRect? = nil
    ) {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        pushUndo()
        annotations.append(TextAnnotationData(
            text: text,
            pagePoint: pagePoint,
            pageIndex: pageIndex,
            fontName: fontName,
            fontSize: fontSize,
            colorHex: colorHex,
            coverBounds: coverBounds
        ))
    }

    // MARK: - Font/Color Detection

    /// Detects the font name, size, and hex color of existing PDF text nearest to `point` on `page`.
    func detectTextStyle(at point: CGPoint, on page: PDFPage) -> (fontName: String, fontSize: CGFloat, hexColor: String) {
        let fallback = ("Helvetica", CGFloat(12), "1A1A1A")
        guard let attrStr = page.attributedString, attrStr.length > 0 else { return fallback }

        // Find character index at tap point; clamp to valid range
        let rawIdx = page.characterIndex(at: point)
        let idx = max(0, min(rawIdx, attrStr.length - 1))

        let attrs = attrStr.attributes(at: idx, effectiveRange: nil)

        var fontName = "Helvetica"
        var fontSize: CGFloat = 12
        var hexColor = "1A1A1A"

        #if canImport(UIKit)
        if let font = attrs[.font] as? UIFont {
            fontName = font.fontName      // PostScript name: e.g. "Helvetica-Bold"
            fontSize = font.pointSize
        }
        if let color = attrs[.foregroundColor] as? UIColor {
            var rr: CGFloat = 0, gg: CGFloat = 0, bb: CGFloat = 0, aa: CGFloat = 0
            color.getRed(&rr, green: &gg, blue: &bb, alpha: &aa)
            hexColor = String(format: "%02X%02X%02X", Int(rr*255), Int(gg*255), Int(bb*255))
        }
        #elseif canImport(AppKit)
        if let font = attrs[.font] as? NSFont {
            fontName = font.fontName
            fontSize = font.pointSize
        }
        if let color = (attrs[.foregroundColor] as? NSColor)?.usingColorSpace(.deviceRGB) {
            hexColor = String(format: "%02X%02X%02X",
                Int(color.redComponent*255), Int(color.greenComponent*255), Int(color.blueComponent*255))
        }
        #endif

        return (fontName, fontSize, hexColor)
    }

    func deleteAnnotation(id: UUID) {
        pushUndo()
        annotations.removeAll { $0.id == id }
    }

    func updateAnnotation(id: UUID, text: String) {
        guard let idx = annotations.firstIndex(where: { $0.id == id }) else { return }
        pushUndo()
        annotations[idx].text = text
    }

    func undo() {
        guard let prev = undoStack.popLast() else { return }
        redoStack.append(annotations)
        annotations = prev
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(annotations)
        annotations = next
    }

    private func pushUndo() {
        undoStack.append(annotations)
        redoStack.removeAll()
    }

    // MARK: - Save & Export

    func saveAndExport() async {
        guard let document else { return }
        isProcessing = true
        defer { isProcessing = false }

        // Commit all in-memory annotations to the PDF document
        let annotationsCopy = annotations
        let documentRef = document

        let saved = await Task.detached(priority: .userInitiated) {
            for entry in annotationsCopy {
                guard let page = documentRef.page(at: entry.pageIndex) else { continue }
                // Use the original text's exact bounds when replacing; otherwise default size
                let bounds = entry.coverBounds ?? CGRect(
                    x: entry.pagePoint.x,
                    y: entry.pagePoint.y,
                    width: 200,
                    height: entry.fontSize * 1.8
                )
                PDFProcessor.addTextAnnotation(
                    to: page,
                    text: entry.text,
                    at: bounds,
                    fontName: entry.fontName,
                    fontSize: entry.fontSize,
                    colorHex: entry.colorHex,
                    coverBounds: entry.coverBounds
                )
            }
            let flat = PDFProcessor.flattenDocument(documentRef)
            return PDFProcessor.saveToTemp(flat, name: "edited")
        }.value

        if let url = saved {
            exportURL = url
            showShareSheet = true
        } else {
            errorMessage = "Failed to save the document."
        }
    }
}
