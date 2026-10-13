import UIKit

enum OnlineSettings {
    static var enabled: Bool {
        get { UserDefaults.standard.bool(forKey: "MugoatOnlineEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "MugoatOnlineEnabled") }
    }
    static var server: String {
        get { UserDefaults.standard.string(forKey: "MugoatOnlineServer") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "MugoatOnlineServer") }
    }
    static var name: String {
        get { UserDefaults.standard.string(forKey: "MugoatOnlineName") ?? "Player" }
        set { UserDefaults.standard.set(newValue, forKey: "MugoatOnlineName") }
    }
    static var room: String {
        get { UserDefaults.standard.string(forKey: "MugoatOnlineRoom") ?? "default" }
        set { UserDefaults.standard.set(newValue, forKey: "MugoatOnlineRoom") }
    }
    static func configure(mode: GameMode) -> Bool {
        (enabled ? server : "").withCString { server in
            name.withCString { name in room.withCString { room in
                MugoatOnlineConfigure(server, name, room, Int32(mode.rawValue))
            } }
        }
    }
    static var status: String {
        var bytes = [CChar](repeating: 0, count: 512)
        bytes.withUnsafeMutableBufferPointer { _ = MugoatOnlineStatus($0.baseAddress, $0.count) }
        return L10n.text(String(cString: bytes))
    }
}

final class OnlineSettingsViewController: UIViewController {
    private let running: Bool
    private let enabled = UISwitch()
    private let server = UITextField()
    private let name = UITextField()
    private let room = UITextField()
    var changed: (() -> Void)?
    init(running: Bool) { self.running = running; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.text("Máy chủ online")
        view.backgroundColor = UIColor(white: 0.06, alpha: 1)
        enabled.isOn = OnlineSettings.enabled; enabled.isEnabled = !running
        let label = UILabel(); label.text = L10n.text("Chơi online"); label.textColor = Theme.text
        let toggle = UIStackView(arrangedSubviews: [label, enabled]); toggle.alignment = .center
        server.text = OnlineSettings.server; server.placeholder = "IP / hostname:47520"; server.keyboardType = .URL
        name.text = OnlineSettings.name; name.placeholder = L10n.text("Tên người chơi")
        room.text = OnlineSettings.room; room.placeholder = L10n.text("Phòng chơi")
        for field in [server, name, room] {
            field.borderStyle = .roundedRect; field.autocapitalizationType = .none
            field.autocorrectionType = .no; field.isEnabled = !running
            field.heightAnchor.constraint(equalToConstant: 44).isActive = true
        }
        let explanation = UILabel()
        explanation.text = L10n.text(running ? "Đóng rồi mở lại app để đổi máy chủ." : "Dùng cùng IP, phòng và chế độ chơi với bạn bè. Máy chủ Muguet dùng UDP 47520. Kết nối bắt đầu khi vào game.")
        explanation.font = Theme.body(13); explanation.textColor = Theme.secondaryText; explanation.numberOfLines = 0
        let status = UILabel(); status.text = running ? OnlineSettings.status : ""; status.textColor = Theme.accent; status.numberOfLines = 0
        let save = Theme.primaryButton(L10n.text("Lưu"), symbol: "checkmark")
        save.isEnabled = !running
        save.addAction(UIAction { [weak self] _ in self?.save() }, for: .touchUpInside)
        let column = UIStackView(arrangedSubviews: [toggle, server, name, room, explanation, status, save]); column.axis = .vertical; column.spacing = 16
        column.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(column)
        NSLayoutConstraint.activate([column.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20), column.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24), column.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24)])
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: L10n.text("Đóng"), style: .done, target: self, action: #selector(close))
    }
    @objc private func close() { dismiss(animated: true) }
    private func save() {
        let host = (server.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let player = (name.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let channel = (room.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !enabled.isOn || (!host.isEmpty && host.utf8.count <= 253 && !host.contains("/") && !host.contains(where: { $0.isWhitespace }) && player.utf8.count <= 48 && channel.utf8.count <= 64) else {
            let alert = UIAlertController(title: L10n.text("Máy chủ không hợp lệ"), message: L10n.text("Nhập IP hoặc hostname, ví dụ 192.168.1.10:47520."), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default)); present(alert, animated: true); return
        }
        OnlineSettings.server = host; OnlineSettings.name = player; OnlineSettings.room = channel; OnlineSettings.enabled = enabled.isOn
        changed?(); dismiss(animated: true)
    }
}
