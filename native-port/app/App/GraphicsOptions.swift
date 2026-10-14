import Foundation
import Metal
import UIKit
import os

/// Graphics presets. The engine reads quality settings once at boot; only the
/// resolution can change while it runs.
enum GraphicsPreset: Int, CaseIterable {
    case battery, performance, balanced, quality, ultra, max

    var title: String { [L10n.text("Tiết kiệm pin"), L10n.text("Ưu tiên mượt"), L10n.text("Cân bằng"), L10n.text("Rõ nét"), L10n.text("Cao"), L10n.text("Tối đa")][rawValue] }
    /// Render height in pixels; width follows the screen's shape.
    var height: Int { [432, 540, 720, 900, 1080, 1080][rawValue] }
    var detail: String {
        [L10n.text("432p · ít tốn RAM và pin"), L10n.text("540p · giảm hiệu ứng nặng"), L10n.text("720p · cân bằng hình ảnh và tốc độ"),
         L10n.text("900p · tăng chi tiết và khoảng nhìn"), L10n.text("1080p · bóng và phản chiếu cao"),
         L10n.text("1080p · chi tiết đồ họa tối đa")][rawValue]
    }

    /// Engine command-line options. Shader quality never goes below 1 (the
    /// low shader set is mostly missing), and must not exceed 1 (Quality 2 shaders
    /// are not compiled for Metal). Tessellation, MSAA and depth of field stay off.
    var engineOptions: [String] {
        switch self {
        case .battery, .performance:
            return ["-shaderQuality=1", "-textureQuality=0", "-shadowQuality=-1", "-reflectionQuality=0", "-particleQuality=0",
                    "-grassQuality=0", "-cityDensity=0", "-lodScale=0", "-pedLodBias=0", "-vehicleLodBias=0", "-pedVariety=0", "-vehicleVariety=0"]
        case .balanced:
            return ["-shaderQuality=1", "-textureQuality=0", "-shadowQuality=0", "-reflectionQuality=0", "-particleQuality=0",
                    "-grassQuality=0", "-cityDensity=0.2", "-lodScale=0.2", "-pedLodBias=0", "-vehicleLodBias=0", "-pedVariety=0.2", "-vehicleVariety=0.2"]
        case .quality:
            return ["-shaderQuality=1", "-textureQuality=1", "-shadowQuality=0", "-reflectionQuality=1", "-particleQuality=1",
                    "-grassQuality=1", "-cityDensity=0.4", "-lodScale=0.4", "-pedLodBias=0.2", "-vehicleLodBias=0.2", "-pedVariety=0.4", "-vehicleVariety=0.4"]
        case .ultra:
            return ["-shaderQuality=1", "-textureQuality=1", "-shadowQuality=1", "-reflectionQuality=1", "-particleQuality=1",
                    "-grassQuality=1", "-cityDensity=0.6", "-lodScale=0.6", "-pedLodBias=0.4", "-vehicleLodBias=0.4", "-pedVariety=0.6", "-vehicleVariety=0.6"]
        case .max:
            return ["-shaderQuality=1", "-textureQuality=1", "-shadowQuality=1", "-reflectionQuality=2", "-particleQuality=1",
                    "-grassQuality=1", "-cityDensity=0.8", "-lodScale=0.8", "-pedLodBias=0.5", "-vehicleLodBias=0.5", "-pedVariety=0.8", "-vehicleVariety=0.8"]
        }
    }
}

/// What this device can afford, measured before the engine starts.
struct DeviceTier {
    let memoryLimitMB: Int
    let physicalMemoryMB: Int
    let model: String
    let supportsBCTextures: Bool

    static func probe() -> DeviceTier {
        var info = utsname(); uname(&info)
        let model = withUnsafeBytes(of: &info.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
        let device = MTLCreateSystemDefaultDevice()
        let supportsBC: Bool
        if #available(iOS 16.4, *) { supportsBC = device?.supportsBCTextureCompression ?? false }
        else { supportsBC = false }
        return DeviceTier(memoryLimitMB: Self.processMemoryLimitMB(),
                          physicalMemoryMB: Int(ProcessInfo.processInfo.physicalMemory / 1_048_576),
                          model: model,
                          supportsBCTextures: supportsBC)
    }

    /// Jetsam limit = memory still available + what the app already uses.
    private static func processMemoryLimitMB() -> Int {
        #if targetEnvironment(simulator)
        // Model the target phone (iPhone 13 Pro Max) unless told otherwise.
        return Int(ProcessInfo.processInfo.environment["PG_SIM_MEMORY_LIMIT_MB"] ?? "") ?? 4096
        #else
        var vm = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &vm) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) }
        }
        let footprint = result == KERN_SUCCESS ? Int(vm.phys_footprint) : 0
        return (Int(os_proc_available_memory()) + footprint) / 1_048_576
        #endif
    }

    /// The Metal renderer needs about 700 MB less than the old renderer did: a 6 GB phone on a
    /// free Apple ID (about 3 GB limit) runs Battery with room to spare.
    var recommended: GraphicsPreset {
        memoryLimitMB < 3400 ? .battery : memoryLimitMB < 4600 ? .performance : memoryLimitMB < 6000 ? .balanced : memoryLimitMB < 8000 ? .quality : .ultra
    }
    /// Every preset can be chosen; those above the recommended one show a warning.
    var allowed: [GraphicsPreset] { GraphicsPreset.allCases }
    /// Presets shown with a warning because they may run out of memory or heat up.
    func risky(_ preset: GraphicsPreset) -> Bool { preset.rawValue > recommended.rawValue }
    var summary: String { "\(model) · \(physicalMemoryMB / 1024) GB · app limit \(memoryLimitMB) MB\(supportsBCTextures ? " · BC textures" : "")" }
}

enum GraphicsConfiguration {
    /// The screen's height in pixels, clamped to safe 1080p maximum on iOS.
    static var nativeHeight: Int {
        let screen = UIScreen.main
        let raw = Int(min(screen.nativeBounds.width, screen.nativeBounds.height))
        return min(raw > 0 ? raw : 720, 1080)
    }
    /// Resolutions offered in Settings, besides "Auto" (the detail preset's own).
    static var resolutionChoices: [Int] {
        let standard = [540, 720, 900, 1080]
        var list = standard.filter { $0 <= nativeHeight }
        if !list.contains(nativeHeight) && nativeHeight >= 540 {
            list.append(nativeHeight)
            list.sort()
        }
        return list.isEmpty ? [720] : list
    }
    /// Width/height to render at: the chosen height (or the preset's), shaped like the screen so the
    /// picture is not stretched, clamped to 2560x1080 safe ceiling (matching Muguet parity).
    static func size(for preset: GraphicsPreset, renderHeight: Int, screen: CGSize, matchScreenShape: Bool) -> (Int, Int) {
        let aspect = matchScreenShape && screen.height > 0 ? max(screen.width, screen.height) / min(screen.width, screen.height) : 16.0 / 9.0
        var height = Double(renderHeight > 0 ? min(renderHeight, 1080) : preset.height)
        height = min(max(height, 360), Double(nativeHeight))
        var width = height * aspect
        let k = min(2560.0 / max(width, 1.0), min(1080.0 / max(height, 1.0), 1.0))
        width *= k
        height *= k
        func even(_ value: Double) -> Int { Int(value.rounded()) & ~1 }
        return (max(even(width), 320), max(even(height), 240))
    }

    /// Pass the chosen settings to the engine. Call before PGStartEngine.
    static func apply(_ settings: GameSettings, screen: CGSize) -> String {
        let preset = settings.graphicsPreset
        let (width, height) = size(for: preset, renderHeight: settings.renderHeight, screen: screen, matchScreenShape: settings.matchScreenShape)
        let options = preset.engineOptions
        var pointers = options.map { strdup($0) }
        defer { pointers.forEach { free($0) } }
        pointers.withUnsafeMutableBufferPointer { buffer in
            buffer.baseAddress!.withMemoryRebound(to: UnsafePointer<CChar>?.self, capacity: buffer.count) {
                PGConfigureEngine($0, UInt32(buffer.count), Int32(width), Int32(height), settings.frameRateCap == 0 ? 0 : settings.frameRateCap == 60 ? 1 : 2)
            }
        }
        return "\(preset.title) \(width)×\(height) at \(GameSettings.frameRateTitle(settings.frameRateCap))"
    }
}
