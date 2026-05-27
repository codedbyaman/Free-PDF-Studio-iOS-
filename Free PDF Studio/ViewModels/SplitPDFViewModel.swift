import Foundation
import PDFKit
import Observation

@Observable
final class SplitPDFViewModel {

    // MARK: - State

    var document: PDFDocument?
    var selectedIndices: IndexSet = []
    var isProcessing: Bool = false
    var errorMessage: String?
    var resultURL: URL?

    // MARK: - Document

    func openDocument(url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        if let doc = PDFDocument(url: url) {
            document = doc
            selectedIndices = []
            resultURL = nil
            errorMessage = nil
        } else {
            errorMessage = "Could not open the selected file."
        }
        if accessing { url.stopAccessingSecurityScopedResource() }
    }

    var pageCount: Int { document?.pageCount ?? 0 }

    // MARK: - Selection Helpers

    func selectAll() {
        guard let document else { return }
        selectedIndices = IndexSet(0..<document.pageCount)
    }

    func clearSelection() {
        selectedIndices = []
    }

    // MARK: - Split

    func split() async {
        guard let document else {
            errorMessage = "No document loaded."
            return
        }
        guard !selectedIndices.isEmpty else {
            errorMessage = "Select at least one page to keep."
            return
        }

        isProcessing = true
        errorMessage = nil

        let indices = selectedIndices
        let saved: URL? = await Task.detached(priority: .userInitiated) {
            do {
                let result = try PDFProcessor.split(document: document, keepingIndices: indices)
                return PDFProcessor.saveToTemp(result, name: "split")
            } catch {
                return nil
            }
        }.value

        isProcessing = false
        if let url = saved {
            resultURL = url
        } else {
            errorMessage = "Split failed."
        }
    }

    func reset() {
        document = nil
        selectedIndices = []
        resultURL = nil
        errorMessage = nil
    }
}
