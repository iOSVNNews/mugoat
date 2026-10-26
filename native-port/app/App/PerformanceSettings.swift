import Foundation

/// Engine switches from R007 (GTA NEW GEN, upstream 1.4.4 + Regeneration R005–R007) that fight lag and the
/// grey/missing map after long play. All but "smaller engine heaps" are on by default; the engine reads them
/// when it starts (Source/EngineHost.c, NativeThreads.c, MetalRenderer/MRRenderer.mm), so a change applies on
/// the next launch. A switch turned off sets the engine's own off value, unless a test launch already set it.
enum PerformanceSettings {
    private static let defaults = UserDefaults.standard
    private static func flag(_ key: String, _ fallback: Bool) -> Bool { defaults.object(forKey: key) as? Bool ?? fallback }

    /// GTA-128: the ground and roads turning grey after long play (the resource pool's free space counts as room).
    static var smarterTextureLoading: Bool {
        get { flag("expSmarterTextureLoading", true) }
        set { defaults.set(newValue, forKey: "expSmarterTextureLoading") }
    }
    /// GTA-122: the largest textures without their top level on GPUs that decode BC (iPhones before the 15 Pro).
    static var lighterBigTextures: Bool {
        get { flag("expLighterBigTextures", true) }
        set { defaults.set(newValue, forKey: "expLighterBigTextures") }
    }
    /// GTA-92: engine threads on the fast cores, GPU queries sent at once (steadier FPS; a little warmer).
    static var fastEngineThreads: Bool {
        get { flag("expFastEngineThreads", true) }
        set { defaults.set(newValue, forKey: "expFastEngineThreads") }
    }
    /// GTA-118: see-through textures (leaves, fences, smoke, decals) kept compressed as ASTC.
    static var compressedAlphaTextures: Bool {
        get { flag("expCompressedAlphaTextures", true) }
        set { defaults.set(newValue, forKey: "expCompressedAlphaTextures") }
    }
    /// GTA-124: replay and debug heaps 16/128 MB instead of 196/220 (more room for the world). Off by default.
    static var smallerEngineHeaps: Bool {
        get { flag("expSmallerEngineHeaps", false) }
        set { defaults.set(newValue, forKey: "expSmallerEngineHeaps") }
    }

    /// Call before PGStartEngine (GraphicsOptions.apply).
    static func applyBeforeBoot() {
        func off(_ name: String, _ value: String) { if getenv(name) == nil { setenv(name, value, 1) } }
        if !smarterTextureLoading { off("PG_GUARD_POOL_ROOM", "0") }
        if !lighterBigTextures { off("PG_BIG_MIP_SKIP", "0") }
        if !fastEngineThreads { off("PG_ENGINE_QOS", "off"); off("PG_QUERY_COMMIT_MS", "2") }
        if !compressedAlphaTextures { off("PG_ASTC_BC3", "0") }
        if smallerEngineHeaps { off("PG_SMALL_ENGINE_HEAPS", "1") }
        // R006/R007 distance streaming: reclaim memory only after moving, with a reserve sized for this iPhone.
        StreamingSettings.applyTextureBudget()
    }

    /// Engine options added to the preset's: the R007 extended draw distance (-MaxLODScale), when chosen.
    static var engineOptions: [String] {
        StreamingSettings.distanceScale.map { ["-MaxLODScale=\($0)"] } ?? []
    }

    static var summary: String {
        "R007 engine: smarter textures \(smarterTextureLoading ? "on" : "off"), lighter big textures \(lighterBigTextures ? "on" : "off"), fast threads \(fastEngineThreads ? "on" : "off"), compressed alpha \(compressedAlphaTextures ? "on" : "off"), small heaps \(smallerEngineHeaps ? "on" : "off"); distance streaming \(StreamingSettings.distanceStreaming ? "on" : "off"), reserve \(StreamingSettings.selectedReserveMB) MiB, \(StreamingSettings.reclaimDistance) m; texture budget \(StreamingSettings.textureBudgetMB) MiB (0 automatic)."
    }
}
