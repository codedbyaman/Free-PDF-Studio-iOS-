import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct SplitPDFView: View {
    @State private var vm = SplitPDFViewModel()
    @State private var showFilePicker = false
    @State private var showErrorAlert = false

    private let toolColors: [Color] = SectionPalette.split

    var body: some View {
        ZStack {
            Color.studioBg.ignoresSafeArea()
            content
            if vm.isProcessing {
                processingOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: vm.document != nil)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: vm.isProcessing)
        .navigationTitle("Split PDF")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .studioNavBar()
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.pdf],
            allowsMultipleSelection: false,
            onCompletion: handleImport
        )
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") {}
        } message: { Text(vm.errorMessage ?? "") }
        .onChange(of: vm.errorMessage) { _, msg in showErrorAlert = msg != nil }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if let document = vm.document {
            VStack(spacing: 0) {
                selectionBar
                ScrollView { PageThumbnailGrid(document: document, selectedIndices: $vm.selectedIndices) }
                splitActionBar
            }
        } else {
            emptyState
        }
    }

    // MARK: - Selection Bar

    private var selectionBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(vm.selectedIndices.count) selected")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.studioLabel)
                Text("of \(vm.pageCount) pages")
                    .font(.caption2)
                    .foregroundStyle(Color.studioSubLabel)
            }

            Spacer()

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(toolColors[0].opacity(0.15))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: toolColors, startPoint: .leading, endPoint: .trailing))
                        .frame(
                            width: vm.pageCount > 0
                                ? geo.size.width * (CGFloat(vm.selectedIndices.count) / CGFloat(vm.pageCount))
                                : 0
                        )
                        .animation(.spring(duration: 0.3), value: vm.selectedIndices.count)
                }
            }
            .frame(width: 80, height: 6)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            Button("All") { vm.selectAll() }
                .font(.caption.bold())
                .foregroundStyle(toolColors[0])
            Text("·").foregroundStyle(Color.studioBorder)
            Button("None") { vm.clearSelection() }
                .font(.caption.bold())
                .foregroundStyle(toolColors[0])
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.studioCard)
        .overlay(Rectangle().frame(height: 0.5).foregroundStyle(Color.studioBorder), alignment: .bottom)
    }

    // MARK: - Action Bar

    @ViewBuilder
    private var splitActionBar: some View {
        VStack(spacing: 10) {
            if let url = vm.resultURL {
                ShareLink(item: url) {
                    Label("Share Split PDF", systemImage: "square.and.arrow.up")
                        .gradientButtonStyle(colors: toolColors)
                }
            } else {
                Button { Task { await vm.split() } } label: {
                    Text(
                        vm.selectedIndices.isEmpty
                            ? "Select pages to extract"
                            : "Extract \(vm.selectedIndices.count) page\(vm.selectedIndices.count == 1 ? "" : "s")"
                    )
                    .gradientButtonStyle(colors: vm.selectedIndices.isEmpty ? [Color.studioSubLabel, Color.studioSubLabel] : toolColors)
                }
                .disabled(vm.selectedIndices.isEmpty || vm.isProcessing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.regularMaterial)
        .overlay(Rectangle().frame(height: 0.5).foregroundStyle(Color.studioBorder), alignment: .top)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 28) {
            GradientIconBadge(systemName: "scissors", colors: toolColors)

            VStack(spacing: 8) {
                Text("No PDF Loaded")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.studioLabel)
                Text("Open a PDF and tap the pages\nyou want to keep or extract.")
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    // MARK: - Processing Overlay

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView().tint(.white).scaleEffect(1.4)
                Text("Splitting…").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
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
        ToolbarItem(placement: .topBarTrailing) {
            if vm.document != nil {
                Button { vm.reset() } label: {
                    Text("Reset").foregroundStyle(.white)
                }
            }
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        if case .success(let urls) = result, let url = urls.first {
            vm.openDocument(url: url)
        }
    }
}
