import UIKit

enum GameSettings { static let sandboxMapTitles = ["Los Santos"] }

@main
final class PreviewApp: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let controller = PreviewController()
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
final class PreviewController: UIViewController {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var prefersStatusBarHidden: Bool { true }
    override func viewDidLoad() {
        super.viewDidLoad()
        if let i = ProcessInfo.processInfo.arguments.firstIndex(of: "--language"), i + 1 < ProcessInfo.processInfo.arguments.count { L10n.language = ProcessInfo.processInfo.arguments[i + 1] }
        let log = UITextView(); log.isHidden = true
        let home = HomeView(modes: [("Cốt truyện", "book.closed.fill"), ("Tự do", "map.fill")], log: log)
        home.frame = view.bounds; home.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        home.setFiles(.ready, title: L10n.text("Dữ liệu đã sẵn sàng"), detail: L10n.text("GTA V · Đã kiểm tra các tệp cần thiết"))
        home.setMode(1, detail: L10n.text("Khám phá Los Santos theo cách của bạn."), enabled: true)
        home.setMap(0, visible: true, enabled: true)
        home.controllerLabel.text = "Điều khiển: cảm ứng"
        home.languageButton.configuration?.title = L10n.language.uppercased()
        home.languageButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            LocalizedUI.chooseLanguage(from: self) {
                LocalizedUI.apply(to: home)
                home.languageButton.configuration?.title = L10n.language.uppercased()
            }
        }, for: .touchUpInside)
        home.onFiles = { [weak self] in self?.message("Dữ liệu game") }
        home.onMode = { index in home.setMode(index, detail: "Chọn chế độ trước khi vào game.", enabled: true); home.setMap(0, visible: index == 1, enabled: true) }
        for button in [home.settingsButton, home.layoutButton, home.saveButton, home.cheatButton, home.playButton] {
            button.addAction(UIAction { [weak self] _ in self?.message(button.currentTitle ?? "Mugoat") }, for: .touchUpInside)
        }
        view.addSubview(home)
    }
    private func message(_ title: String) {
        let alert = UIAlertController(title: title, message: "Bản kiểm tra giao diện; không chạy engine game.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Đóng", style: .cancel))
        present(alert, animated: true)
    }
}
