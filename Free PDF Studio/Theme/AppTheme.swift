import SwiftUI

// MARK: - Hex Helper

extension Color {
    static func hex(_ s: String) -> Color {
        let c = s.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var v: UInt64 = 0
        Scanner(string: c).scanHexInt64(&v)
        let a, r, g, b: UInt64
        switch c.count {
        case 3:  (a,r,g,b) = (255,(v>>8)*17,(v>>4 & 0xF)*17,(v & 0xF)*17)
        case 6:  (a,r,g,b) = (255,v>>16,v>>8 & 0xFF,v & 0xFF)
        case 8:  (a,r,g,b) = (v>>24,v>>16 & 0xFF,v>>8 & 0xFF,v & 0xFF)
        default: (a,r,g,b) = (255,180,180,180)
        }
        return Color(.sRGB, red: Double(r)/255, green: Double(g)/255,
                     blue: Double(b)/255, opacity: Double(a)/255)
    }
}

// MARK: - App-wide Neutral Palette (dark-mode adaptive)

extension Color {
    /// Grouped table-style background — dark in dark mode, light in light mode
    static let appBg: Color = {
        #if canImport(UIKit)
        Color(uiColor: .systemGroupedBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }()

    /// Card / cell surface — one step lighter than appBg
    static let cardWhite: Color = {
        #if canImport(UIKit)
        Color(uiColor: .secondarySystemGroupedBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }()

    /// Primary text — near-black in light mode, near-white in dark mode
    static let labelPrimary: Color = {
        #if canImport(UIKit)
        Color(uiColor: .label)
        #else
        Color(nsColor: .labelColor)
        #endif
    }()

    /// Secondary / caption text
    static let labelSec: Color = {
        #if canImport(UIKit)
        Color(uiColor: .secondaryLabel)
        #else
        Color(nsColor: .secondaryLabelColor)
        #endif
    }()

    /// Hairline dividers and borders
    static let borderLight: Color = {
        #if canImport(UIKit)
        Color(uiColor: .separator)
        #else
        Color(nsColor: .separatorColor)
        #endif
    }()

    // Legacy aliases so existing code still compiles
    static let studioNavy     = Color.hex("0F172A")
    static let studioNavyMed  = Color.hex("1E293B")
    static let studioAccent   = Color.hex("3B82F6")
    static let studioBg       = Color.appBg
    static let studioCard     = Color.cardWhite
    static let studioLabel    = Color.labelPrimary
    static let studioSubLabel = Color.labelSec
    static let studioBorder   = Color.borderLight
    static let studioRed      = Color.hex("EF4444")
    static let studioGreen    = Color.hex("10B981")
}

// MARK: - Section Gradient Palettes

enum SectionPalette {
    // Home Dashboard — warm vibrant: Orange → Pink → Purple
    static let home:   [Color] = [.hex("FFB000"), .hex("FF5F6D"), .hex("A044FF")]

    // Edit PDF — cool productivity: Blue → Cyan → Indigo
    static let edit:   [Color] = [.hex("3B82F6"), .hex("06B6D4"), .hex("6366F1")]

    // Merge PDF — modern growth: Green → Teal
    static let merge:  [Color] = [.hex("10B981"), .hex("14B8A6")]

    // Split PDF — creative: Purple → Violet → Pink
    static let split:  [Color] = [.hex("8B5CF6"), .hex("A855F7"), .hex("EC4899")]

    // Photos to PDF — energetic: Yellow → Orange → Red
    static let photos: [Color] = [.hex("FACC15"), .hex("F97316"), .hex("EF4444")]
}

// MARK: - View Modifiers

extension View {
    // MARK: Cards
    func glassCard(radius: CGFloat = 20) -> some View {
        self
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .shadow(color: .black.opacity(0.07), radius: 16, x: 0, y: 6)
    }

    func whiteCard(radius: CGFloat = 20) -> some View {
        self
            .background(Color.cardWhite)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .shadow(color: .black.opacity(0.07), radius: 16, x: 0, y: 6)
    }

    // MARK: Buttons
    func gradientButton(colors: [Color]) -> some View {
        self
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: (colors.first ?? .clear).opacity(0.45), radius: 12, x: 0, y: 6)
    }

    func outlineButton(color: Color) -> some View {
        self
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.25), lineWidth: 1))
    }

    // Legacy aliases
    func primaryActionStyle() -> some View {
        self.gradientButton(colors: SectionPalette.edit)
    }

    func secondaryActionStyle() -> some View {
        self.outlineButton(color: .studioAccent)
    }

    func gradientButtonStyle(colors: [Color]) -> some View {
        self.gradientButton(colors: colors)
    }

    // MARK: Navigation Bar

    /// Transparent nav bar — gradient extends full-bleed under status bar
    func transparentNavBar() -> some View {
        #if os(iOS)
        self
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        #else
        self
        #endif
    }

    /// Dark-navy opaque nav bar (home screen)
    func studioNavBar() -> some View {
        #if os(iOS)
        self
            .toolbarBackground(Color.hex("0F172A"), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        #else
        self
        #endif
    }
}

// MARK: - Gradient Mesh Background

/// Subtle animated gradient orbs background
struct GradientMeshBackground: View {
    let colors: [Color]

    var body: some View {
        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            // Soft orb 1
            Circle()
                .fill(.white.opacity(0.12))
                .frame(width: 260)
                .blur(radius: 40)
                .offset(x: 100, y: -80)

            // Soft orb 2
            Circle()
                .fill(.white.opacity(0.08))
                .frame(width: 200)
                .blur(radius: 50)
                .offset(x: -80, y: 60)

            // Noise vignette at bottom
            LinearGradient(
                colors: [.black.opacity(0.12), .clear],
                startPoint: .bottom,
                endPoint: .center
            )
        }
    }
}

// MARK: - Section Header (full-bleed gradient)

struct SectionHeader: View {
    let title: String
    let subtitle: String
    let icon: String
    let colors: [Color]
    var extraContent: AnyView? = nil

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Gradient + mesh
            GradientMeshBackground(colors: colors)
                .frame(height: 210)

            // Hard shadow at bottom edge for depth
            LinearGradient(
                colors: [.black.opacity(0.15), .clear],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: 60)
            .frame(maxHeight: .infinity, alignment: .bottom)

            VStack(alignment: .leading, spacing: 10) {
                // Icon pill
                HStack(spacing: 8) {
                    ZStack {
                        Capsule()
                            .fill(.white.opacity(0.2))
                            .frame(width: 42, height: 42)
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }

                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.82))

                if let extra = extraContent { extra }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .frame(height: 210)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: 28,
                bottomTrailingRadius: 28, topTrailingRadius: 0
            )
        )
    }
}

// MARK: - Gradient Icon Badge (empty states)

struct GradientIconBadge: View {
    let systemName: String
    let colors: [Color]
    var size: CGFloat = 110

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size, height: size)
                .shadow(color: (colors.first ?? .clear).opacity(0.55), radius: 28, x: 0, y: 14)

            Circle()
                .stroke(.white.opacity(0.3), lineWidth: 2)
                .frame(width: size - 10, height: size - 10)

            Image(systemName: systemName)
                .font(.system(size: size * 0.36, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}
