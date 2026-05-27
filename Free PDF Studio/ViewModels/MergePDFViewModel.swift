import Foundation
import PDFKit
import Observation
import SwiftUI

@Observable
final class MergePDFViewModel {

    // MARK: - State

    var pdfItems: [PDFItem] = []
    var isProcessing: Bool = false
    var errorMessage: String?
    var resultURL: URL?

    // MARK: - Item Management

    func addItems(urls: [URL]) {
        let newItems = urls.map { PDFItem(url: $0) }
        pdfItems.append(contentsOf: newItems)
    }

    func removeItem(at offsets: IndexSet) {
        pdfItems.remove(atOffsets: offsets)
    }

    func moveItem(from source: IndexSet, to destination: Int) {
        pdfItems.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Merge

    func merge() async {
        guard pdfItems.count >= 2 else {
            errorMessage = "Add at least two PDF files to merge."
            return
        }
        isProcessing = true
        errorMessage = nil

        let urls = pdfItems.map(\.url)
        let saved: URL? = await Task.detached(priority: .userInitiated) {
            do {
                let merged = try PDFProcessor.merge(urls: urls)
                return PDFProcessor.saveToTemp(merged, name: "merged")
            } catch {
                return nil
            }
        }.value

        isProcessing = false
        if let url = saved {
            resultURL = url
        } else {
            errorMessage = "Merge failed. Check that all files are valid PDFs."
        }
    }

    func reset() {
        pdfItems = []
        resultURL = nil
        errorMessage = nil
    }
}
