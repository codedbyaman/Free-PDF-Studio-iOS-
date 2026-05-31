import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct EditPDFView: View {
    @State private var vm = EditPDFViewModel()
    @State private var showFilePicker = false
    @State private var showAnnotationInput = false
    @State private var pendingPage: PDFPage?
    @State private var pendingPoint: CGPoint = .zero
    @State private var annotationText = ""
    @State private var showErrorAlert = false
    // Detected style at tap location
    @State private var pendingFontName: String = "Helvetica"
    @State private var pendingFontSize: CGFloat = 12
    @State private var pendingColorHex: String = "1A1A1A"
    /// Bounds of existing PDF text to white-out (nil when adding new text)
    @State private var pendingCoverBounds: CGRect? = nil
    /// Whether the sheet is replacing existing text (true) or adding new (false)
    @State private var isEditingExisting: Bool = false

    private var pendingColor: Color { Color.hex(pendingColorHex) }

    private let toolColors: [Color] = SectionPalette.edit

    var body: some View {
        ZStack {
            Color.studioBg.ignoresSafeArea()
            mainContent
            if vm.isProcessing {
                processingOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: vm.document != nil)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: vm.isProcessing)
        .navigationTitle(vm.document != nil ? "Edit PDF" : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .studioNavBar()
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.pdf],
            allowsMultipleSelection: false,
            onCompletion: handleImport
        )
        .sheet(isPresented: $showAnnotationInput) { annotationInputSheet }
        .sheet(isPresented: $vm.showShareSheet) { exportSheet }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") {}
        } message: { Text(vm.errorMessage ?? "") }
        .onChange(of: vm.errorMessage) { _, msg in showErrorAlert = msg != nil }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        if let document = vm.document {
            VStack(spacing: 0) {
                if vm.isAnnotationMode { annotationModeBanner }
                PDFKitView(
                    document: document,
                    currentPageIndex: $vm.currentPageIndex,
                    scaleFactor: $vm.scaleFactor,
                    onTap: vm.isAnnotationMode
                        ? { page, point in handleTap(page: page, point: point) }
                        : nil
                )
                .ignoresSafeArea(edges: .bottom)
                .transition(.opacity)
                bottomBar(pageCount: document.pageCount)
            }
        } else {
            emptyState
                .transition(.opacity)
        }
    }

    // MARK: - Annotation Banner

    private var annotationModeBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.tap.fill").font(.caption)
            Text("Tap the PDF to place a text annotation").font(.caption)
            Spacer()
            Button("Done") { vm.isAnnotationMode = false }
                .font(.caption.bold())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            LinearGradient(colors: toolColors, startPoint: .leading, endPoint: .trailing)
                .opacity(0.15)
        )
        .foregroundStyle(toolColors[0])
    }

    // MARK: - Bottom Bar

    private func bottomBar(pageCount: Int) -> some View {
        HStack(spacing: 4) {
            Button {
                vm.currentPageIndex = max(0, vm.currentPageIndex - 1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 40, height: 44)
                    .foregroundStyle(vm.currentPageIndex == 0 ? Color.studioSubLabel : toolColors[0])
            }
            .disabled(vm.currentPageIndex == 0)

            Spacer()

            VStack(spacing: 1) {
                Text("Page \(vm.currentPageIndex + 1)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.studioLabel)
                Text("of \(pageCount)")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.studioSubLabel)
            }

            Spacer()

            Button {
                vm.currentPageIndex = min(pageCount - 1, vm.currentPageIndex + 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 40, height: 44)
                    .foregroundStyle(vm.currentPageIndex >= pageCount - 1 ? Color.studioSubLabel : toolColors[0])
            }
            .disabled(vm.currentPageIndex >= pageCount - 1)

            Divider().frame(height: 24).padding(.horizontal, 8)

            Button { vm.scaleFactor = max(0.25, vm.scaleFactor - 0.25) } label: {
                Image(systemName: "minus.magnifyingglass").frame(width: 40, height: 44)
            }
            .foregroundStyle(toolColors[0])

            Text("\(Int(vm.scaleFactor * 100))%")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.studioSubLabel)
                .frame(minWidth: 38)

            Button { vm.scaleFactor = min(4.0, vm.scaleFactor + 0.25) } label: {
                Image(systemName: "plus.magnifyingglass").frame(width: 40, height: 44)
            }
            .foregroundStyle(toolColors[0])
        }
        .padding(.horizontal, 6)
        .frame(height: 54)
        .background(.regularMaterial)
        .overlay(Rectangle().frame(height: 0.5).foregroundStyle(Color.studioBorder), alignment: .top)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 28) {
            GradientIconBadge(systemName: "doc.text.magnifyingglass", colors: toolColors)

            VStack(spacing: 8) {
                Text("No PDF Loaded")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.studioLabel)
                Text("Open a PDF file to view and add\ntext annotations to its pages.")
                    .font(.subheadline)
                    .foregroundStyle(Color.studioSubLabel)
                    .multilineTextAlignment(.center)
            }

            Button { showFilePicker = true } label: {
                Label("Open PDF", systemImage: "doc.badge.plus")
                    .gradientButtonStyle(colors: toolColors)
                    .frame(maxWidth: 240)
            }
        }
        .padding(40)
    }

    // MARK: - Processing Overlay

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView().tint(.white).scaleEffect(1.4)
                Text("Saving…").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                Text("This may take a moment").font(.caption).foregroundStyle(.white.opacity(0.7))
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }

    // MARK: - Annotation Input Sheet

    private var annotationInputSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Detected style badge
                HStack(spacing: 8) {
                    Image(systemName: "textformat")
                        .font(.caption2.weight(.semibold))
                    Text(pendingFontName)
                        .font(.caption2.weight(.medium))
                    Text("·")
                    Text("\(Int(pendingFontSize))pt")
                        .font(.caption2)
                    Spacer()
                    Circle()
                        .fill(pendingColor)
                        .frame(width: 13, height: 13)
                        .overlay(Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

                // Text input — styled with detected font/color
                TextField("Type your text…", text: $annotationText, axis: .vertical)
                    .lineLimit(3...)
                    .font(.custom(pendingFontName, size: min(pendingFontSize, 20)))
                    .foregroundStyle(pendingColor)
                    .padding(14)
                    .background(Color.studioBg)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)

                Button { commitAnnotation() } label: {
                    Label(
                        isEditingExisting ? "Replace Text" : "Add to PDF",
                        systemImage: isEditingExisting ? "checkmark.circle.fill" : "plus.circle.fill"
                    )
                    .gradientButtonStyle(colors: toolColors)
                }
                .padding(.horizontal, 16)
                .disabled(annotationText.trimmingCharacters(in: .whitespaces).isEmpty)
                Spacer()
            }
            .padding(.top, 16)
            .navigationTitle(isEditingExisting ? "Edit Text" : "Add Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { annotationText = ""; showAnnotationInput = false }
                }
            }
        }
        .presentationDetents([.height(290)])
        .presentationCornerRadius(24)
    }

    // MARK: - Export Sheet

    @ViewBuilder
    private var exportSheet: some View {
        if let url = vm.exportURL {
            #if os(iOS)
            ShareSheet(items: [url])
            #else
            ShareLink(item: url) {
                Label("Share Edited PDF", systemImage: "square.and.arrow.up")
                    .gradientButtonStyle(colors: toolColors)
                    .padding()
            }
            #endif
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { showFilePicker = true } label: {
                Image(systemName: "doc.badge.plus").foregroundStyle(.white)
            }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button { vm.undo() } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(!vm.canUndo)
            .foregroundStyle(vm.canUndo ? Color.white : Color.white.opacity(0.35))

            Button { vm.redo() } label: {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(!vm.canRedo)
            .foregroundStyle(vm.canRedo ? Color.white : Color.white.opacity(0.35))

            Button { vm.isAnnotationMode.toggle() } label: {
                Image(systemName: vm.isAnnotationMode ? "pencil.slash" : "pencil")
                    .foregroundStyle(vm.isAnnotationMode ? Color.yellow : .white)
            }

            Button { Task { await vm.saveAndExport() } } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .disabled(vm.document == nil || vm.isProcessing)
            .foregroundStyle(.white)
        }
    }

    // MARK: - Handlers

    private func handleImport(_ result: Result<[URL], Error>) {
        if case .success(let urls) = result, let url = urls.first {
            vm.openDocument(url: url)
        }
    }

    private func handleTap(page: PDFPage, point: CGPoint) {
        guard vm.document != nil else { return }
        pendingPage = page

        // Try to detect an existing line of text at the tap point
        if let selection = page.selectionForLine(at: point),
           let selectedText = selection.string,
           !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Editing existing text
            let cover = selection.bounds(for: page)
            pendingCoverBounds = cover
            pendingPoint = CGPoint(x: cover.minX, y: cover.minY)
            annotationText = selectedText.trimmingCharacters(in: .newlines)
            isEditingExisting = true
            // Detect style from the selection's attributed string
            if let attr = selection.attributedString, attr.length > 0 {
                let attrs = attr.attributes(at: 0, effectiveRange: nil)
                #if canImport(UIKit)
                if let font = attrs[.font] as? UIFont {
                    pendingFontName = font.fontName
                    pendingFontSize = font.pointSize
                }
                if let color = attrs[.foregroundColor] as? UIColor {
                    var rr: CGFloat = 0, gg: CGFloat = 0, bb: CGFloat = 0, aa: CGFloat = 0
                    color.getRed(&rr, green: &gg, blue: &bb, alpha: &aa)
                    pendingColorHex = String(format: "%02X%02X%02X", Int(rr*255), Int(gg*255), Int(bb*255))
                }
                #elseif canImport(AppKit)
                if let font = attrs[.font] as? NSFont {
                    pendingFontName = font.fontName
                    pendingFontSize = font.pointSize
                }
                if let color = (attrs[.foregroundColor] as? NSColor)?.usingColorSpace(.deviceRGB) {
                    pendingColorHex = String(format: "%02X%02X%02X",
                        Int(color.redComponent*255), Int(color.greenComponent*255), Int(color.blueComponent*255))
                }
                #endif
            }
        } else {
            // No existing text — adding new annotation
            pendingPoint = point
            pendingCoverBounds = nil
            annotationText = ""
            isEditingExisting = false
            let style = vm.detectTextStyle(at: point, on: page)
            pendingFontName = style.fontName
            pendingFontSize = style.fontSize
            pendingColorHex = style.hexColor
        }
        showAnnotationInput = true
    }

    private func commitAnnotation() {
        guard let page = pendingPage, let document = vm.document else { return }
        let idx = document.index(for: page)
        vm.addAnnotation(
            text: annotationText,
            pagePoint: pendingPoint,
            pageIndex: idx,
            fontName: pendingFontName,
            fontSize: pendingFontSize,
            colorHex: pendingColorHex,
            coverBounds: pendingCoverBounds
        )
        annotationText = ""
        pendingCoverBounds = nil
        isEditingExisting = false
        showAnnotationInput = false
    }
}
