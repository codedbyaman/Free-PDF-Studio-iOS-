import SwiftUI

// MARK: - Home View

struct HomeView: View {
    @Environment(\.verticalSizeClass) private var vSizeClass

    private var isLandscape: Bool { vSizeClass == .compact }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                heroSection
                toolGridSection
            }
        }
        .background(Color.studioBg.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { navBarContent }
        #if os(iOS)
        .toolbarBackground(
            LinearGradient(
                colors: [Color.hex("FF5F6D"), Color.hex("A044FF")],
                startPoint: .leading,
                endPoint: .trailing
            ),
            for: .navigationBar
        )
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        #endif
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            GradientMeshBackground(colors: SectionPalette.home)
                .ignoresSafeArea(edges: .top)

            VStack(alignment: .leading, spacing: isLandscape ? 10 : 16) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: isLandscape ? 10 : 12)
                            .fill(MeshGradient(
                                width: 2, height: 2,
                                points: [[0,0],[1,0],[0,1],[1,1]],
                                colors: [
                                    .hex("68C040"), .hex("DDAC20"),
                                    .hex("3A58C8"), .hex("D04444")
                                ]
                            ))
                            .frame(width: isLandscape ? 42 : 50, height: isLandscape ? 42 : 50)
                            .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
                        Text("P")
                            .font(.system(size: isLandscape ? 22 : 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("PDF Studio")
                            .font(.system(size: isLandscape ? 18 : 22, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Professional PDF toolkit")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                if !isLandscape {
                    Rectangle()
                        .fill(.white.opacity(0.12))
                        .frame(height: 1)
                }

                HStack(spacing: isLandscape ? 10 : 16) {
                    statPill(icon: "wrench.and.screwdriver.fill", label: "4 Tools")
                    statPill(icon: "iphone",                      label: "On‑Device")
                    statPill(icon: "lock.shield.fill",             label: "Private")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, isLandscape ? 12 : 20)
            .padding(.bottom, isLandscape ? 16 : 28)
        }
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: 28,
                bottomTrailingRadius: 28, topTrailingRadius: 0
            )
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isLandscape)
    }

    private func statPill(icon: String, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.white.opacity(0.15))
        .clipShape(Capsule())
    }

    // MARK: - Tool Grid

    private var toolGridSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Choose a Tool")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.studioLabel)
                Spacer()
                Text("4 tools")
                    .font(.caption)
                    .foregroundStyle(Color.studioSubLabel)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.studioAccent.opacity(0.12))
                    .clipShape(Capsule())
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 155, maximum: 240), spacing: 16)],
                spacing: 16
            ) {
                ForEach(PDFTool.allTools) { tool in
                    NavigationLink { destinationView(for: tool) } label: {
                        ToolCardView(tool: tool)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.studioGreen)
                Text("All processing is done on your device. Your files never leave it.")
                    .font(.caption)
                    .foregroundStyle(Color.studioSubLabel)
            }
            .padding(14)
            .background(Color.studioGreen.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.studioGreen.opacity(0.2), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 40)
    }

    // MARK: - Nav Bar

    @ToolbarContentBuilder
    private var navBarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(MeshGradient(
                            width: 2, height: 2,
                            points: [[0,0],[1,0],[0,1],[1,1]],
                            colors: [
                                .hex("68C040"), .hex("DDAC20"),
                                .hex("3A58C8"), .hex("D04444")
                            ]
                        ))
                        .frame(width: 26, height: 26)
                        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
                    Text("P")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                Text("PDF Studio")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
            }
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
    }

    // MARK: - Navigation Destinations

    @ViewBuilder
    private func destinationView(for tool: PDFTool) -> some View {
        switch tool.title {
        case "Edit PDF":      EditPDFView()
        case "Merge PDF":     MergePDFView()
        case "Split PDF":     SplitPDFView()
        case "Photos to PDF": PhotosToPDFView()
        default:              EmptyView()
        }
    }
}

// MARK: - Tool Card

struct ToolCardView: View {
    let tool: PDFTool

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: tool.gradient,
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            Circle()
                .fill(.white.opacity(0.12))
                .frame(width: 110)
                .offset(x: 55, y: -38)
            Circle()
                .fill(.white.opacity(0.07))
                .frame(width: 70)
                .offset(x: 95, y: 20)

            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white.opacity(0.22))
                        .frame(width: 46, height: 46)
                    Image(systemName: tool.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Spacer()

                Text(tool.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.bottom, 3)

                Text(tool.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
                .padding(8)
                .background(.white.opacity(0.2))
                .clipShape(Circle())
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .frame(height: 165)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(
            color: (tool.gradient.first ?? .clear).opacity(0.45),
            radius: 14, x: 0, y: 7
        )
    }
}
