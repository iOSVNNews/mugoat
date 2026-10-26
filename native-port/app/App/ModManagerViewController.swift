import UIKit
import UniformTypeIdentifiers

/// Dedicated Mod Manager screen: manage installed mods, import mod archives/files (.zip, .rar, .oiv, .asi, loose),
/// import custom engine sound DLCs, import skin addons, toggle built-in Menyoo trainer,
/// and spawn installed add-on/DLC vehicles and iconic GTA V vehicles directly into the game.
final class ModManagerViewController: UITableViewController, UIDocumentPickerDelegate {
    private let engineRunning: Bool
    private let fileManager = FileManager.default
    private var installedMods: [ModInstaller.Installed] = []
    private var modFiles: [ModFile] = []
    private var dlcCatalog: ModRuntime.Catalog = ModRuntime.Catalog()
    private var modVehicles: [String] = []

    /// Set by the game screen: spawns through it (with progress and failure messages on the game view).
    var spawnHandler: ((String) -> Void)?

    typealias ModFile = ModFiles.Entry

    private enum ImportMode {
        case generalMod
        case soundMod
        case skinMod(alias: String?)
    }
    private var currentImportMode: ImportMode = .generalMod

    private let defaultVehicles: [(name: String, model: String, icon: String)] = [
        ("Karin Sultan (4 cửa)", "sultan", "car.fill"),
        ("Trực thăng Buzzard Attack", "buzzard", "airplane"),
        ("Mô tô bay Oppressor Mk II", "oppressor2", "bolt.car.fill"),
        ("Siêu xe Truffade Adder", "adder", "car.side.fill"),
        ("Mô tô Pegassi Bati 801", "bati", "bicycle")
    ]

    /// The dedicated mods directory: Files › On My iPhone › Mugoat › Mods
    static var modsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let target = docs.appendingPathComponent("Mods")
        let fm = FileManager.default
        if !fm.fileExists(atPath: target.path) {
            try? fm.createDirectory(at: target, withIntermediateDirectories: true)
        }
        migrateLegacyModsFolderIfNeeded(docs: docs, target: target)
        return target
    }

    /// One-time automatic migration from old lowercase `mods` to `Mods`
    private static func migrateLegacyModsFolderIfNeeded(docs: URL, target: URL) {
        let fm = FileManager.default
        let legacy = docs.appendingPathComponent("mods")
        guard legacy.path != target.path else { return }
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: legacy.path, isDirectory: &isDir), isDir.boolValue else { return }

        // Check if both paths point to the same directory on a case-insensitive filesystem
        if let legacyID = try? legacy.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier,
           let targetID = try? target.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier,
           legacyID.isEqual(targetID) {
            return
        }

        guard let items = try? fm.contentsOfDirectory(at: legacy, includingPropertiesForKeys: nil) else { return }
        for item in items {
            let dest = target.appendingPathComponent(item.lastPathComponent)
            if !fm.fileExists(atPath: dest.path) {
                try? fm.moveItem(at: item, to: dest)
            }
        }
        let remaining = (try? fm.contentsOfDirectory(atPath: legacy.path)) ?? []
        if remaining.isEmpty {
            try? fm.removeItem(at: legacy)
        }
    }

    init(engineRunning: Bool) {
        self.engineRunning = engineRunning
        super.init(style: .insetGrouped)
        title = L10n.text("Quản lý Mod")
        overrideUserInterfaceStyle = .dark
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
        tableView.backgroundView = Theme.dimmedBackdrop(image: "SettingsBackground")
        refreshControl = UIRefreshControl()
        refreshControl?.addAction(UIAction { [weak self] _ in self?.scanMods() }, for: .valueChanged)
        _ = Self.modsDirectory
        scanMods()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        scanMods()
    }

    private func scanMods() {
        installedMods = ModInstaller.installed()
        modFiles = ModFiles.scan(Self.modsDirectory)
        dlcCatalog = ModRuntime.catalog(Self.modsDirectory)
        modVehicles = ModVehicleSupport.vehicles()
        tableView.reloadData()
        refreshControl?.endRefreshing()
    }

    private var allVehicleModels: [String] {
        var set = Set<String>()
        set.formUnion(modVehicles)
        set.formUnion(dlcCatalog.vehicleModels)
        return set.sorted()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int { 3 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 7 // Cài đặt & Thêm Mod
        case 1: return max(1, installedMods.count) // Danh sách mod đã cài
        case 2: return 1 + allVehicleModels.count + defaultVehicles.count // Gọi xe
        default: return 0
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return L10n.text("Cài đặt & Thêm Mod")
        case 1: return L10n.text("Danh sách Mod đã cài") + " · \(installedMods.count)"
        case 2: return L10n.text("Gọi phương tiện & Xe Mod (DLC Spawner)")
        default: return nil
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0:
            return L10n.text("Mod tải về (.zip, .rar, .oiv, .asi, xe, skin, audio) được hệ thống R007 tự động phân loại và nạp trực tiếp ở cấp C/Metal. Bấm vào từng mục để nhập từ Tệp.")
        case 1:
            return L10n.text("Các thay đổi bật/tắt hoặc xóa mod sẽ áp dụng vào lần khởi động game tiếp theo. Mod bị tắt có hậu tố .off.")
        case 2:
            return L10n.text("Bấm vào phương tiện để triệu hồi ngay trước mặt nhân vật. Có thể nhập tên model bất kỳ từ bản mod hoặc GTA V gốc.")
        default: return nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.backgroundColor = Theme.rowBackground
        cell.textLabel?.textColor = Theme.text
        cell.detailTextLabel?.textColor = Theme.secondaryText
        cell.detailTextLabel?.numberOfLines = 2

        switch indexPath.section {
        case 0:
            let titles = [
                L10n.text("Nhập Mod từ tệp (.zip, .rar, .oiv, .asi)"),
                L10n.text("Nhập âm thanh xe (DLC Sound)"),
                L10n.text("Chọn tiếng cho xe mod"),
                L10n.text("Nhập skin addon (Menyoo)"),
                L10n.text("Plugin Menyoo tích hợp"),
                L10n.text("Vị trí thư mục Mod"),
                L10n.text("Làm mới danh sách Mod")
            ]
            let subs = [
                L10n.text("Tự động giải nén, sắp xếp OpenIV/Script/Addon vào thư mục Mods"),
                L10n.text("Chuyển đổi âm thanh động cơ REL54 cho xe mod"),
                L10n.text("Gán âm thanh động cơ tuỳ chỉnh cho từng dòng xe mod"),
                L10n.text("Thêm ped skin (bộ 4 tệp YDD, YFT, YMT, YTD) vào game"),
                L10n.text("Menu Trainer F8: đổi nhân vật, skin addon, spawn xe và tùy biến"),
                "Files › On My iPhone › Mugoat › Mods",
                L10n.text("Quét lại thư mục sau khi chép file qua máy tính hoặc app Tệp")
            ]
            let icons = [
                "square.and.arrow.down.fill",
                "waveform",
                "speaker.wave.2.fill",
                "person.crop.rectangle.fill",
                "puzzlepiece.extension.fill",
                "folder.fill.badge.gearshape",
                "arrow.clockwise"
            ]
            cell.textLabel?.text = titles[indexPath.row]
            cell.detailTextLabel?.text = subs[indexPath.row]
            cell.imageView?.image = UIImage(systemName: icons[indexPath.row])
            cell.imageView?.tintColor = Theme.accent
            cell.accessoryType = (indexPath.row <= 4) ? .disclosureIndicator : .none

        case 1:
            if installedMods.isEmpty {
                cell.textLabel?.text = L10n.text("Chưa có Mod nào được cài")
                cell.detailTextLabel?.text = L10n.text("Bấm 'Nhập Mod từ tệp' ở trên hoặc chép mod vào thư mục Mugoat/Mods.")
                cell.imageView?.image = UIImage(systemName: "tray")
                cell.imageView?.tintColor = Theme.secondaryText
                cell.selectionStyle = .none
            } else {
                let mod = installedMods[indexPath.row]
                cell.textLabel?.text = mod.name
                var descParts: [String] = []
                descParts.append(String(format: L10n.text("%d tệp"), mod.files))
                descParts.append(mod.enabled ? L10n.text("Đang bật") : L10n.text("Đã tắt"))
                if mod.waiting > 0 {
                    descParts.append(String(format: L10n.text("%d tệp chờ nạp"), mod.waiting))
                }
                if let change = ModInstaller.pending[mod.name] {
                    let changeDesc = change == "remove" ? L10n.text("sẽ xóa khi mở lại")
                        : change == "on" ? L10n.text("sẽ bật khi mở lại")
                        : L10n.text("sẽ tắt khi mở lại")
                    descParts.append(changeDesc)
                }
                cell.detailTextLabel?.text = descParts.joined(separator: " · ")
                cell.imageView?.image = UIImage(systemName: mod.enabled ? "checkmark.circle.fill" : "xmark.circle")
                cell.imageView?.tintColor = mod.enabled ? Theme.accent : .systemGray

                let toggle = UISwitch()
                let change = ModInstaller.pending[mod.name]
                toggle.isOn = change.map { $0 == "on" } ?? mod.enabled
                toggle.isEnabled = change != "remove"
                toggle.addAction(UIAction { [weak self] action in
                    guard let self, let toggle = action.sender as? UISwitch else { return }
                    do {
                        try ModInstaller.setEnabled(mod, toggle.isOn)
                        if mod.name == BundledMenyoo.name {
                            UserDefaults.standard.set(toggle.isOn, forKey: "NewGenMenyooEnabled")
                        }
                        self.scanMods()
                    } catch {
                        toggle.isOn = !toggle.isOn
                        self.showAlert(L10n.text("Lỗi"), error.localizedDescription)
                    }
                }, for: .valueChanged)
                cell.accessoryView = toggle
            }

        case 2:
            if indexPath.row == 0 {
                cell.textLabel?.text = L10n.text("Gọi xe theo tên Model (Custom Spawn…)")
                cell.detailTextLabel?.text = L10n.text("Nhập tên model bất kỳ (ví dụ: mbslk, sultan, buzzard…)")
                cell.imageView?.image = UIImage(systemName: "magnifyingglass.circle.fill")
                cell.imageView?.tintColor = Theme.accent
                cell.accessoryType = .disclosureIndicator
            } else if indexPath.row <= allVehicleModels.count {
                let model = allVehicleModels[indexPath.row - 1]
                cell.textLabel?.text = "Xe Mod: \(model.uppercased())"
                cell.detailTextLabel?.text = L10n.text("Phương tiện từ gói DLC Add-on đã cài. Bấm để triệu hồi ngay.")
                cell.imageView?.image = UIImage(systemName: "star.fill")
                cell.imageView?.tintColor = .systemYellow
                cell.accessoryType = .disclosureIndicator
            } else {
                let index = indexPath.row - 1 - allVehicleModels.count
                if index < defaultVehicles.count {
                    let v = defaultVehicles[index]
                    cell.textLabel?.text = v.name
                    cell.detailTextLabel?.text = "Model: \(v.model) · " + L10n.text("Bấm để triệu hồi")
                    cell.imageView?.image = UIImage(systemName: v.icon)
                    cell.imageView?.tintColor = Theme.accent
                    cell.accessoryType = .disclosureIndicator
                }
            }

        default: break
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch indexPath.section {
        case 0:
            switch indexPath.row {
            case 0: pickModFile()
            case 1: pickSoundFile()
            case 2: chooseSound()
            case 3: promptSkinImport()
            case 4: openMenyooSettings()
            case 5: showFolderInfo()
            case 6: scanMods()
            default: break
            }

        case 1:
            guard !installedMods.isEmpty, indexPath.row < installedMods.count else { return }
            toggleOrManageMod(at: indexPath.row)

        case 2:
            if indexPath.row == 0 {
                promptCustomVehicleSpawn()
            } else if indexPath.row <= allVehicleModels.count {
                let model = allVehicleModels[indexPath.row - 1]
                spawnVehicle(named: model)
            } else {
                let index = indexPath.row - 1 - allVehicleModels.count
                if index < defaultVehicles.count {
                    spawnVehicle(named: defaultVehicles[index].model)
                }
            }

        default: break
        }
    }

    // MARK: - Mod Import Handlers

    private func pickModFile() {
        currentImportMode = .generalMod
        let types = [
            UTType.zip,
            UTType.data,
            UTType.folder,
            UTType(filenameExtension: "rar"),
            UTType(filenameExtension: "oiv"),
            UTType(filenameExtension: "asi"),
            UTType(filenameExtension: "rpf")
        ].compactMap { $0 }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = true
        present(picker, animated: true)
    }

    private func pickSoundFile() {
        guard !ModInstaller.gameRunning else {
            showAlert(L10n.text("Game đang chạy"), L10n.text("Hãy thoát hẳn game và mở Quản lý Mod từ màn hình chính để nhập âm thanh, tránh xung đột bank âm thanh."))
            return
        }
        currentImportMode = .soundMod
        let types = [
            UTType.zip,
            UTType.data,
            UTType(filenameExtension: "rar"),
            UTType(filenameExtension: "oiv"),
            UTType(filenameExtension: "rel")
        ].compactMap { $0 }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = true
        present(picker, animated: true)
    }

    private func promptSkinImport() {
        let alert = UIAlertController(
            title: L10n.text("Nhập Skin Addon"),
            message: L10n.text("Nhập tên model skin (ví dụ: 2b, tifa) hoặc để trống để giữ tên gốc từ mod. Skin cần đủ 4 tệp YDD, YFT, YMT, YTD:"),
            preferredStyle: .alert
        )
        alert.addTextField { tf in
            tf.placeholder = "Tên model (tùy chọn, ví dụ: 2b)"
            tf.autocapitalizationType = .none
            tf.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: L10n.text("Chọn tệp Skin…"), style: .default) { [weak self, weak alert] _ in
            let alias = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
            self?.currentImportMode = .skinMod(alias: (alias?.isEmpty == false) ? alias : nil)
            let types = [
                UTType.zip,
                UTType.data,
                UTType.folder,
                UTType(filenameExtension: "rar"),
                UTType(filenameExtension: "ydd"),
                UTType(filenameExtension: "yft"),
                UTType(filenameExtension: "ymt"),
                UTType(filenameExtension: "ytd")
            ].compactMap { $0 }
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
            picker.delegate = self
            picker.allowsMultipleSelection = true
            self?.present(picker, animated: true)
        })
        alert.addAction(UIAlertAction(title: L10n.text("Hủy"), style: .cancel))
        present(alert, animated: true)
    }

    private func openMenyooSettings() {
        let menyooVC = BundledMenyooViewController()
        if let nav = navigationController {
            nav.pushViewController(menyooVC, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: menyooVC)
            Theme.styleNavigation(nav)
            menyooVC.navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak nav] _ in
                nav?.dismiss(animated: true)
            })
            present(nav, animated: true)
        }
    }

    // MARK: - UIDocumentPickerDelegate

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard !urls.isEmpty else { return }

        switch currentImportMode {
        case .generalMod:
            for url in urls {
                do {
                    let stage = try ModInstaller.unpack(url)
                    if SoundInstaller.isSoundOnly(stage) {
                        let (plan, _) = try SoundInstaller.build(stage)
                        confirmModPlan(plan, folder: stage)
                    } else {
                        let plan = ModInstaller.plan(folder: stage, name: url.lastPathComponent, index: .load(manifest: EnginePaths.manifest))
                        confirmModPlan(plan, folder: stage)
                    }
                } catch {
                    showAlert(L10n.text("Không thể đọc Mod"), error.localizedDescription)
                }
            }

        case .soundMod:
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let result = Result { () -> (ModInstaller.Plan, URL) in
                    let stage = try SoundInstaller.stage(urls)
                    do {
                        let (plan, _) = try SoundInstaller.build(stage)
                        return (plan, stage)
                    } catch {
                        try? FileManager.default.removeItem(at: stage)
                        throw error
                    }
                }
                DispatchQueue.main.async {
                    switch result {
                    case let .success((plan, stage)):
                        self?.confirmModPlan(plan, folder: stage)
                    case let .failure(error):
                        self?.showAlert(L10n.text("Lỗi nhập âm thanh"), error.localizedDescription)
                    }
                }
            }

        case .skinMod(let alias):
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let fm = FileManager.default
                let stage = fm.temporaryDirectory.appendingPathComponent("skin-stage-\(UUID().uuidString)")
                let result = Result { () -> (ModInstaller.Plan, URL) in
                    try fm.createDirectory(at: stage, withIntermediateDirectories: true)
                    for (i, url) in urls.enumerated() {
                        let ext = url.pathExtension.lowercased()
                        if ["zip", "rar", "oiv"].contains(ext) {
                            let unpacked = try ModInstaller.unpack(url)
                            defer { try? fm.removeItem(at: unpacked) }
                            let items = (try? fm.contentsOfDirectory(at: unpacked, includingPropertiesForKeys: nil)) ?? []
                            for item in items {
                                try? fm.copyItem(at: item, to: stage.appendingPathComponent(item.lastPathComponent))
                            }
                        } else {
                            try? fm.copyItem(at: url, to: stage.appendingPathComponent(url.lastPathComponent))
                        }
                    }
                    let planName = alias ?? urls.first?.deletingPathExtension().lastPathComponent ?? "skin"
                    let plan = try SkinInstaller.plan(folder: stage, name: planName, female: true, modelName: alias)
                    return (plan, stage)
                }
                DispatchQueue.main.async {
                    switch result {
                    case let .success((plan, stage)):
                        self?.confirmModPlan(plan, folder: stage)
                    case let .failure(error):
                        try? fm.removeItem(at: stage)
                        self?.showAlert(L10n.text("Lỗi nhập skin"), error.localizedDescription)
                    }
                }
            }
        }
    }

    private func confirmModPlan(_ plan: ModInstaller.Plan, folder: URL) {
        if plan.items.isEmpty {
            let title = plan.unsupported ? L10n.text("Mod không tương thích với iOS") : L10n.text("Không có tệp để cài đặt")
            let lines = plan.skipped.map { "✕ \($0.file) (\($0.reason))" }
            let help = plan.unsupported
                ? L10n.text("Mod này yêu cầu Windows .NET (ScriptHookVDotNet) hoặc dành cho phiên bản GTA V Enhanced (PC mới).")
                : L10n.text("Hệ thống không tìm thấy đường dẫn phù hợp trong GTA V cho các tệp này.")
            let alert = UIAlertController(title: title, message: lines.joined(separator: "\n") + "\n\n" + help, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L10n.text("Đã hiểu"), style: .cancel) { _ in
                try? FileManager.default.removeItem(at: folder)
            })
            present(alert, animated: true)
            return
        }

        let lines: [String] = plan.items.map { item in
            let noteStr = item.note.isEmpty ? "" : " (\(item.note))"
            return "• \(item.target)\(noteStr)"
        } +
        plan.skipped.map { "✕ \($0.file) (\($0.reason))" }
        let title = String(format: L10n.text("Cài đặt \"%@\"?"), plan.name)
        let message = lines.prefix(15).joined(separator: "\n") + (lines.count > 15 ? "\n...và \(lines.count - 15) mục khác" : "")

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.text("Hủy"), style: .cancel) { _ in
            try? FileManager.default.removeItem(at: folder)
        })
        alert.addAction(UIAlertAction(title: L10n.text("Cài đặt"), style: .default) { [weak self] _ in
            do {
                _ = try ModInstaller.install(plan)
                try? SkinInstaller.updateMenyooList()
                self?.scanMods()
                self?.showAlert(L10n.text("Thành công"), String(format: L10n.text("Đã cài đặt thành công mod \"%@\"."), plan.name))
            } catch {
                self?.showAlert(L10n.text("Lỗi cài đặt"), error.localizedDescription)
            }
            try? FileManager.default.removeItem(at: folder)
        })
        present(alert, animated: true)
    }

    private func chooseSound() {
        let profiles = SoundInstaller.available()
        guard !profiles.isEmpty else {
            showAlert(L10n.text("Chưa có gói âm thanh"), L10n.text("Vui lòng nhập gói âm thanh trước qua mục 'Nhập âm thanh xe'. Sau đó khởi động lại game để game nạp bank."))
            return
        }
        let cars = ModVehicleSupport.vehicles()
        guard !cars.isEmpty else {
            showAlert(L10n.text("Chưa có xe mod"), L10n.text("Chưa tìm thấy xe mod nào trong thư mục Mods. Hãy nhập xe mod trước và khởi động game một lần."))
            return
        }
        let ask = UIAlertController(title: L10n.text("Chọn xe đã mod"), message: L10n.text("Chọn dòng xe để gán âm thanh động cơ tuỳ chỉnh:"), preferredStyle: .actionSheet)
        for name in cars {
            ask.addAction(UIAlertAction(title: name.uppercased(), style: .default) { [weak self] _ in
                let model = ModAudio.hash(name)
                let menu = UIAlertController(title: "Âm thanh: \(name.uppercased())", message: L10n.text("Chọn cấu hình âm thanh cho xe:"), preferredStyle: .actionSheet)
                for profile in profiles {
                    menu.addAction(UIAlertAction(title: profile, style: .default) { _ in
                        SoundAssignments.set(model, profile)
                        self?.showAlert(L10n.text("Đã gán âm thanh"), String(format: L10n.text("Xe %@ đã được gán âm thanh '%@'. Hãy khởi động lại game để áp dụng."), name.uppercased(), profile))
                    })
                }
                menu.addAction(UIAlertAction(title: L10n.text("Bỏ gán (dùng âm thanh mặc định)"), style: .destructive) { _ in
                    SoundAssignments.set(model, "")
                    self?.showAlert(L10n.text("Đã bỏ gán"), String(format: L10n.text("Xe %@ sẽ dùng âm thanh mặc định."), name.uppercased()))
                })
                menu.addAction(UIAlertAction(title: L10n.text("Hủy"), style: .cancel))
                self?.present(menu, animated: true)
            })
        }
        ask.addAction(UIAlertAction(title: L10n.text("Hủy"), style: .cancel))
        present(ask, animated: true)
    }

    private func toggleOrManageMod(at index: Int) {
        guard index < installedMods.count else { return }
        let mod = installedMods[index]
        let sheet = UIAlertController(title: mod.name, message: L10n.text("Chọn thao tác cho bản mod này:"), preferredStyle: .actionSheet)
        let toggleTitle = mod.enabled ? L10n.text("Tắt Mod này (.off)") : L10n.text("Bật lại Mod này")
        sheet.addAction(UIAlertAction(title: toggleTitle, style: .default) { [weak self] _ in
            guard let self else { return }
            do {
                try ModInstaller.setEnabled(mod, !mod.enabled)
                if mod.name == BundledMenyoo.name {
                    UserDefaults.standard.set(!mod.enabled, forKey: "NewGenMenyooEnabled")
                }
                self.scanMods()
            } catch {
                self.showAlert(L10n.text("Lỗi"), error.localizedDescription)
            }
        })
        sheet.addAction(UIAlertAction(title: L10n.text("Xóa Mod vĩnh viễn"), style: .destructive) { [weak self] _ in
            guard let self else { return }
            let confirm = UIAlertController(
                title: L10n.text("Xác nhận xóa"),
                message: String(format: L10n.text("Bạn có chắc chắn muốn xóa vĩnh viễn mod \"%@\" khỏi máy?"), mod.name),
                preferredStyle: .alert
            )
            confirm.addAction(UIAlertAction(title: L10n.text("Hủy"), style: .cancel))
            confirm.addAction(UIAlertAction(title: L10n.text("Xóa"), style: .destructive) { [weak self] _ in
                do {
                    try ModInstaller.remove(mod)
                    try? SkinInstaller.updateMenyooList()
                    self?.scanMods()
                } catch {
                    self?.showAlert(L10n.text("Lỗi xóa mod"), error.localizedDescription)
                }
            })
            self.present(confirm, animated: true)
        })
        sheet.addAction(UIAlertAction(title: L10n.text("Đóng"), style: .cancel))
        if let cell = tableView.cellForRow(at: IndexPath(row: index, section: 1)) {
            sheet.popoverPresentationController?.sourceView = cell
        }
        present(sheet, animated: true)
    }

    private func showFolderInfo() {
        let path = Self.modsDirectory.path
        let alert = UIAlertController(
            title: L10n.text("Thư mục Mod Mugoat"),
            message: "\(L10n.text("Đường dẫn trên iPhone:"))\n\(path)\n\n\(L10n.text("Mở app 'Tệp' › 'Trên iPhone' › 'Mugoat' › 'Mods' để quản lý hoặc chép đè tệp mod."))",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.text("Sao chép đường dẫn"), style: .default) { _ in
            UIPasteboard.general.string = path
        })
        alert.addAction(UIAlertAction(title: L10n.text("Đã hiểu"), style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Vehicle Spawner

    private func spawnVehicle(named model: String) {
        guard engineRunning else {
            showAlert(L10n.text("Chưa vào game"), L10n.text("Vui lòng khởi động và vào game trước khi gọi phương tiện."))
            return
        }
        guard !MugoatOnlineEnabled() else {
            showAlert(L10n.text("Không khả dụng"), L10n.text("Không thể triệu hồi xe trong Online."))
            return
        }
        if let spawnHandler {
            let name = model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !name.isEmpty else { return }
            dismiss(animated: true) { spawnHandler(name) }
            return
        }
        var cleanModel = model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if cleanModel == "mbs1k" { cleanModel = "mbslk" }
        guard !cleanModel.isEmpty else { return }
        let started = cleanModel.withCString { MugoatSpawnVehicleNamed($0) }
        if started {
            showAlert(L10n.text("Đã gọi xe"), String(format: L10n.text("Đang nạp model '%@'. Xe sẽ xuất hiện ngay trước mặt nhân vật!"), cleanModel))
        } else {
            showAlert(L10n.text("Hệ thống bận"), L10n.text("Đang trong quá trình triệu hồi phương tiện khác. Vui lòng thử lại sau giây lát."))
        }
    }

    private func promptCustomVehicleSpawn() {
        let alert = UIAlertController(
            title: L10n.text("Gọi xe theo tên Model"),
            message: L10n.text("Nhập tên model xe từ bản mod (ví dụ: mbslk) hoặc GTA V gốc (ví dụ: sultan, adder, buzzard):"),
            preferredStyle: .alert
        )
        alert.addTextField { tf in
            tf.placeholder = "mbslk, sultan, buzzard..."
            tf.autocapitalizationType = .none
            tf.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: L10n.text("Gọi xe ngay"), style: .default) { [weak self, weak alert] _ in
            guard let text = alert?.textFields?.first?.text else { return }
            self?.spawnVehicle(named: text)
        })
        alert.addAction(UIAlertAction(title: L10n.text("Hủy"), style: .cancel))
        present(alert, animated: true)
    }

    private func showAlert(_ title: String, _ message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.text("Đã hiểu"), style: .default))
        present(alert, animated: true)
    }
}
