import Foundation
import PDFKit
import Observation

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

    func addAnnotation(text: String, pagePoint: CGPoint, pageIndex: Int) {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        pushUndo()
        annotations.append(
            TextAnnotationData(text: text, pagePoint: pagePoint, pageIndex: pageIndex)
        )
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
                let bounds = CGRect(
                    x: entry.pagePoint.x,
                    y: entry.pagePoint.y,
                    width: 200,
                    height: entry.fontSize * 1.8
                )
                PDFProcessor.addTextAnnotation(
                    to: page,
                    text: entry.text,
                    at: bounds,
                    fontSize: entry.fontSize
                )
            }
            return PDFProcessor.saveToTemp(documentRef, name: "edited")
        }.value

        if let url = saved {
            exportURL = url
            showShareSheet = true
        } else {
            errorMessage = "Failed to save the document."
        }
    }
}
