import SwiftUI
import EjectDockCore

struct DiskPanelRow: Identifiable {
    let id: String
    let stableID: String
    let name: String
    let subtitle: String
    let detail: String
    let selected: Bool
    let canSelect: Bool
    let canOperate: Bool
    let disconnected: Bool
    let image: Bool
}

struct DockPanelRow: Identifiable {
    let id: String
    let name: String
    let detail: String
    let connected: Bool
    let selectable: Bool
}

enum PrimaryActionChoice: Hashable {
    case selectedDisks
    case dock(String)
}

final class DiskPanelModel: ObservableObject {
    @Published var disks: [DiskPanelRow] = []
    @Published var docks: [DockPanelRow] = []
    @Published var images: [DiskPanelRow] = []
    @Published var status = ""
    @Published var results: [String] = []
    @Published var busy = false
    @Published var warning = false
    @Published var completed = false
    @Published var refreshing = false
    @Published var inventoryError: String?
    @Published var canUnmountSelected = false
    @Published var primaryActionChoice = PrimaryActionChoice.selectedDisks
    @Published var primaryActionTitle = ""
    @Published var canUnmountAll = false
    @Published var canEjectImages = false
    @Published var includeImages = false
    @Published var loginEnabled = false
    @Published var loginAvailable = true
    @Published var loginHint: String?
    @Published var language = AppLanguage.system
    var onSelection: ((String, Bool) -> Void)?
    var onPrimaryActionChoice: ((PrimaryActionChoice) -> Void)?
    var onTarget: ((String) -> Void)?
    var onSelected: (() -> Void)?
    var onAll: (() -> Void)?
    var onImages: (() -> Void)?
    var onIncludeImages: (() -> Void)?
    var onLogin: (() -> Void)?
    var onLanguage: ((AppLanguage) -> Void)?
    var onAbout: (() -> Void)?
    var onQuit: (() -> Void)?
    var onRefresh: (() -> Void)?
}

struct DiskPanelView: View {
    @ObservedObject var model: DiskPanelModel
    @State private var settingsExpanded = false

    private func text(_ key: String) -> String { Localization.text(key) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "eject.circle.fill")
                    .font(.system(size: 28)).foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("EjectDock").font(.system(size: 17, weight: .semibold))
                    Text(text("panel.subtitle")).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { model.onRefresh?() } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(model.refreshing || model.busy)
                .help(text("panel.refresh"))
                .accessibilityLabel(text("panel.refresh"))
            }
            .padding(18)

            HStack(alignment: .top, spacing: 8) {
                if model.busy || model.refreshing {
                    ProgressView().controlSize(.small).frame(width: 16, height: 16)
                } else {
                    Image(systemName: model.warning ? "exclamationmark.triangle" : model.completed ? "checkmark.circle.fill" : "info.circle")
                        .foregroundStyle(model.warning ? Color.orange : model.completed ? Color.green : Color.secondary)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.inventoryError ?? model.status).font(.system(size: 12, weight: .medium))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18).padding(.bottom, 14)

            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !model.results.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(model.results.enumerated()), id: \.offset) { _, result in
                                Text(result).font(.system(size: 11)).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }.padding(.vertical, 12)
                        Divider()
                    }
                    Text(text("panel.primaryAction"))
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.top, 16).padding(.bottom, 8)
                    VStack(alignment: .leading, spacing: 8) {
                        primaryActionOption(
                            choice: .selectedDisks,
                            title: text("panel.selectedDisksTarget"),
                            detail: text("panel.selectedDisksTargetDetail"),
                            enabled: true
                        )
                        ForEach(model.docks) { dock in
                            primaryActionOption(
                                choice: .dock(dock.id),
                                title: dock.name,
                                detail: dock.detail,
                                enabled: dock.selectable || model.primaryActionChoice == .dock(dock.id)
                            )
                        }
                    }
                    if model.docks.isEmpty {
                        Text(text("panel.noDocks"))
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 7)
                    }
                    Divider().padding(.top, 14)
                    HStack {
                        Text(text("menu.externalDisks")).font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Text(text("panel.leftClick")).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                    }.padding(.top, 16).padding(.bottom, 8)
                    if model.disks.isEmpty {
                        empty(text("panel.noDisks"))
                    } else {
                        ForEach(model.disks) { row in diskRow(row) }
                    }
                    HStack {
                        Text(text("menu.diskImages")).font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Toggle(text("panel.leftClick"), isOn: Binding(get: { model.includeImages }, set: { _ in model.onIncludeImages?() }))
                            .toggleStyle(.switch).controlSize(.mini)
                            .font(.system(size: 10)).disabled(model.busy)
                            .help(text("settings.includeDiskImages"))
                            .accessibilityLabel(text("settings.includeDiskImages"))
                    }.padding(.top, 20).padding(.bottom, 8)
                    if model.images.isEmpty {
                        empty(text("inventory.noDiskImages"))
                    } else {
                        ForEach(model.images) { row in diskRow(row) }
                        Button(text("menu.ejectAllImages")) { model.onImages?() }
                            .buttonStyle(.link).font(.system(size: 11))
                            .disabled(!model.canEjectImages).padding(.top, 8)
                    }
                }.padding(.horizontal, 18).padding(.bottom, 16)
            }
            .frame(maxHeight: .infinity)

            Divider()
            VStack(spacing: 9) {
                Button { model.onSelected?() } label: {
                    HStack {
                        Image(systemName: "eject")
                        Text(model.primaryActionTitle).fontWeight(.medium)
                    }.frame(maxWidth: .infinity).padding(.vertical, 3)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(!model.canUnmountSelected)
                Button(text("menu.ejectAllExternal")) { model.onAll?() }
                    .buttonStyle(.link).font(.system(size: 11)).disabled(!model.canUnmountAll)
            }.padding(16)

            Divider()
            VStack(spacing: 12) {
                HStack {
                    Button {
                        settingsExpanded.toggle()
                    } label: {
                        Label(text("menu.settings"), systemImage: "slider.horizontal.3")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityValue(settingsExpanded ? text("panel.expanded") : text("panel.collapsed"))
                    Spacer()
                    Button { model.onAbout?() } label: { Image(systemName: "info.circle") }
                        .buttonStyle(.borderless).help(text("menu.about")).accessibilityLabel(text("menu.about"))
                    Button { model.onQuit?() } label: { Image(systemName: "power") }
                        .buttonStyle(.borderless).disabled(model.busy)
                        .help(text("menu.quit")).accessibilityLabel(text("menu.quit"))
                }.font(.system(size: 12))
                if settingsExpanded {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(text("settings.launchAtLogin"), isOn: Binding(get: { model.loginEnabled }, set: { _ in model.onLogin?() }))
                            .toggleStyle(.switch).controlSize(.small)
                            .disabled(model.busy || !model.loginAvailable)
                        if let hint = model.loginHint {
                            Text(hint).font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        Picker(text("settings.language"), selection: Binding(get: { model.language }, set: { model.onLanguage?($0) })) {
                            Text(text("language.system")).tag(AppLanguage.system)
                            Text("English").tag(AppLanguage.english)
                            Text("Français").tag(AppLanguage.french)
                        }.controlSize(.small)
                    }.font(.system(size: 12))
                }
            }.padding(16)
        }
        .frame(width: 410, height: 580)
        .background(.regularMaterial)
    }

    private func empty(_ message: String) -> some View {
        Text(message).font(.system(size: 12)).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true).padding(.vertical, 12)
    }

    private func primaryActionOption(
        choice: PrimaryActionChoice,
        title: String,
        detail: String,
        enabled: Bool
    ) -> some View {
        Button {
            model.onPrimaryActionChoice?(choice)
        } label: {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: model.primaryActionChoice == choice ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(model.primaryActionChoice == choice ? Color.accentColor : Color.secondary)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 12, weight: .medium))
                    Text(detail).font(.system(size: 10)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.busy || !enabled)
        .accessibilityValue(model.primaryActionChoice == choice ? text("panel.primarySelected") : "")
    }

    private func diskRow(_ row: DiskPanelRow) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: row.image ? "opticaldiscdrive" : "externaldrive")
                .font(.system(size: 23, weight: .regular))
                .foregroundStyle(row.disconnected ? Color.secondary : Color.accentColor)
                .frame(width: 28).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(row.name).font(.system(size: 13, weight: .medium)).lineLimit(1).help(row.name)
                Text(row.subtitle).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
                if !row.detail.isEmpty {
                    Text(row.detail).font(.system(size: 10)).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle).help(row.detail)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            if !row.disconnected {
                Button { model.onTarget?(row.stableID) } label: {
                    Image(systemName: "eject").frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless).disabled(!row.canOperate)
                .help(row.image ? text("panel.ejectImage") : text("disk.ejectNow"))
                .accessibilityLabel(row.name + ": " + (row.image ? text("panel.ejectImage") : text("disk.ejectNow")))
            }
            if !row.image {
                Toggle(text("disk.includeInPrimary"), isOn: Binding(get: { row.selected }, set: { model.onSelection?(row.stableID, $0) }))
                    .toggleStyle(.switch).controlSize(.small).labelsHidden()
                    .disabled(!row.canSelect || model.busy)
                    .help(row.disconnected ? text("disk.removeFromPrimary") : text("disk.includeInPrimary"))
                    .accessibilityLabel(row.name + ": " + text("disk.includeInPrimary"))
            }
        }
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) { Divider() }
    }
}
