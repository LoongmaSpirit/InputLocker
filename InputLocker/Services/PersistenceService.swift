import Foundation

// 持久化服务类，负责管理应用设置的存储和读取
// 使用 UserDefaults 保存用户配置
class PersistenceService: ObservableObject {
    // 单例模式，全局唯一实例
    static let shared = PersistenceService()
    
    // UserDefaults 实例，用于存储设置
    private let defaults = UserDefaults.standard
    
    // UserDefaults 键名定义
    private enum Keys {
        static let isLockEnabled = "isLockEnabled"              // 是否启用输入法锁定
        static let selectedInputMethodID = "selectedInputMethodID"  // 选中的输入法 ID
        static let launchAtLogin = "launchAtLogin"              // 是否开机自启动
    }
    
    // 是否启用输入法锁定功能
    // 当值改变时自动保存到 UserDefaults
    @Published var isLockEnabled: Bool {
        didSet {
            defaults.set(isLockEnabled, forKey: Keys.isLockEnabled)
        }
    }
    
    // 选中的输入法 ID
    // 当值改变时自动保存到 UserDefaults
    @Published var selectedInputMethodID: String? {
        didSet {
            defaults.set(selectedInputMethodID, forKey: Keys.selectedInputMethodID)
        }
    }
    
    // 是否开机自启动
    // 当值改变时自动保存到 UserDefaults
    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
        }
    }
    
    // 私有初始化方法，从 UserDefaults 读取保存的设置
    private init() {
        self.isLockEnabled = defaults.bool(forKey: Keys.isLockEnabled)
        self.selectedInputMethodID = defaults.string(forKey: Keys.selectedInputMethodID)
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
    }
    
    // 清除所有设置
    func clearSettings() {
        defaults.removeObject(forKey: Keys.isLockEnabled)
        defaults.removeObject(forKey: Keys.selectedInputMethodID)
        defaults.removeObject(forKey: Keys.launchAtLogin)
    }
}
