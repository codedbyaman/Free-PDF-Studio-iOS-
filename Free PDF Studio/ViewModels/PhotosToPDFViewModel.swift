import Foundation
import PDFKit
import Observation
import SwiftUI
import PhotosUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@Observable
final class PhotosToPDFViewModel {

    // MARK: - State

    var images: [PlatformImage] = []
    var isProcessing: Bool = false
    var isLoadingPhotos: Bool = false
    var errorMessage: String?
    var resultURL: URL?

    // MARK: - Load from PhotosUI

    func loadImages(from items: [PhotosPickerItem]) async {
        isLoadingPhotos = true
        defer { isLoadingPhotos = false }

        var loaded: [PlatformImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                #if canImport(UIKit)
                if let img = UIImage(data: data) { loaded.append(img) }
                #elseif canImport(AppKit)
                if let img = NSImage(data: data) { loaded.append(img) }
                #endif
            }
        }
        images = loaded
    }

    func removeImage(at offsets: IndexSet) {
        images.remove(atOffsets: offsets)
    }

    func moveImage(from source: IndexSet, to destination: Int) {
        images.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Convert

    func convert() async {
        guard !images.isEmpty else {
            errorMessage = "Add at least one photo."
            return
        }
        isProcessing = true
        errorMessage = nil

        let imagesCopy = images
        let saved: URL? = await Task.detached(priority: .userInitiated) {
            do {
                let doc = try PDFProcessor.imagesToPDF(images: imagesCopy)
                return PDFProcessor.saveToTemp(doc, name: "photos")
            } catch {
                return nil
            }
        }.value

        isProcessing = false
        if let url = saved {
            resultURL = url
        } else {
            errorMessage = "Conversion failed."
        }
    }

    func reset() {
        images = []
        resultURL = nil
        errorMessage = nil
    }
}
