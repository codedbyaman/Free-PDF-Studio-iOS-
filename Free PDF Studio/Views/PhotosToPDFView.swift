import SwiftUI
import PhotosUI

struct PhotosToPDFView: View {
    @State private var vm = PhotosToPDFViewModel()
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showErrorAlert = false

    private let toolColors: [Color] = SectionPalette.photos

    var body: some View {
        ZStack {
            Color.studioBg.ignoresSafeArea()
            VStack(spacing: 0) {
                if vm.images.isEmpty {
                    emptyState.transition(.opacity)
                } else {
                    photoGrid.transition(.opacity)
                }
                actionBar
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: vm.images.isEmpty)
            .animation(.spring(response: 0.3), value: vm.resultURL != nil)
        }
        .navigationTitle("Photos to PDF")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .studioNavBar()
        .onChange(of: selectedItems) { _, newItems in
            Task { await vm.loadImages(from: newItems) }
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") {}
        } message: { Text(vm.errorMessage ?? "") }
        .onChange(of: vm.errorMessage) { _, msg in showErrorAlert = msg != nil }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 28) {
            if vm.isLoadingPhotos {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(toolColors[0])
                        .scaleEffect(1.4)
                    Text("Loading photos…")
                        .font(.subheadline)
                        .foregroundStyle(Color.studioSubLabel)
                }
            } else {
                GradientIconBadge(systemName: "photo.stack", colors: toolColors)

                VStack(spacing: 8) {
                    Text("No Photos Selected")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.studioLabel)
                    Text("Choose photos from your library\nand convert them into a PDF.")
                        .font(.subheadline)
                        .foregroundStyle(Color.studioSubLabel)
                        .multilineTextAlignment(.center)
                }

                photosPickerButton
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    // MARK: - Photo Grid

    private var photoGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 100), spacing: 3)],
                spacing: 3
            ) {
                ForEach(vm.images.indices, id: \.self) { idx in
                    photoCell(index: idx)
                }
            }
            .padding(3)
        }
    }

    @ViewBuilder
    private func photoCell(index: Int) -> some View {
        let image = vm.images[index]
        #if canImport(UIKit)
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(minWidth: 0, maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fill)
            .clipped()
            .overlay(alignment: .topTrailing) { removeCellButton(index: index) }
        #elseif canImport(AppKit)
        Image(nsImage: image)
            .resizable()
            .scaledToFill()
            .frame(minWidth: 0, maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fill)
            .clipped()
            .overlay(alignment: .topTrailing) { removeCellButton(index: index) }
        #endif
    }

    private func removeCellButton(index: Int) -> some View {
        Button {
            vm.removeImage(at: IndexSet(integer: index))
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.4), radius: 4)
                .padding(4)
        }
    }

    // MARK: - Action Bar

    @ViewBuilder
    private var actionBar: some View {
        VStack(spacing: 10) {
            if let url = vm.resultURL {
                ShareLink(item: url) {
                    Label("Share PDF", systemImage: "square.and.arrow.up")
                        .gradientButtonStyle(colors: toolColors)
                }
            } else if !vm.images.isEmpty {
                Button { Task { await vm.convert() } } label: {
                    Group {
                        if vm.isProcessing {
                            HStack(spacing: 8) { ProgressView().tint(.white); Text("Converting…") }
                        } else {
                            Label(
                                "Convert \(vm.images.count) photo\(vm.images.count == 1 ? "" : "s") to PDF",
                                systemImage: "doc.badge.plus"
                            )
                        }
                    }
                    .gradientButtonStyle(colors: toolColors)
                }
                .disabled(vm.isProcessing)
            }

            photosPickerButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.regularMaterial)
        .overlay(Rectangle().frame(height: 0.5).foregroundStyle(Color.studioBorder), alignment: .top)
    }

    // MARK: - Photos Picker

    private var photosPickerButton: some View {
        PhotosPicker(
            selection: $selectedItems,
            maxSelectionCount: 50,
            matching: .images,
            photoLibrary: .shared()
        ) {
            Label(
                vm.images.isEmpty ? "Select Photos" : "Replace Photos",
                systemImage: "photo.badge.plus"
            )
            .secondaryActionStyle()
            .frame(maxWidth: vm.images.isEmpty ? 240 : .infinity)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if !vm.images.isEmpty {
                Button { vm.reset() } label: {
                    Text("Reset").foregroundStyle(.white)
                }
            }
        }
    }
}
