import SwiftUI

struct SettingsView: View {
    @AppStorage("Manchot_AccentColor_Hex") private var accentColorHex: String = "#F7BA00"
    @AppStorage("Manchot_StrikeThroughEnabled") private var strikeThroughEnabled: Bool = true
    @AppStorage("Manchot_FontWeight") private var fontWeightName: String = "Regular"
    
    @State private var selectedTab: SettingsTab = .appearance
    
    enum SettingsTab {
        case appearance
        case info
    }
    
    private let presetColors: [String] = [
        "#F7BA00", // Yellow
        "#FF3B30", // Red
        "#FF9500", // Orange
        "#32D74B", // Mint/Green
        "#00C7BE", // Teal
        "#0A84FF", // Blue
        "#5E5CE6", // Indigo
        "#FF2D55"  // Pink
    ]
    
    private let fontWeights: [String] = [
        "Ultralight",
        "Thin",
        "Light",
        "Regular",
        "Medium",
        "Semibold",
        "Bold",
        "Heavy",
        "Black"
    ]
    
    private var currentAccentColor: Color {
        Color(hex: accentColorHex) ?? Color(red: 0.97, green: 0.73, blue: 0.0)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top Segmented Tabs
            HStack(spacing: 24) {
                Button(action: { selectedTab = .appearance }) {
                    VStack(spacing: 6) {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 20))
                        Text("Appearance")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(selectedTab == .appearance ? currentAccentColor : Color.white.opacity(0.6))
                    .frame(width: 70, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(selectedTab == .appearance ? Color.white.opacity(0.08) : Color.clear)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: { selectedTab = .info }) {
                    VStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 20))
                        Text("Info")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(selectedTab == .info ? currentAccentColor : Color.white.opacity(0.6))
                    .frame(width: 70, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(selectedTab == .info ? Color.white.opacity(0.08) : Color.clear)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.top, 16)
            .padding(.bottom, 16)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Content Area wrapped in ScrollView to prevent clipping and overflow
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    if selectedTab == .appearance {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Theme Color")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                            
                            // Preset Color Circles with proper padding/clipping container
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(presetColors, id: \.self) { hexCode in
                                        let isSelected = (accentColorHex.uppercased() == hexCode.uppercased())
                                        Circle()
                                            .fill(Color(hex: hexCode) ?? .yellow)
                                            .frame(width: 28, height: 28)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: isSelected ? 2.5 : 0)
                                            )
                                            .scaleEffect(isSelected ? 1.1 : 1.0)
                                            .onTapGesture {
                                                accentColorHex = hexCode
                                            }
                                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                                    }
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 6)
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                                .padding(.vertical, 4)
                            
                            // Font Weight Selector
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Task Font Weight")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white)
                                    Text("Choose the thickness of your task text")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                Spacer()
                                Picker("", selection: $fontWeightName) {
                                    ForEach(fontWeights, id: \.self) { weight in
                                        Text(weight).tag(weight)
                                    }
                                }
                                .frame(width: 130)
                                .accentColor(currentAccentColor)
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                                .padding(.vertical, 4)
                            
                            // Strikethrough Option
                            Toggle(isOn: $strikeThroughEnabled) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Strikethrough completed text")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white)
                                    Text("Draw a line through text when a task is marked done")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                            .toggleStyle(.checkbox)
                            .accentColor(currentAccentColor)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Manchot")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                            Text("developer - plykopia")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.8))
                            Text("v0.0.2")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 380, height: 340)
        .background(Color(red: 0.11, green: 0.11, blue: 0.12))
        .preferredColorScheme(.dark)
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let red = Double((rgb & 0xFF0000) >> 16) / 255.0
        let green = Double((rgb & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgb & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }
}
