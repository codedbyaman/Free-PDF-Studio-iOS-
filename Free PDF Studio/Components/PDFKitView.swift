import SwiftUI
import PDFKit

// MARK: - Public SwiftUI View

/// A cross-platform SwiftUI view that wraps PDFKit's PDFView.
/// Supports tap-to-annotate via the `onTap` callback.
struct PDFKitView: View {
    let document: PDFDocument
    @Binding var currentPageIndex: Int
    @Binding var scaleFactor: CGFloat
    /// Called with the tapped PDFPage and position in PDF-page coordinates.
    var onTap: ((PDFPage, CGPoint) -> Void)? = nil

    var body: some View {
        _PDFViewRepresentable(
            document: document,
            currentPageIndex: $currentPageIndex,
            scaleFactor: $scaleFactor,
            onTap: onTap
        )
    }
}

// MARK: - iOS / visionOS Implementation

#if canImport(UIKit)

private struct _PDFViewRepresentable: UIViewRepresentable {
    let document: PDFDocument
    @Binding var currentPageIndex: Int
    @Binding var scaleFactor: CGFloat
    var onTap: ((PDFPage, CGPoint) -> Void)?

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.usePageViewController(false)
        pdfView.backgroundColor = .systemGroupedBackground

        // Page-change notification
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageDidChange(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )

        // Tap gesture for annotation placement
        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        tap.delegate = context.coordinator
        pdfView.addGestureRecognizer(tap)
        context.coordinator.pdfView = pdfView

        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.document !== document {
            pdfView.document = document
        }
        if abs(pdfView.scaleFactor - scaleFactor) > 0.01 {
            pdfView.scaleFactor = scaleFactor
        }
        if let page = document.page(at: currentPageIndex),
           pdfView.currentPage !== page {
            pdfView.go(to: page)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // MARK: Coordinator

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: _PDFViewRepresentable
        weak var pdfView: PDFView?

        init(_ parent: _PDFViewRepresentable) { self.parent = parent }

        @objc func pageDidChange(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let page = pdfView.currentPage,
                  let doc = pdfView.document else { return }
            let idx = doc.index(for: page)
            parent.currentPageIndex = idx
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let pdfView,
                  let onTap = parent.onTap,
                  gesture.state == .ended else { return }
            let viewPoint = gesture.location(in: pdfView)
            guard let page = pdfView.page(for: viewPoint, nearest: true) else { return }
            let pagePoint = pdfView.convert(viewPoint, to: page)
            onTap(page, pagePoint)
        }

        // Allow tap gesture to coexist with PDFView's built-in gestures
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool { true }
    }
}

#elseif canImport(AppKit)

private struct _PDFViewRepresentable: NSViewRepresentable {
    let document: PDFDocument
    @Binding var currentPageIndex: Int
    @Binding var scaleFactor: CGFloat
    var onTap: ((PDFPage, CGPoint) -> Void)?

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageDidChange(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )
        context.coordinator.pdfView = pdfView

        // Click gesture for annotation placement
        let click = NSClickGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleClick(_:))
        )
        pdfView.addGestureRecognizer(click)

        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        if pdfView.document !== document { pdfView.document = document }
        if abs(pdfView.scaleFactor - scaleFactor) > 0.01 {
            pdfView.scaleFactor = scaleFactor
        }
        if let page = document.page(at: currentPageIndex),
           pdfView.currentPage !== page {
            pdfView.go(to: page)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject {
        var parent: _PDFViewRepresentable
        weak var pdfView: PDFView?

        init(_ parent: _PDFViewRepresentable) { self.parent = parent }

        @objc func pageDidChange(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let page = pdfView.currentPage,
                  let doc = pdfView.document else { return }
            let idx = doc.index(for: page)
            parent.currentPageIndex = idx
        }

        @objc func handleClick(_ gesture: NSClickGestureRecognizer) {
            guard let pdfView,
                  let onTap = parent.onTap else { return }
            let viewPoint = gesture.location(in: pdfView)
            guard let page = pdfView.page(for: viewPoint, nearest: true) else { return }
            let pagePoint = pdfView.convert(viewPoint, to: page)
            onTap(page, pagePoint)
        }
    }
}

#endif
