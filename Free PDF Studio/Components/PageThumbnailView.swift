import SwiftUI
import PDFKit

// MARK: - Single Page Thumbnail

/// Renders one PDF page as a selectable thumbnail.
struct PageThumbnailView: View {
    let page: PDFPage
    let pageIndex: Int
    let isSelected: Bool
    var thumbnailSize: CGSize = CGSize(width: 90, height: 120)

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Image(decorative: thumbnail, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .background(Color.cardWhite)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.studioAccent : Color.clear, lineWidth: 2.5)
                    )

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.studioAccent)
                        .background(Circle().fill(Color.cardWhite).padding(2))
                        .padding(6)
                }
            }
            .frame(width: thumbnailSize.width, height: thumbnailSize.height)

            Text("Page \(pageIndex + 1)")
                .font(.caption2)
                .foregroundStyle(Color.studioSubLabel)
        }
    }

    // MARK: - Platform Thumbnail

    #if canImport(UIKit)
    private var thumbnail: CGImage {
        let img = page.thumbnail(of: thumbnailSize, for: .mediaBox)
        return img.cgImage ?? UIImage().cgImage!
    }
    #elseif canImport(AppKit)
    private var thumbnail: CGImage {
        let img = page.thumbnail(of: thumbnailSize, for: .mediaBox)
        return img.cgImage(forProposedRect: nil, context: nil, hints: nil) ?? CGImage(width: 1, height: 1, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: 0), provider: CGDataProvider(data: Data(count: 4) as CFData)!, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    }
    #endif
}

// MARK: - Thumbnail Grid

/// A lazy grid of page thumbnails with multi-select support.
struct PageThumbnailGrid: View {
    let document: PDFDocument
    @Binding var selectedIndices: IndexSet

    private let columns = [
        GridItem(.adaptive(minimum: 90), spacing: 16)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(0..<document.pageCount, id: \.self) { idx in
                if let page = document.page(at: idx) {
                    PageThumbnailView(
                        page: page,
                        pageIndex: idx,
                        isSelected: selectedIndices.contains(idx)
                    )
                    .onTapGesture {
                        if selectedIndices.contains(idx) {
                            selectedIndices.remove(idx)
                        } else {
                            selectedIndices.insert(idx)
                        }
                    }
                }
            }
        }
        .padding(16)
    }
}
