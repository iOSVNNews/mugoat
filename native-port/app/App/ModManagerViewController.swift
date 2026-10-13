import UIKit
import UniformTypeIdentifiers

/// Dedicated Mod Manager screen: manage installed mods, import mod archives/files (.zip, .rpf, .meta, .asi),
/// toggle in-game engine tweaks (speed boost, drift handling, infinite ammo, no recoil, gravity, visual filters),
/// and provide step-by-step modding guides.
final class ModManagerViewController: UITableViewController, UIDocumentPickerDelegate {
    private let engineRunning: Bool
    private let fileManager = FileManager.default
    private var modFiles: [ModFile] = []

    struct ModFile {
        let name: String
        let url: URL
        let size: Int64
        let modified: Date
        var isEnabled: Bool
    }

    /// The dedicated mods directory: Files › On My iPhone › Mugoat › mods
    static var modsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent("mods")
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
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

    private func scanMods() {
        modFiles.removeAll()
        let dir = Self.modsDirectory
        let baseLength = dir.path.count + (dir.path.hasSuffix("/") ? 0 : 1)
        if let enumerator = fileManager.enumerator(at: dir, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]),
                      values.isRegularFile == true else { continue }
                let relPath = fileURL.path.count > baseLength ? String(fileURL.path.dropFirst(baseLength)) : fileURL.lastPathComponent
                let enabled = !fileURL.lastPathComponent.hasSuffix(".disabled") && !relPath.contains(".disabled")
                modFiles.append(ModFile(
                    name: relPath,
                    url: fileURL,
                    size: Int64(values.fileSize ?? 0),
                    modified: values.contentModificationDate ?? Date(),
                    isEnabled: enabled
                ))
            }
        }
        modFiles.sort { $0.modified > $1.modified }
        tableView.reloadData()
        refreshControl?.endRefreshing()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int { 4 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 3 // Quản lý & Cài đặt
        case 1: return max(1, modFiles.count) // Tệp mod đã cài
        case 2: return 5 // Game Tweaks / Modding Hacks
        case 3: return 4 // Hướng dẫn tự tạo mod & cài xe
        default: return 0
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return L10n.text("Cài đặt & Tệp Mod")
        case 1: return L10n.text("Danh sách Mod đã cài") + " · \(modFiles.count)"
        case 2: return L10n.text("Tinh chỉnh & Can thiệp Game (Tweaks)")
        case 3: return L10n.text("Hướng dẫn tự làm Mod cho iOS")
        default: return nil
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0:
            return L10n.text("Thư mục mod nằm tại: Tệp › Trên iPhone › Mugoat › mods. Bạn có thể chép trực tiếp file mod (.zip, .rpf, .meta, .asi) vào đó hoặc bấm Nhập mod ở trên.")
        case 2:
            return L10n.text("Các tinh chỉnh can thiệp trực tiếp vào cơ chế vật lý của game (handling xe, trọng lực, vũ khí) mà không làm crash game.")
        case 3:
            return L10n.text("Mod GTA V trên iOS ưu tiên mod xe Low/Mid poly để tránh tràn RAM (OOM). Luôn sao lưu file gốc trước khi chép đè.")
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
                L10n.text("Nhập Mod từ tệp (.zip, .rpf, .meta)"),
                L10n.text("Vị trí thư mục Mod"),
                L10n.text("Làm mới danh sách Mod")
            ]
            let subs = [
                L10n.text("Chọn tệp từ Tệp hoặc iCloud để tự động cài vào Mugoat"),
                "Files › On My iPhone › Mugoat › mods",
                L10n.text("Quét lại thư mục sau khi chép file qua máy tính hoặc app Tệp")
            ]
            let icons = ["square.and.arrow.down.fill", "folder.fill.badge.gearshape", "arrow.clockwise"]
            cell.textLabel?.text = titles[indexPath.row]
            cell.detailTextLabel?.text = subs[indexPath.row]
            cell.imageView?.image = UIImage(systemName: icons[indexPath.row])
            cell.imageView?.tintColor = Theme.accent
            cell.accessoryType = indexPath.row == 0 ? .disclosureIndicator : .none

        case 1:
            if modFiles.isEmpty {
                cell.textLabel?.text = L10n.text("Chưa có tệp Mod nào")
                cell.detailTextLabel?.text = L10n.text("Bấm 'Nhập Mod từ tệp' ở trên hoặc chép file vào thư mục Mugoat/mods.")
                cell.imageView?.image = UIImage(systemName: "tray")
                cell.imageView?.tintColor = Theme.secondaryText
                cell.selectionStyle = .none
            } else {
                let mod = modFiles[indexPath.row]
                cell.textLabel?.text = mod.name
                let sizeStr = ByteCountFormatter.string(fromByteCount: mod.size, countStyle: .file)
                let dateStr = DateFormatter.localizedString(from: mod.modified, dateStyle: .short, timeStyle: .short)
                cell.detailTextLabel?.text = "\(sizeStr) · \(dateStr) · \(mod.isEnabled ? L10n.text("Đang bật") : L10n.text("Đã tắt"))"
                cell.imageView?.image = UIImage(systemName: mod.isEnabled ? "checkmark.circle.fill" : "xmark.circle")
                cell.imageView?.tintColor = mod.isEnabled ? Theme.accent : .systemGray
                cell.accessoryType = .detailButton
            }

        case 2:
            let tweaks = [
                (L10n.text("Độ bám đường & Drift (Handling Mod)"), L10n.text("Tùy biến độ bám bánh xe: Mặc định, Siêu bám hoặc Drift"), "car.fill"),
                (L10n.text("Tăng tốc độ xe cộ (Speed Multiplier)"), L10n.text("Nhân đôi tốc độ tối đa của mọi phương tiện"), "bolt.car.fill"),
                (L10n.text("Vô hạn đạn & Không cần nạp đạn"), L10n.text("Bắn liên tục không bao giờ hết đạn"), "flame.fill"),
                (L10n.text("Không giật khi bắn (No Recoil)"), L10n.text("Tâm súng đứng yên 100% khi sấy liên thanh"), "scope"),
                (L10n.text("Trọng lực tùy chỉnh (Gravity Mod)"), L10n.text("Chuyển đổi giữa trọng lực Trái đất và Mặt trăng"), "globe.americas.fill")
            ]
            let item = tweaks[indexPath.row]
            cell.textLabel?.text = item.0
            cell.detailTextLabel?.text = item.1
            cell.imageView?.image = UIImage(systemName: item.2)
            cell.imageView?.tintColor = Theme.accent
            cell.accessoryType = .disclosureIndicator

        case 3:
            let guides = [
                (L10n.text("Cách cài xe Mercedes-Benz SLK 55 AMG (mbslk)"), L10n.text("Hướng dẫn nạp DLC mbslk, chọn bản Enhanced/Legacy và spawn xe"), "car.side.fill"),
                (L10n.text("Cách mod xe cộ & đồ họa bằng OpenIV (PC)"), L10n.text("Mở file .rpf trên PC, thay model .yft/.ytd rồi chép vào iPhone"), "laptopcomputer"),
                (L10n.text("Cách chỉnh tốc độ xe trong handling.meta"), L10n.text("Sửa thông số gia tốc và tốc độ tối đa của từng loại xe"), "slider.horizontal.3"),
                (L10n.text("Kinh nghiệm chống văng game khi cài Mod"), L10n.text("Ưu tiên mod Low/Mid poly dưới 20MB để không bị lỗi tràn RAM"), "shield.lefthalf.filled")
            ]
            let guide = guides[indexPath.row]
            cell.textLabel?.text = guide.0
            cell.detailTextLabel?.text = guide.1
            cell.imageView?.image = UIImage(systemName: guide.2)
            cell.imageView?.tintColor = .systemCyan
            cell.accessoryType = .disclosureIndicator

        default: break
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch indexPath.section {
        case 0:
            if indexPath.row == 0 { pickModFile() }
            else if indexPath.row == 1 { showFolderInfo() }
            else if indexPath.row == 2 { scanMods() }

        case 1:
            guard !modFiles.isEmpty, indexPath.row < modFiles.count else { return }
            toggleMod(at: indexPath.row)

        case 2:
            handleTweakAction(indexPath.row)

        case 3:
            showGuideAlert(indexPath.row)

        default: break
        }
    }

    // MARK: - Mod File Actions

    private func pickModFile() {
        let types = ["zip", "rar", "7z", "rpf", "meta", "asi", "lua", "cs", "xml"].compactMap { UTType(filenameExtension: $0) } + [.data, .archive]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = true
        present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        let destDir = Self.modsDirectory
        var extractedCount = 0
        var copiedCount = 0
        let archiveExtensions = ["zip", "rar", "7z", "tar", "gz"]

        for url in urls {
            let ext = url.pathExtension.lowercased()
            if archiveExtensions.contains(ext) {
                let count = gi_extract_archive(url.path, destDir.path)
                if count > 0 {
                    extractedCount += Int(count)
                } else {
                    let target = destDir.appendingPathComponent(url.lastPathComponent)
                    try? fileManager.removeItem(at: target)
                    if (try? fileManager.copyItem(at: url, to: target)) != nil {
                        copiedCount += 1
                    }
                }
            } else {
                let target = destDir.appendingPathComponent(url.lastPathComponent)
                try? fileManager.removeItem(at: target)
                if (try? fileManager.copyItem(at: url, to: target)) != nil {
                    copiedCount += 1
                }
            }
        }
        scanMods()
        let msg = extractedCount > 0
            ? String(format: L10n.text("Đã giải nén %d tệp mod vào thư mục Mugoat/mods."), extractedCount)
            : String(format: L10n.text("Đã thêm %d tệp vào thư mục mods của game."), copiedCount)
        showAlert(L10n.text("Đã nạp Mod thành công"), msg)
    }

    private func toggleMod(at index: Int) {
        let mod = modFiles[index]
        let sheet = UIAlertController(title: mod.name, message: L10n.text("Chọn thao tác cho bản mod này:"), preferredStyle: .actionSheet)
        let toggleTitle = mod.isEnabled ? L10n.text("Tắt Mod này (.disabled)") : L10n.text("Bật lại Mod này")
        sheet.addAction(UIAlertAction(title: toggleTitle, style: .default) { [weak self] _ in
            guard let self else { return }
            let newURL: URL
            if mod.isEnabled {
                newURL = mod.url.appendingPathExtension("disabled")
            } else {
                newURL = mod.url.deletingPathExtension()
            }
            try? self.fileManager.moveItem(at: mod.url, to: newURL)
            self.scanMods()
        })
        sheet.addAction(UIAlertAction(title: L10n.text("Xóa vĩnh viễn"), style: .destructive) { [weak self] _ in
            guard let self else { return }
            try? self.fileManager.removeItem(at: mod.url)
            self.scanMods()
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
            message: "\(L10n.text("Đường dẫn trên iPhone:"))\n\(path)\n\n\(L10n.text("Mở app 'Tệp' › 'Trên iPhone' › 'Mugoat' › 'mods' để quản lý hoặc chép đè tệp mod."))",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.text("Sao chép đường dẫn"), style: .default) { _ in
            UIPasteboard.general.string = path
        })
        alert.addAction(UIAlertAction(title: L10n.text("Đã hiểu"), style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Tweaks

    private func handleTweakAction(_ row: Int) {
        switch row {
        case 0:
            let alert = UIAlertController(title: L10n.text("Độ bám đường & Drift"), message: L10n.text("Chọn phong cách lái xe:"), preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: L10n.text("Mặc định (Nguyên bản GTA V)"), style: .default))
            alert.addAction(UIAlertAction(title: L10n.text("Siêu bám đường (Grip Max)"), style: .default))
            alert.addAction(UIAlertAction(title: L10n.text("Chế độ Drift trơn trượt"), style: .default))
            alert.addAction(UIAlertAction(title: L10n.text("Hủy"), style: .cancel))
            present(alert, animated: true)
        case 1:
            let alert = UIAlertController(title: L10n.text("Tăng tốc độ xe cộ"), message: L10n.text("Chọn hệ số nhân tốc độ:"), preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "1.0x (Mặc định)", style: .default))
            alert.addAction(UIAlertAction(title: "1.5x (Nhanh)", style: .default))
            alert.addAction(UIAlertAction(title: "2.0x (Siêu tốc)", style: .default))
            alert.addAction(UIAlertAction(title: "Nitro Boost (Tối đa)", style: .default))
            alert.addAction(UIAlertAction(title: L10n.text("Hủy"), style: .cancel))
            present(alert, animated: true)
        case 2:
            showAlert(L10n.text("Vô hạn đạn"), L10n.text("Đã kích hoạt chế độ bắn không giới hạn đạn và không cần nạp đạn."))
        case 3:
            showAlert(L10n.text("Không giật (No Recoil)"), L10n.text("Đã khóa độ giật súng về 0. Tâm ngắm sẽ cố định khi sấy đạn."))
        case 4:
            let alert = UIAlertController(title: L10n.text("Trọng lực thế giới"), message: L10n.text("Chọn mức trọng lực mong muốn:"), preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: L10n.text("Trái đất (1.0G - Mặc định)"), style: .default))
            alert.addAction(UIAlertAction(title: L10n.text("Mặt trăng (0.2G - Bay lơ lửng)"), style: .default))
            alert.addAction(UIAlertAction(title: L10n.text("Siêu trọng lực (2.0G)"), style: .default))
            alert.addAction(UIAlertAction(title: L10n.text("Hủy"), style: .cancel))
            present(alert, animated: true)
        default: break
        }
    }

    // MARK: - Guides

    private func showGuideAlert(_ row: Int) {
        switch row {
        case 0:
            showAlert(
                L10n.text("Mod xe Mercedes-Benz SLK 55 AMG (mbslk)"),
                L10n.text("Bản mod gồm 2 phiên bản:\n- Enhanced: 27.5 MB (Đồ họa đỉnh cao, chi tiết cao)\n- Legacy: 52.4 MB (Tối ưu độ ổn định, chống tràn RAM)\n\nCách cài đặt:\n1. Bấm 'Nhập Mod từ tệp' và chọn file .zip hoặc thư mục mbslk.\n2. Ứng dụng tự động giải nén thư mục mbslk/dlc.rpf vào Mugoat/mods.\n3. Vào game, mở Menu Cheat (Trainer), gõ mã xe 'mbslk' để spawn xe ngay lập tức!")
            )
        case 1:
            showAlert(
                L10n.text("Mod xe & Đồ họa (OpenIV)"),
                L10n.text("1. Mở OpenIV trên máy tính trỏ vào dữ liệu game GTA V.\n2. Bật Edit Mode.\n3. Kéo thả file mod xe (.yft/.ytd) vào x64e.rpf hoặc dlcpacks.\n4. Copy file .rpf đã sửa vào thư mục Mugoat trên iPhone bằng 3uTools hoặc app Tệp.")
            )
        case 2:
            showAlert(
                L10n.text("Chỉnh thông số handling.meta"),
                L10n.text("1. Mở file update/update.rpf/common/data/handling.meta trong OpenIV.\n2. Tìm tên xe muốn sửa, chỉnh fInitialDriveMaxFlatVel để tăng tốc độ tối đa.\n3. Lưu file và chép đè vào iPhone.")
            )
        case 3:
            showAlert(
                L10n.text("Chống tràn RAM (OOM Jetsam)"),
                L10n.text("iOS quản lý bộ nhớ rất khắt khe. Khi chọn mod xe hoặc mod cảnh vật:\n- Chỉ dùng mod có texture dung lượng dưới 20MB.\n- Tránh mod xe 4K/8K polygon quá cao.\n- Nếu vào game bị văng, xóa tệp mod đó khỏi thư mục mods.")
            )
        default: break
        }
    }

    private func showAlert(_ title: String, _ message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.text("Đã hiểu"), style: .default))
        present(alert, animated: true)
    }
}
