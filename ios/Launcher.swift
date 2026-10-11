// muguet - Launcher.swift
// Constantin Clerc (c22dev) - 0.1

import SwiftUI
import UIKit
import UniformTypeIdentifiers

let configURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("config.json")

final class Settings: ObservableObject {
    @Published var mode = 2
    @Published var scale = 0.5
    @Published var fps = 60
    @Published var textures = 0
    @Published var touch = 1.5
    @Published var aimSensitivity = 0.8
    @Published var aimMode = "toggle"
    @Published var fireAim = true
    @Published var mute = false
    @Published var multiplayer = false
    @Published var host = false
    @Published var server = "18.143.103.253"
    @Published var name = "Player" + String(Int.random(in: 100...999))
    @Published var room = String(Int.random(in: 1000...9999))
    @Published var roomMode = "create"
    @Published var pvp = false
    var extra: [String: Any] = [:]

    init() {
        guard let data = try? Data(contentsOf: configURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        extra = json
        if let v = json["start_mode"] as? Int, (1...2).contains(v) { mode = v }
        if let v = json["scale"] as? Double { scale = v }
        if let v = json["fps_limit"] as? Int, [30, 60, 120].contains(v) { fps = v }
        if fps > UIScreen.main.maximumFramesPerSecond { fps = 60 }
        if let v = json["texture_quality"] as? Int, (0...2).contains(v) { textures = v }
        if let v = json["touch_sensitivity"] as? Double { touch = max(0.1, min(10.0, v)) }
        if let v = json["aim_sensitivity"] as? Double { aimSensitivity = max(0.1, min(5.0, v)) }
        if let v = json["aim_mode"] as? String, ["toggle", "hold"].contains(v) { aimMode = v }
        if let v = json["fire_aim"] as? Bool { fireAim = v }
        if let v = json["mute"] as? Bool { mute = v }
        if let v = json["multiplayer"] as? Bool { multiplayer = v }
        if let v = json["host"] as? Bool { host = v }
        if let v = json["server"] as? String, !v.trimmingCharacters(in: .whitespaces).isEmpty { server = v }
        if let v = json["room"] as? String, !v.trimmingCharacters(in: .whitespaces).isEmpty { room = v }
        if let v = json["room_mode"] as? String, ["create", "join", "lan"].contains(v) { roomMode = v }
        if let v = json["pvp"] as? Bool { pvp = v }
        if let v = json["player_name"] as? String, !v.trimmingCharacters(in: .whitespaces).isEmpty && v != "iPhone" && v != "iPad" {
            name = v
        }
    }

    func save() throws {
        var json = extra
        json["start_mode"] = mode
        json["scale"] = scale
        json["fps_limit"] = fps
        json["texture_quality"] = textures
        json["touch_sensitivity"] = (touch * 100).rounded() / 100
        json["aim_sensitivity"] = (aimSensitivity * 100).rounded() / 100
        json["aim_mode"] = aimMode
        json["fire_aim"] = fireAim
        json["mute"] = mute
        json["multiplayer"] = multiplayer
        json["host"] = (roomMode == "lan")
        let srv = server.trimmingCharacters(in: .whitespaces)
        json["server"] = srv.isEmpty ? "18.143.103.253" : srv
        let rm = room.trimmingCharacters(in: .whitespaces)
        json["room"] = rm.isEmpty ? "default" : rm
        json["room_mode"] = roomMode
        json["pvp"] = pvp
        let nm = name.trimmingCharacters(in: .whitespaces)
        json["player_name"] = nm.isEmpty ? "Player" : nm
        if json["extra_args"] == nil { json["extra_args"] = [String]() }
        let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: configURL)
    }
}

@_silgen_name("muguet_import")
func muguet_import(_ zip: UnsafePointer<CChar>, _ progress: @convention(c) (UInt64, UInt64) -> Void) -> Bool
@_silgen_name("muguet_import_error")
func muguet_import_error() -> UnsafePointer<CChar>?
@_silgen_name("muguet_game_ready")
func muguet_game_ready() -> Bool
@_silgen_name("muguet_has_game_code")
func muguet_has_game_code() -> Bool

final class Importer: ObservableObject {
    static let shared = Importer()
    @Published var ready = muguet_game_ready()
    @Published var progress: Double?
    @Published var error: String?
    private var lastProgressTime = 0.0

    func run(_ url: URL) {
        error = nil
        progress = 0
        DispatchQueue.global(qos: .userInitiated).async {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let ok = url.path.withCString { muguet_import($0) { done, total in
                let now = ProcessInfo.processInfo.systemUptime
                guard done == total || now - Importer.shared.lastProgressTime >= 0.05 else { return }
                Importer.shared.lastProgressTime = now
                let p = total > 0 ? Double(done) / Double(total) : 0
                DispatchQueue.main.async { Importer.shared.progress = p }
            } }
            let message = ok ? nil : muguet_import_error().map { String(cString: $0) } ?? "unknown error"
            DispatchQueue.main.async {
                self.progress = nil
                self.ready = muguet_game_ready()
                if let message { self.error = "Import failed: \(message)" }
            }
        }
    }
}

struct LauncherView: View {
    @StateObject private var s = Settings()
    @ObservedObject private var importer = Importer.shared
    @State private var error: String?
    @State private var picking = false
    let play: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 16) {
                Text("Muguet").font(.largeTitle.weight(.bold))
                if !muguet_has_game_code() {
                    Text("This build has no game code: build it with ./make-ios.sh <game.zip>.")
                        .foregroundStyle(.red).font(.callout).multilineTextAlignment(.center)
                } else if !importer.ready || importer.progress != nil {
                    importView
                } else {
                    if let error { Text(error).foregroundStyle(.red).font(.callout).multilineTextAlignment(.center) }
                    playButton
                    Button("Import other game data…") { picking = true }.font(.caption)
                }
                Text("proudly made by c22dev").font(.caption).foregroundStyle(.secondary)
                Text("Rebuild: iOSVN").font(.caption).foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            Form {
                Section("Tên nhân vật / Người chơi") {
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundStyle(.blue)
                        TextField("Nhập tên nhân vật...", text: $s.name)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                    }
                    Text("Tên này sẽ hiển thị trên đầu nhân vật của bạn khi chơi cùng bạn bè.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Picker("Mode", selection: $s.mode) {
                    Text("Story Mode").tag(1)
                    Text("Sandbox").tag(2)
                }
                Picker("Resolution", selection: $s.scale) {
                    Text("35 % (fastest)").tag(0.35)
                    Text("50 %").tag(0.5)
                    Text("75 %").tag(0.75)
                    Text("100 % (sharpest)").tag(1.0)
                }
                Picker("Textures", selection: $s.textures) {
                    Text("Normal (less memory)").tag(0)
                    Text("High").tag(1)
                    Text("Very High").tag(2)
                }
                Picker("Frame limit", selection: $s.fps) {
                    Text("30 fps (cooler)").tag(30)
                    Text("60 fps").tag(60)
                    if UIScreen.main.maximumFramesPerSecond >= 120 { Text("120 fps (ProMotion)").tag(120) }
                }
                Text("Higher frame rates use more power. Low memory automatically reduces the render limit.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Text("Look sensitivity")
                    Slider(value: $s.touch, in: 0.25...6.0, step: 0.25)
                    Text(String(format: "%.2f×", s.touch)).monospacedDigit().frame(width: 55, alignment: .trailing)
                }
                Section("Aiming") {
                    Picker("Aim button", selection: $s.aimMode) {
                        Text("Tap to toggle").tag("toggle")
                        Text("Hold to aim").tag("hold")
                    }
                    Toggle("Aim while firing", isOn: $s.fireAim)
                    HStack {
                        Text("Aim sensitivity")
                        Slider(value: $s.aimSensitivity, in: 0.1...3.0, step: 0.1)
                        Text(String(format: "%.2f×", s.aimSensitivity)).monospacedDigit().frame(width: 55, alignment: .trailing)
                    }
                    Text("Drag on the right FIRE button to adjust aim while shooting. The left FIRE button frees your right thumb to aim.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Toggle("Mute audio", isOn: $s.mute)
                Section("Chơi Online (Multiplayer)") {
                    Toggle("Bật chế độ Multiplayer", isOn: $s.multiplayer)
                    if s.multiplayer {
                        Picker("Loại phòng", selection: $s.roomMode) {
                            Text("Tạo phòng").tag("create")
                            Text("Vào phòng").tag("join")
                            Text("LAN Host").tag("lan")
                        }
                        .pickerStyle(.segmented)

                        if s.roomMode == "create" {
                            HStack {
                                Text("Mã phòng:")
                                    .fontWeight(.medium)
                                Text(s.room)
                                    .font(.title3.monospaced().bold())
                                    .foregroundStyle(.green)
                                Spacer()
                                Button(action: {
                                    s.room = String(Int.random(in: 1000...9999))
                                }) {
                                    Label("Đổi mã", systemImage: "arrow.clockwise")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                            }
                            Text("Đọc mã phòng này cho bạn bè để cùng vào một phòng riêng trên máy chủ AWS!")
                                .font(.caption).foregroundStyle(.secondary)
                        } else if s.roomMode == "join" {
                            HStack {
                                Text("Mã phòng:")
                                    .fontWeight(.medium)
                                TextField("Ví dụ: 8621", text: $s.room)
                                    .keyboardType(.numbersAndPunctuation)
                                    .autocorrectionDisabled()
                                    .font(.title3.monospaced().bold())
                            }
                            Text("Nhập mã phòng do người tạo phòng chia sẻ.")
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            Text("Mở phòng trên Wi-Fi: Bạn bè kết nối qua: \(localIPs().joined(separator: " hoặc "))")
                                .font(.callout).textSelection(.enabled)
                        }

                        Toggle("Bật sát thương người chơi (PvP)", isOn: $s.pvp)
                        Text(s.pvp ? "PvP Bật: Người chơi có thể bắn và gây sát thương lẫn nhau." : "Chế độ Hòa bình (Khuyên dùng): Không gây sát thương lẫn nhau, tránh bắn nhau loạn xạ khi mới spawn.")
                            .font(.caption).foregroundStyle(.secondary)

                        DisclosureGroup("Máy chủ (Nâng cao)") {
                            HStack {
                                Text("Server IP:")
                                TextField("18.143.103.253", text: $s.server)
                                    .keyboardType(.numbersAndPunctuation)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                            }
                            HStack {
                                Circle().fill(Color.green).frame(width: 8, height: 8)
                                Text("Server AWS iOSVN (Singapore ~40ms ping)")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section("Save Data") {
                    Button("Share / Backup saves") { shareSaves() }
                    Text("In game: save via Phone > Quick Save, or Pause > Game > Save Game. Saves are stored in Files app > On My iPhone > Muguet > saves.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Diagnostics") {
                    Button("Share startup / memory logs") { shareDiagnostics() }
                    Text("After a crash, reopen Muguet and share the previous log. Logs contain connection addresses and runtime errors, not game files.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .preferredColorScheme(.dark)
        .fileImporter(isPresented: $picking, allowedContentTypes: [.zip]) { result in
            if case .success(let url) = result { importer.run(url) }
        }
    }

    @ViewBuilder var importView: some View {
        VStack(spacing: 12) {
            if let p = importer.progress {
                ProgressView(value: p)
                Text("Importing… \(Int(p * 100)) %").font(.callout).monospacedDigit()
            } else {
                Button("Import game data .zip") { picking = true }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
            }
            if let e = importer.error { Text(e).foregroundStyle(.red).font(.callout).multilineTextAlignment(.center) }
        }
    }

    @ViewBuilder var playButton: some View {
        let button = Button(action: start) {
            Text("Play").font(.title3.weight(.semibold)).frame(maxWidth: 220)
        }
        .controlSize(.large)
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            button.buttonStyle(.glassProminent)
        } else {
            button.buttonStyle(.borderedProminent)
        }
        #else
        button.buttonStyle(.borderedProminent)
        #endif
    }

    func start() {
        if s.multiplayer && s.roomMode == "join" && s.room.trimmingCharacters(in: .whitespaces).isEmpty {
            error = "Nhập mã phòng để vào chơi cùng bạn bè."
            return
        }
        if s.multiplayer && s.roomMode != "lan" && s.server.trimmingCharacters(in: .whitespaces).isEmpty {
            error = "Nhập địa chỉ máy chủ để kết nối."
            return
        }
        if s.name.trimmingCharacters(in: .whitespaces).isEmpty {
            s.name = "Player" + String(Int.random(in: 100...999))
        }
        do { try s.save() } catch { self.error = "Could not save settings: \(error.localizedDescription)"; return }
        play()
    }
}

@_cdecl("muguet_physical_memory")
public func muguetPhysicalMemory() -> UInt64 { ProcessInfo.processInfo.physicalMemory }

private final class RefreshHint: NSObject {
    static let shared = RefreshHint()
    var link: CADisplayLink?
    @objc func tick(_ link: CADisplayLink) {}
    func set(_ requested: UInt32) {
        let maximum = Float(UIScreen.main.maximumFramesPerSecond)
        let rate = requested == 0 ? maximum : min(maximum, Float(requested))
        if link == nil {
            link = CADisplayLink(target: self, selector: #selector(tick(_:)))
            link?.add(to: .main, forMode: .common)
        }
        link?.preferredFrameRateRange = CAFrameRateRange(minimum: min(30, rate), maximum: rate, preferred: rate)
    }
}

@_cdecl("muguet_set_refresh_rate")
public func muguetSetRefreshRate(_ fps: UInt32) {
    DispatchQueue.main.async { RefreshHint.shared.set(fps) }
}

func shareDiagnostics() {
    let folder = configURL.deletingLastPathComponent()
    let logs = ["muguet-previous.log", "muguet-runtime.log"].map { folder.appendingPathComponent($0) }
        .filter { FileManager.default.fileExists(atPath: $0.path) }
    guard !logs.isEmpty,
          let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = scene.windows.first(where: { $0.isKeyWindow }),
          let root = window.rootViewController else { return }
    var presenter = root
    while let child = presenter.presentedViewController { presenter = child }
    let sheet = UIActivityViewController(activityItems: logs, applicationActivities: nil)
    if let popover = sheet.popoverPresentationController {
        popover.sourceView = presenter.view
        popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 1, height: 1)
    }
    presenter.present(sheet, animated: true)
}


func shareSaves() {
    let folder = configURL.deletingLastPathComponent().appendingPathComponent("saves")
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = scene.windows.first(where: { $0.isKeyWindow }),
          let root = window.rootViewController else { return }
    var presenter = root
    while let child = presenter.presentedViewController { presenter = child }
    let sheet = UIActivityViewController(activityItems: [folder], applicationActivities: nil)
    if let popover = sheet.popoverPresentationController {
        popover.sourceView = presenter.view
        popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 1, height: 1)
    }
    presenter.present(sheet, animated: true)
}
func localIPs() -> [String] {
    var out: [String] = []
    var ifs: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifs) == 0, let first = ifs else { return ["?"] }
    defer { freeifaddrs(ifs) }
    for p in sequence(first: first, next: { $0.pointee.ifa_next }) {
        guard let a = p.pointee.ifa_addr, a.pointee.sa_family == UInt8(AF_INET) else { continue }
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        if getnameinfo(a, socklen_t(a.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
            let ip = String(cString: host)
            if !ip.hasPrefix("127.") && !out.contains(ip) { out.append(ip) }
        }
    }
    return out.isEmpty ? ["?"] : out
}

@_cdecl("muguet_show_launcher")
public func muguetShowLauncher(_ viewController: UnsafeMutableRawPointer, _ done: @convention(c) () -> Void) {
    let parent = Unmanaged<UIViewController>.fromOpaque(viewController).takeUnretainedValue()
    weak var sheet: UIViewController?
    let host = UIHostingController(rootView: LauncherView(play: {
        sheet?.dismiss(animated: true)
        done()
    }))
    sheet = host
    host.modalPresentationStyle = .fullScreen
    host.isModalInPresentation = true
    parent.present(host, animated: false)
}
