import AppKit
import SwiftUI

extension ContentView {
    var sidebar: some View {
        VStack(spacing: 6) {
            brandMark.padding(.top, 52).padding(.bottom, 6)
            sideButton(.home, icon: "house.fill")
            sideButton(.junk, icon: "paintbrush.fill")
            sideButton(.uninstall, icon: "app.badge.checkmark")
            sideButton(.files, icon: "chart.pie.fill")
            sideButton(.performance, icon: "gauge.with.dots.needle.67percent")
            sideButton(.network, icon: "network")
            sideButton(.tools, icon: "wrench.and.screwdriver.fill")
            systemInventorySideButton
            Spacer()
            if model.isStorageAnalyzing {
                Button { model.changeMode(.files) } label: {
                    VStack(spacing: 2) {
                        ProgressView().controlSize(.mini)
                        sidebarLabel("Analyzing", size: 9, weight: .medium)
                    }
                    .frame(width: 52, height: 42)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .help("Storage analysis is running in the background")
            }
            sideButton(.settings, icon: "gearshape.fill")
            Button(action: openFeedback) {
                VStack(spacing: 2) {
                    Image(systemName: "bubble.left.and.bubble.right").font(.system(size: 16))
                    sidebarLabel("Feedback")
                }
                .frame(width: 52, height: 48)
                .contentShape(Rectangle())
            }.buttonStyle(.plain).foregroundStyle(.secondary).padding(.bottom, MachKitLayout.bannerPadding)
        }
        .frame(width: 72)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    func openFeedback() {
        if let url = URL(string: "https://github.com/rhevorn/machkit/issues") {
            NSWorkspace.shared.open(url)
        }
    }

    var brandMark: some View {
        Image("BrandMark")
            .resizable()
            .scaledToFit()
            .frame(width: 34, height: 34)
            .help("MachKit")
    }

    func sideButton(_ mode: FeatureMode, icon: String) -> some View {
        Button {
            inventorySearch = ""
            model.changeMode(mode)
        } label: {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.system(size: 17, weight: .medium))
                sidebarLabel(mode.rawValue)
            }
            .foregroundStyle(model.mode == mode ? Color.accentColor : Color.secondary)
            .frame(width: 60, height: 48)
            .background {
                if model.mode == mode {
                    RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.10))
                }
            }
            .overlay(alignment: .leading) {
                if model.mode == mode {
                    Capsule().fill(Color.accentColor).frame(width: 3, height: 28).offset(x: -2)
                }
            }
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    var systemInventorySideButton: some View {
        let isSelected = [.loginItems, .backgroundActivity, .extensions].contains(model.mode)
        return Button {
            inventorySearch = ""
            if !isSelected { model.changeMode(.loginItems) }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "switch.2").font(.system(size: 17, weight: .medium))
                sidebarLabel("System", size: 10.5)
            }
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            .frame(width: 60, height: 48)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.10))
                }
            }
            .overlay(alignment: .leading) {
                if isSelected {
                    Capsule().fill(Color.accentColor).frame(width: 3, height: 28).offset(x: -2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    func sidebarLabel(
        _ title: String,
        size: CGFloat = 10.5,
        weight: Font.Weight = .regular
    ) -> some View {
        Text(title.localized)
            .font(.system(size: size, weight: weight))
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(width: 60)
    }

}

