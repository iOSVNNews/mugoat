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
    @Published var roomDigits = String(Int.random(in: 1000...9999))
    @Published var joinCode = ""
    @Published var roomPass = ""
    @Published var roomMode = "create" // "create", "join", "public", "lan"
    @Published var pvp = false
    @Published var promotionSync = true
    @Published var buttonScale = 1.0
    @Published var buttonOffsetX = 0.0
    @Published var buttonOffsetY = 0.0
    @Published var buttonOpacity = 0.22
    @Published var stickOffsetX = 0.0
    @Published var stickOffsetY = 0.0
    var extra: [String: Any] = [:]

    var formattedCreateCode: String {
        let m = mode == 1 ? "S" : "B"
        let p = pvp ? "X" : "P"
        return "\(m)\(p)-\(roomDigits)"
    }

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
        if let v = json["room_digits"] as? String, !v.trimmingCharacters(in: .whitespaces).isEmpty {
            roomDigits = v
        } else if let v = json["room"] as? String {
            let digits = v.filter { $0.isNumber }
            if !digits.isEmpty { roomDigits = String(digits.prefix(4)) }
        }
        if let v = json["join_code"] as? String { joinCode = v }
        if let v = json["room_pass"] as? String { roomPass = v }
        if let v = json["room_mode"] as? String, ["create", "join", "public", "lan"].contains(v) { roomMode = v }
        if let v = json["pvp"] as? Bool { pvp = v }
        if let v = json["promotion_sync"] as? Bool { promotionSync = v }
        if let v = json["button_scale"] as? Double { buttonScale = max(0.6, min(2.0, v)) }
        if let v = json["button_offset_x"] as? Double { buttonOffsetX = max(-150.0, min(150.0, v)) }
        if let v = json["button_offset_y"] as? Double { buttonOffsetY = max(-150.0, min(150.0, v)) }
        if let v = json["button_opacity"] as? Double { buttonOpacity = max(0.1, min(0.9, v)) }
        if let v = json["stick_offset_x"] as? Double { stickOffsetX = max(-100.0, min(150.0, v)) }
        if let v = json["stick_offset_y"] as? Double { stickOffsetY = max(-100.0, min(150.0, v)) }
        if let v = json["player_name"] as? String, !v.trimmingCharacters(in: .whitespaces).isEmpty && v != "iPhone" && v != "iPad" {
            name = v
        }
    }

    func parseJoinCode(_ code: String) {
        let clean = code.trimmingCharacters(in: .whitespaces).uppercased()
        if clean.hasPrefix("S") {
            mode = 1
        } else if clean.hasPrefix("B") {
            mode = 2
        }
        if clean.contains("X") {
            pvp = true
        } else if clean.contains("P") {
            pvp = false
        }
    }

    func save() throws {
        var json = extra
        let srv = server.trimmingCharacters(in: .whitespaces)
        json["server"] = srv.isEmpty ? "18.143.103.253" : srv
        json["multiplayer"] = multiplayer
        json["host"] = (roomMode == "lan")
        json["room_mode"] = roomMode
        json["promotion_sync"] = promotionSync
        json["room_digits"] = roomDigits
        json["join_code"] = joinCode

        if multiplayer {
            if roomMode == "create" {
                let m = mode == 1 ? "story" : "sandbox"
                let r = pvp ? "pvp" : "peace"
                let rm = "\(m)-\(r)-\(roomDigits)"
                json["room"] = rm
                json["room_pass"] = roomPass.trimmingCharacters(in: .whitespaces)
                json["start_mode"] = mode
                json["pvp"] = pvp
            } else if roomMode == "join" {
                parseJoinCode(joinCode)
                let m = mode == 1 ? "story" : "sandbox"
                let r = pvp ? "pvp" : "peace"
                let digits = joinCode.filter { $0.isNumber }
                let rm = "\(m)-\(r)-\(digits.isEmpty ? "default" : digits)"
                json["room"] = rm
                json["room_pass"] = roomPass.trimmingCharacters(in: .whitespaces)
                json["start_mode"] = mode
                json["pvp"] = pvp
            } else if roomMode == "public" {
                let m = mode == 1 ? "story" : "sandbox"
                json["room"] = "\(m)-public"
                json["room_pass"] = ""
                json["start_mode"] = mode
                json["pvp"] = false
            } else { // lan
                let m = mode == 1 ? "story" : "sandbox"
                json["room"] = "\(m)-lan"
                json["room_pass"] = ""
                json["start_mode"] = mode
                json["pvp"] = pvp
            }
        } else {
            json["start_mode"] = mode
            json["room"] = "default"
            json["room_pass"] = ""
            json["pvp"] = false
        }

        json["scale"] = scale
        json["fps_limit"] = fps
        json["texture_quality"] = textures
        json["touch_sensitivity"] = (touch * 100).rounded() / 100
        json["aim_sensitivity"] = (aimSensitivity * 100).rounded() / 100
        json["aim_mode"] = aimMode
        json["fire_aim"] = fireAim
        json["mute"] = mute
        json["button_scale"] = (buttonScale * 100).rounded() / 100
        json["button_offset_x"] = (buttonOffsetX * 10).rounded() / 10
        json["button_offset_y"] = (buttonOffsetY * 10).rounded() / 10
        json["button_opacity"] = (buttonOpacity * 100).rounded() / 100
        json["stick_offset_x"] = (stickOffsetX * 10).rounded() / 10
        json["stick_offset_y"] = (stickOffsetY * 10).rounded() / 10
        let nm = name.trimmingCharacters(in: .whitespaces)
        json["player_name"] = nm.isEmpty ? "Player" : nm
        if json["extra_args"] == nil { json["extra_args"] = [String]() }
        let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: configURL)
    }

    func resetLayout() {
        buttonScale = 1.0
        buttonOffsetX = 0.0
        buttonOffsetY = 0.0
        buttonOpacity = 0.22
        stickOffsetX = 0.0
        stickOffsetY = 0.0
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
@_silgen_name("muguet_reload_settings")
func muguet_reload_settings()
@_silgen_name("muguet_apply_cheat")
func muguet_apply_cheat(_ code: UnsafePointer<CChar>)
@_silgen_name("muguet_is_multiplayer")
func muguet_is_multiplayer() -> Bool
@_silgen_name("muguet_toggle_first_person")
func muguet_toggle_first_person()

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

struct CheatItem: Identifiable {
    let id = UUID()
    let code: String
    let name: String
    let desc: String
    let category: String
}

let CHEAT_LIST: [CheatItem] = [
    CheatItem(code: "PAINKILLER", name: "Bất tử 5 phút", desc: "Không nhận sát thương trong 5 phút", category: "Nhân vật"),
    CheatItem(code: "TURTLE", name: "Đầy Máu & Giáp", desc: "Hồi phục 100% máu, giáp và sửa xe", category: "Nhân vật"),
    CheatItem(code: "TOOLUP", name: "Tất cả Vũ khí", desc: "Nhận full tất cả vũ khí và đạn", category: "Nhân vật"),
    CheatItem(code: "LAWYERUP", name: "Xóa sao cảnh sát", desc: "Giảm mức độ truy nã về 0", category: "Nhân vật"),
    CheatItem(code: "FUGITIVE", name: "Tăng 1 sao cảnh sát", desc: "Tăng thêm 1 cấp độ truy nã", category: "Nhân vật"),
    CheatItem(code: "POWERUP", name: "Đầy kỹ năng", desc: "Nạp đầy thanh kỹ năng nhân vật", category: "Nhân vật"),
    CheatItem(code: "CATCHME", name: "Chạy siêu nhanh", desc: "Tăng tốc độ di chuyển tối đa", category: "Nhân vật"),
    CheatItem(code: "GOTGILLS", name: "Bơi siêu nhanh", desc: "Tăng tốc độ bơi dưới nước", category: "Nhân vật"),
    CheatItem(code: "HOPTOIT", name: "Siêu nhảy", desc: "Nhảy cao gấp 10 lần bình thường", category: "Nhân vật"),
    CheatItem(code: "SKYDIVE", name: "Trang bị Dù nhảy", desc: "Nhận dù để nhảy từ trên cao", category: "Nhân vật"),

    CheatItem(code: "BUZZOFF", name: "Trực thăng Buzzard", desc: "Trực thăng chiến đấu có súng & tên lửa", category: "Phương tiện"),
    CheatItem(code: "COMET", name: "Xe thể thao Comet", desc: "Xe Porsche 2 cửa siêu tốc", category: "Phương tiện"),
    CheatItem(code: "RAPIDGT", name: "Xe đua Rapid GT", desc: "Xe thể thao cao cấp", category: "Phương tiện"),
    CheatItem(code: "ROCKET", name: "Mô tô đua PCJ-600", desc: "Xe máy phân khối lớn tốc độ cao", category: "Phương tiện"),
    CheatItem(code: "OFFROAD", name: "Xe cào cào Sanchez", desc: "Mô tô địa hình vượt đồi núi", category: "Phương tiện"),
    CheatItem(code: "BANDIT", name: "Xe đạp BMX", desc: "Xe đạp biểu diễn nhào lộn", category: "Phương tiện"),
    CheatItem(code: "BARNSTORM", name: "Máy bay Stunt Plane", desc: "Máy bay nhào lộn cánh quạt", category: "Phương tiện"),
    CheatItem(code: "VINEWOOD", name: "Xe Limousine", desc: "Xe sang trọng kéo dài", category: "Phương tiện"),
    CheatItem(code: "TRASHED", name: "Xe rác Trashmaster", desc: "Xe chở rác bọc thép húc xe khác", category: "Phương tiện"),

    CheatItem(code: "HOTHANDS", name: "Nắm đấm phát nổ", desc: "Đấm kẻ địch văng xa và phát nổ", category: "Chiến đấu"),
    CheatItem(code: "INCENDIARY", name: "Đạn lửa", desc: "Bắn ra đạn thiêu đốt mục tiêu", category: "Chiến đấu"),
    CheatItem(code: "HIGHEX", name: "Đạn nổ", desc: "Mỗi phát bắn tạo ra vụ nổ lớn", category: "Chiến đấu"),
    CheatItem(code: "DEADEYE", name: "Làm chậm khi ngắm", desc: "Làm chậm thời gian khi giữ nút ngắm", category: "Chiến đấu"),
    CheatItem(code: "SLOWMO", name: "Làm chậm toàn game", desc: "Hiệu ứng slow-motion điện ảnh", category: "Thế giới"),
    CheatItem(code: "FLOATER", name: "Trọng lực Mặt Trăng", desc: "Xe và người bay lơ lửng nhẹ", category: "Thế giới"),
    CheatItem(code: "MAKEITRAIN", name: "Đổi thời tiết", desc: "Thay đổi nắng, mưa, bão sấm chớp", category: "Thế giới"),
    CheatItem(code: "SNOW", name: "Tuyết rơi", desc: "Kích hoạt hiệu ứng tuyết rơi toàn map", category: "Thế giới")
]

struct CheatMenuView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var customCode = ""
    @State private var toastMessage: String?
    let onApply: (String) -> Void

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Nhập lệnh tùy chỉnh")) {
                    HStack {
                        TextField("Nhập mã lệnh (vd: PAINKILLER)", text: $customCode)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                        Button("Áp dụng") {
                            let c = customCode.trimmingCharacters(in: .whitespaces).uppercased()
                            guard !c.isEmpty else { return }
                            apply(c)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                ForEach(["Nhân vật", "Phương tiện", "Chiến đấu", "Thế giới"], id: \.self) { cat in
                    Section(header: Text(cat)) {
                        ForEach(CHEAT_LIST.filter { $0.category == cat }) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text(item.name).fontWeight(.semibold)
                                        Text("(\(item.code))").font(.caption.monospaced()).foregroundStyle(.secondary)
                                    }
                                    Text(item.desc).font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(action: { apply(item.code) }) {
                                    Text("Bật").font(.caption.weight(.bold)).padding(.horizontal, 10).padding(.vertical, 4)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Lệnh Cheat GTA V (Offline)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
            .overlay(alignment: .bottom) {
                if let msg = toastMessage {
                    Text(msg)
                        .font(.callout.bold())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .shadow(radius: 5)
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    private func apply(_ code: String) {
        onApply(code)
        withAnimation { toastMessage = "Đã gửi lệnh cheat: \(code)" }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            dismiss()
        }
    }
}

struct LauncherView: View {
    @StateObject private var s = Settings()
    @ObservedObject private var importer = Importer.shared
    @State private var error: String?
    @State private var picking = false
    @State private var showingCheatSheet = false
    var isOverlay: Bool = false
    let play: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 16) {
                Text(isOverlay ? "Muguet Menu" : "Muguet").font(.largeTitle.weight(.bold))
                if !muguet_has_game_code() {
                    Text("This build has no game code: build it with ./make-ios.sh <game.zip>.")
                        .foregroundStyle(.red).font(.callout).multilineTextAlignment(.center)
                } else if !importer.ready || importer.progress != nil {
                    importView
                } else if isOverlay {
                    Button(action: resumeAndSave) {
                        Text("Tiếp tục (Resume)").font(.title3.weight(.semibold)).frame(maxWidth: 220)
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    Button(action: { exit(0) }) {
                        Text("Thoát hẳn ứng dụng (Exit)").font(.callout.weight(.medium)).frame(maxWidth: 220)
                    }
                    .controlSize(.regular)
                    .buttonStyle(.bordered)
                    .tint(.red)
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

                if !s.multiplayer {
                    Picker("Mode", selection: $s.mode) {
                        Text("Story Mode (Cốt truyện)").tag(1)
                        Text("Sandbox (Tự do)").tag(2)
                    }
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

                Section("Tối ưu hiệu năng (MeloNX & ProMotion)") {
                    Toggle("Khóa nhịp CADisplayLink ProMotion", isOn: $s.promotionSync)
                    Text("Đồng bộ phần cứng nhịp quét 60Hz/120Hz của iPhone/iPad với render loop, triệt tiêu micro-stutter và ngăn ngừa hiện tượng crash nóng máy.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Tùy chỉnh Giao diện Nút Bấm (Touch Controls)") {
                    HStack {
                        Text("Kích thước nút")
                        Slider(value: $s.buttonScale, in: 0.7...1.5, step: 0.05)
                        Text(String(format: "%.2f×", s.buttonScale)).monospacedDigit().frame(width: 55, alignment: .trailing)
                    }
                    HStack {
                        Text("Độ trong suốt nút")
                        Slider(value: $s.buttonOpacity, in: 0.12...0.70, step: 0.02)
                        Text(String(format: "%.0f%%", s.buttonOpacity * 100)).monospacedDigit().frame(width: 55, alignment: .trailing)
                    }
                    HStack {
                        Text("Dời cụm nút (Ngang X)")
                        Slider(value: $s.buttonOffsetX, in: -60.0...60.0, step: 5.0)
                        Text(String(format: "%+.0f", s.buttonOffsetX)).monospacedDigit().frame(width: 55, alignment: .trailing)
                    }
                    HStack {
                        Text("Dời cụm nút (Dọc Y)")
                        Slider(value: $s.buttonOffsetY, in: -60.0...60.0, step: 5.0)
                        Text(String(format: "%+.0f", s.buttonOffsetY)).monospacedDigit().frame(width: 55, alignment: .trailing)
                    }
                    HStack {
                        Text("Dời Joystick (Ngang X)")
                        Slider(value: $s.stickOffsetX, in: -40.0...60.0, step: 5.0)
                        Text(String(format: "%+.0f", s.stickOffsetX)).monospacedDigit().frame(width: 55, alignment: .trailing)
                    }
                    HStack {
                        Text("Dời Joystick (Dọc Y)")
                        Slider(value: $s.stickOffsetY, in: -40.0...60.0, step: 5.0)
                        Text(String(format: "%+.0f", s.stickOffsetY)).monospacedDigit().frame(width: 55, alignment: .trailing)
                    }
                    Button("Khôi phục mặc định nút bấm") {
                        s.resetLayout()
                    }
                    .font(.caption)
                    .foregroundStyle(.orange)
                }

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
                        Picker("Chế độ phòng", selection: $s.roomMode) {
                            Text("Tạo phòng").tag("create")
                            Text("Vào phòng").tag("join")
                            Text("Công khai").tag("public")
                            Text("LAN Host").tag("lan")
                        }
                        .pickerStyle(.segmented)

                        if s.roomMode == "create" {
                            VStack(alignment: .leading, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("1. Chọn Chế độ phòng:").font(.subheadline.bold())
                                    Picker("Mode", selection: $s.mode) {
                                        Text("Story Mode (Cốt truyện)").tag(1)
                                        Text("Sandbox (Tự do)").tag(2)
                                    }
                                    .pickerStyle(.segmented)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("2. Luật sát thương (PvP):").font(.subheadline.bold())
                                    Picker("PvP", selection: $s.pvp) {
                                        Text("🛡️ Hòa bình (Co-op)").tag(false)
                                        Text("⚔️ Đấu trường (PvP)").tag(true)
                                    }
                                    .pickerStyle(.segmented)
                                    Text(s.pvp ? "PvP Bật: Người chơi có thể bắn và tiêu diệt nhau." : "Hòa bình: Không gây sát thương lẫn nhau, tránh bắn nhau khi spawn.")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("3. Mã phòng chia sẻ cho bạn bè:").font(.subheadline.bold())
                                    HStack {
                                        Text(s.formattedCreateCode)
                                            .font(.title2.monospaced().bold())
                                            .foregroundStyle(.green)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.green.opacity(0.15))
                                            .clipShape(RoundedRectangle(cornerRadius: 8))

                                        Spacer()

                                        Button(action: {
                                            s.roomDigits = String(Int.random(in: 1000...9999))
                                        }) {
                                            Label("Đổi mã", systemImage: "arrow.clockwise")
                                                .font(.caption)
                                        }
                                        .buttonStyle(.bordered)

                                        Button(action: {
                                            UIPasteboard.general.string = s.formattedCreateCode
                                        }) {
                                            Label("Sao chép", systemImage: "doc.on.doc")
                                                .font(.caption)
                                        }
                                        .buttonStyle(.borderedProminent)
                                    }
                                }

                                HStack {
                                    Image(systemName: "lock.fill").foregroundStyle(.secondary)
                                    TextField("Mật khẩu phòng (Tùy chọn)", text: $s.roomPass)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                }

                                HStack(spacing: 8) {
                                    Label(s.mode == 1 ? "Story Mode" : "Sandbox", systemImage: "gamecontroller")
                                        .font(.caption.bold())
                                        .foregroundStyle(s.mode == 1 ? .orange : .cyan)
                                    Text("•")
                                    Label(s.pvp ? "PvP Bật" : "Hòa bình Co-op", systemImage: s.pvp ? "burst.fill" : "shield.fill")
                                        .font(.caption.bold())
                                        .foregroundStyle(s.pvp ? .red : .green)
                                    Text("•")
                                    Label(s.roomPass.isEmpty ? "Phòng Mở" : "Có Pass", systemImage: s.roomPass.isEmpty ? "lock.open" : "lock")
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                }
                                .padding(8)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        } else if s.roomMode == "join" {
                            VStack(alignment: .leading, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Nhập mã phòng:").font(.subheadline.bold())
                                    TextField("Ví dụ: SP-8621 hoặc BX-5520", text: $s.joinCode)
                                        .font(.title3.monospaced().bold())
                                        .textInputAutocapitalization(.characters)
                                        .autocorrectionDisabled()
                                        .onChange(of: s.joinCode) { val in
                                            s.parseJoinCode(val)
                                        }
                                }

                                let clean = s.joinCode.trimmingCharacters(in: .whitespaces).uppercased()
                                if !clean.isEmpty {
                                    HStack(spacing: 8) {
                                        Label(s.mode == 1 ? "Story Mode" : "Sandbox", systemImage: "gamecontroller")
                                            .font(.caption.bold())
                                            .foregroundStyle(s.mode == 1 ? .orange : .cyan)
                                        Text("•")
                                        Label(s.pvp ? "PvP Bật" : "Hòa bình Co-op", systemImage: s.pvp ? "burst.fill" : "shield.fill")
                                            .font(.caption.bold())
                                            .foregroundStyle(s.pvp ? .red : .green)
                                        Spacer()
                                        Text("Đã đồng bộ tự động")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(8)
                                    .background(Color.green.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    Text("Chế độ chơi (Story / Sandbox) và luật PvP tự động đồng bộ theo mã phòng của chủ phòng.")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }

                                HStack {
                                    Image(systemName: "lock.fill").foregroundStyle(.secondary)
                                    TextField("Mật khẩu phòng (nếu chủ phòng đặt)", text: $s.roomPass)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                }

                                Text("Lưu ý: Luật sát thương PvP và Chế độ chơi hoàn toàn tuân theo chủ phòng, không thể tự đổi.")
                                    .font(.caption2).foregroundStyle(.orange)
                            }
                        } else if s.roomMode == "public" {
                            VStack(alignment: .leading, spacing: 10) {
                                Picker("Phân vùng công khai", selection: $s.mode) {
                                    Text("Story Mode Public").tag(1)
                                    Text("Sandbox Public").tag(2)
                                }
                                .pickerStyle(.segmented)

                                HStack {
                                    Image(systemName: "globe.americas.fill").foregroundStyle(.green)
                                    Text("Sảnh chung công khai (Tối đa 32 người/phòng)")
                                        .fontWeight(.medium)
                                }
                                Text("Tự động kết nối vào sảnh chung với người chơi trực tuyến trên server AWS iOSVN. Chế độ Hòa bình bật mặc định.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Picker("Chế độ LAN", selection: $s.mode) {
                                    Text("Story Mode").tag(1)
                                    Text("Sandbox").tag(2)
                                }
                                .pickerStyle(.segmented)
                                Text("Mở phòng trên Wi-Fi (Tối đa 32 người): Kết nối qua: \(localIPs().joined(separator: " hoặc "))")
                                    .font(.callout).textSelection(.enabled)
                            }
                        }

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
                                Text("Server AWS iOSVN Singapore (Ping ~40ms, Tối đa 32 người)")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if !s.multiplayer {
                    Section("Lệnh Cheat GTA V (Chỉ Offline)") {
                        Button(action: { showingCheatSheet = true }) {
                            Label("Xem & Kích hoạt Lệnh Cheat", systemImage: "wand.and.stars")
                        }
                        Text("Tra cứu và kích hoạt nhanh các lệnh cheat (Bất tử, full vũ khí, trực thăng, xe đua...). Lệnh cheat tự động bị khóa trong chế độ Online.")
                            .font(.caption).foregroundStyle(.secondary)
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
        .sheet(isPresented: $showingCheatSheet) {
            CheatMenuView(onApply: { code in
                code.withCString { muguet_apply_cheat($0) }
            })
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

    func resumeAndSave() {
        do { try s.save() } catch {}
        play()
        muguet_reload_settings()
    }

    func start() {
        if s.multiplayer && s.roomMode == "join" {
            let digits = s.joinCode.filter { $0.isNumber }
            if digits.isEmpty {
                error = "Nhập mã phòng (vd: SP-8621) để vào chơi cùng bạn bè."
                return
            }
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
    private let condition = NSCondition()
    private var vsyncCount: UInt64 = 0
    var lockedPacingEnabled: Bool = false

    @objc func tick(_ link: CADisplayLink) {
        guard lockedPacingEnabled else { return }
        condition.lock()
        vsyncCount &+= 1
        condition.broadcast()
        condition.unlock()
    }

    func set(_ requested: UInt32, lockedPacing: Bool = false) {
        self.lockedPacingEnabled = lockedPacing
        let maximum = Float(UIScreen.main.maximumFramesPerSecond)
        let rate = requested == 0 ? maximum : min(maximum, Float(requested))
        if link == nil {
            link = CADisplayLink(target: self, selector: #selector(tick(_:)))
            link?.add(to: .main, forMode: .common)
        }
        if lockedPacing {
            link?.preferredFrameRateRange = CAFrameRateRange(minimum: rate, maximum: rate, preferred: rate)
        } else {
            link?.preferredFrameRateRange = CAFrameRateRange(minimum: min(30, rate), maximum: rate, preferred: rate)
        }
    }

    func waitVsync(timeoutMs: UInt32) -> Bool {
        guard lockedPacingEnabled else { return true }
        condition.lock()
        let current = vsyncCount
        let deadline = Date(timeIntervalSinceNow: Double(timeoutMs) / 1000.0)
        var signaled = false
        while vsyncCount == current {
            if !condition.wait(until: deadline) {
                break
            }
            signaled = true
        }
        condition.unlock()
        return signaled
    }
}

@_cdecl("muguet_set_refresh_rate")
public func muguetSetRefreshRate(_ fps: UInt32) {
    let settings = Settings()
    DispatchQueue.main.async { RefreshHint.shared.set(fps, lockedPacing: settings.promotionSync) }
}

@_cdecl("muguet_wait_vsync")
public func muguetWaitVsync(_ timeoutMs: UInt32) -> Bool {
    return RefreshHint.shared.waitVsync(timeoutMs: timeoutMs)
}

@_cdecl("muguet_open_menu")
public func muguetOpenMenu() {
    DispatchQueue.main.async {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }),
              let root = window.rootViewController else { return }
        var presenter = root
        while let child = presenter.presentedViewController { presenter = child }

        let alert = UIAlertController(title: "Muguet Menu", message: "Chọn hành động:", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Tiếp tục chơi (Resume)", style: .cancel))

        let isMp = muguet_is_multiplayer()
        if !isMp {
            alert.addAction(UIAlertAction(title: "🎮 Bảng Lệnh Cheat (Offline)", style: .default, handler: { _ in
                let cheatHost = UIHostingController(rootView: CheatMenuView(onApply: { code in
                    code.withCString { muguet_apply_cheat($0) }
                }))
                presenter.present(cheatHost, animated: true)
            }))
        }

        alert.addAction(UIAlertAction(title: "📷 Đổi góc nhìn (1st / 3rd POV)", style: .default, handler: { _ in
            muguet_toggle_first_person()
        }))

        alert.addAction(UIAlertAction(title: "⚙️ Màn hình chính & Tùy chỉnh Nút", style: .default, handler: { _ in
            weak var sheet: UIViewController?
            let host = UIHostingController(rootView: LauncherView(isOverlay: true, play: {
                sheet?.dismiss(animated: true)
                muguet_reload_settings()
            }))
            sheet = host
            host.modalPresentationStyle = .fullScreen
            host.isModalInPresentation = true
            presenter.present(host, animated: true)
        }))

        alert.addAction(UIAlertAction(title: "🚪 Thoát ứng dụng nhanh", style: .destructive, handler: { _ in
            exit(0)
        }))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 1, height: 1)
        }
        presenter.present(alert, animated: true)
    }
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
    let host = UIHostingController(rootView: LauncherView(isOverlay: false, play: {
        sheet?.dismiss(animated: true)
        done()
    }))
    sheet = host
    host.modalPresentationStyle = .fullScreen
    host.isModalInPresentation = true
    parent.present(host, animated: false)
}
