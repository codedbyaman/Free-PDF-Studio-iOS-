import SwiftUI
import UniformTypeIdentifiers

struct MergePDFView: View {
    @State private var vm = MergePDFViewModel()
    @State private var showFilePicker = false
    @State private var showErrorAlert = false

    private let toolColors: [Color] = SectionPalette.merge

    var body: some View {
        ZStack {
            Color.studioBg.ignoresSafeArea()
            VStack(spacing: 0) {
                if vm.pdfItems.isEmpty {
                    emptyState.transition(.opacity)
                } else {
                    pdfList.transition(.opacity)
                }
                actionBar
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: vm.pdfItems.isEmpty)
            .animation(.spring(response: 0.3), value: vm.resultURL != nil)
        }
        .navigationTitle("Merge PDF")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .studioNavBar()
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.pdf],
            allowsMultipleSelection: true,
            onCompletion: handleImport
        )
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") {}
        } message: { Text(vm.errorMessage ?? "") }
        .onChange(of: vm.errorMessage) { _, msg in showErrorAlert = msg != nil }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 28) {
            GradientIconBadge(systemName: "arrow.triangle.merge", colors: toolColors)

            VStack(spacing: 8) {
                Text("No PDFs Added")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.studioLabel)
                Text("Add two or more PDF files and\nmerge them into a single document.")
                    .font(.subheadline)
                    .foregroundStyle(Color.studioSubLabel)
                    .multilineTextAlignment(.center)
            }

            Button { showFilePicker = true } label: {
                Label("Add PDF Files", systemImage: "plus.circle.fill")
                    .gradientButtonStyle(colors: toolColors)
                    .frame(maxWidth: 240)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    // MARK: - PDF List

    private var pdfList: some View {
        List {
            Section {
                ForEach(vm.pdfItems) { item in
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    LinearGradient(colors: toolColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .frame(width: 40, height: 40)
                            Image(systemName: "doc.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.displayName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.studioLabel)
                                .lineLimit(1)
                            Text("\(item.pageCount) page\(item.pageCount == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(Color.studioSubLabel)
                        }

                        Spacer()
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(Color.studioSubLabel.opacity(0.5))
                    }
                    .padding(.vertical, 6)
                }
                .onDelete { vm.removeItem(at: $0) }
                .onMove { vm.moveItem(from: $0, to: $1) }
            } header: {
                HStack {
                    Text("\(vm.pdfItems.count) document\(vm.pdfItems.count == 1 ? "" : "s") · Drag to reorder")
                        .textCase(nil)
                        .font(.caption)
                        .foregroundStyle(Color.studioSubLabel)
                    Spacer()
                    EditButton().font(.caption).foregroundStyle(toolColors[0])
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Action Bar

    @ViewBuilder
    private var actionBar: some View {
        VStack(spacing: 10) {
            if let url = vm.resultURL {
                ShareLink(item: url) {
                    Label("Share Merged PDF", systemImage: "square.and.arrow.up")
                        .gradientButtonStyle(colors: toolColors)
                }
            } else if vm.pdfItems.count >= 2 {
                Button { Task { await vm.merge() } } label: {
                    Group {
                        if vm.isProcessing {
                            HStack(spacing: 8) { ProgressView().tint(.white); Text("Merging…") }
                        } else {
                            Label("Merge \(vm.pdfItems.count) PDFs", systemImage: "arrow.triangle.merge")
                        }
                    }
                    .gradientButtonStyle(colors: toolColors)
                }
                .disabled(vm.isProcessing)
            }

            Button { showFilePicker = true } label: {
                Label("Add More PDFs", systemImage: "plus.circle")
                    .secondaryActionStyle()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.regularMaterial)
        .overlay(Rectangle().frame(height: 0.5).foregroundStyle(Color.studioBorder), alignment: .top)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if !vm.pdfItems.isEmpty {
                Button { vm.reset() } label: {
                    Text("Reset").foregroundStyle(.white)
                }
            }
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        if case .success(let urls) = result { vm.addItems(urls: urls) }
    }
}
