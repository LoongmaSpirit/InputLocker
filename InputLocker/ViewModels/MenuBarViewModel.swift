import Foundation
import Combine
import AppKit

// 菜单栏视图模型类，负责管理应用的业务逻辑和状态
// 协调 InputMethodService、PersistenceService 和 LaunchAtLoginService
class MenuBarViewModel: ObservableObject {
    // 是否启用输入法锁定功能
    @Published var isLockEnabled: Bool = false
    // 系统中所有可用的输入法列表
    @Published var availableInputMethods: [InputMethod] = []
    // 用户选中的目标输入法
    @Published var selectedInputMethod: InputMethod?
    // 是否启用开机自启动
    @Published var launchAtLogin: Bool = false
    
    // 输入法服务实例
    private let inputMethodService = InputMethodService.shared
    // 持久化服务实例
    private let persistenceService = PersistenceService.shared
    // 开机自启动服务实例（需要 macOS 13.0+）
    @available(macOS 13.0, *)
    private var launchAtLoginService: LaunchAtLoginService {
        return LaunchAtLoginService.shared
    }
    // Combine 订阅集合，用于管理响应式绑定
    private var cancellables = Set<AnyCancellable>()
    
    // 初始化方法
    init() {
        Logger.shared.info("MenuBarViewModel 初始化")
        // 先加载设置，再设置绑定，避免初始值覆盖保存的设置
        loadSettings()
        setupBindings()
        setupInputMethodLock()
    }
    
    // 设置响应式绑定，监听属性变化并执行相应操作
    private func setupBindings() {
        // 监听锁定状态变化
        $isLockEnabled
            .sink { [weak self] enabled in
                guard let self = self else { return }
                Logger.shared.info("锁定功能\(enabled ? "启用" : "禁用")")
                // 保存设置到持久化服务
                self.persistenceService.isLockEnabled = enabled
                // 同步到输入法服务
                self.inputMethodService.isLockEnabled = enabled
                
                if enabled {
                    // 启用锁定时，设置目标输入法并启用 Event Tap
                    self.inputMethodService.targetInputMethod = self.selectedInputMethod
                    self.inputMethodService.enableEventTap()
                    self.enforceInputMethodLock()
                } else {
                    // 禁用锁定时，禁用 Event Tap
                    self.inputMethodService.disableEventTap()
                }
            }
            .store(in: &cancellables)
        
        // 监听开机自启动状态变化
        $launchAtLogin
            .sink { [weak self] enabled in
                guard let self = self else { return }
                Logger.shared.info("开机自启动\(enabled ? "启用" : "禁用")")
                // 保存设置到持久化服务
                self.persistenceService.launchAtLogin = enabled
                // 同步到开机自启动服务
                if #available(macOS 13.0, *) {
                    self.launchAtLoginService.isEnabled = enabled
                }
            }
            .store(in: &cancellables)
        
        // 监听目标输入法变化，同步到输入法服务
        $selectedInputMethod
            .sink { [weak self] method in
                self?.inputMethodService.targetInputMethod = method
            }
            .store(in: &cancellables)
        
        // 监听输入法变化通知
        NotificationCenter.default.publisher(for: .inputMethodChanged)
            .sink { [weak self] _ in
                self?.handleInputMethodChanged()
            }
            .store(in: &cancellables)
        
        // 监听应用激活通知（当应用切换到前台时）
        NotificationCenter.default.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .sink { [weak self] notification in
                if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                    Logger.shared.debug("应用激活: \(app.localizedName ?? "未知")")
                }
                self?.handleApplicationActivated()
            }
            .store(in: &cancellables)
    }
    
    // 从持久化服务加载保存的设置
    private func loadSettings() {
        Logger.shared.debug("加载设置...")
        // 从持久化服务读取设置
        isLockEnabled = persistenceService.isLockEnabled
        launchAtLogin = persistenceService.launchAtLogin
        
        // 加载可用输入法列表
        loadInputMethods()
        
        // 恢复上次选择的输入法
        if let savedID = persistenceService.selectedInputMethodID,
           let savedMethod = availableInputMethods.first(where: { $0.id == savedID }) {
            selectedInputMethod = savedMethod
            Logger.shared.info("恢复上次选择的输入法: \(savedMethod.name)")
        } else if selectedInputMethod == nil, let first = availableInputMethods.first {
            // 如果没有保存的设置，选择第一个输入法作为默认
            selectedInputMethod = first
            persistenceService.selectedInputMethodID = first.id
            Logger.shared.info("默认选择第一个输入法: \(first.name)")
        }
        
        Logger.shared.info("设置加载完成 - 锁定: \(isLockEnabled), 开机自启: \(launchAtLogin), 目标: \(selectedInputMethod?.name ?? "未设置")")
    }
    
    // 加载可用输入法列表
    func loadInputMethods() {
        Logger.shared.debug("加载输入法列表...")
        inputMethodService.loadAvailableInputMethods()
        availableInputMethods = inputMethodService.availableInputMethods
    }
    
    // 用户选择输入法时调用
    func selectInputMethod(_ inputMethod: InputMethod) {
        Logger.shared.info("用户选择输入法: \(inputMethod.name)")
        // 更新选中的输入法
        selectedInputMethod = inputMethod
        // 保存选择到持久化服务
        persistenceService.selectedInputMethodID = inputMethod.id
        
        // 如果锁定功能已启用，立即切换输入法
        if isLockEnabled {
            Logger.shared.info("锁定已启用，立即切换输入法")
            _ = inputMethodService.selectInputMethod(inputMethod)
        }
    }
    
    // 设置输入法锁定功能
    private func setupInputMethodLock() {
        // 同步状态到输入法服务
        inputMethodService.isLockEnabled = isLockEnabled
        inputMethodService.targetInputMethod = selectedInputMethod
        
        if isLockEnabled {
            Logger.shared.info("启动时锁定已启用，启用 Event Tap")
            // 启用 Event Tap 拦截键盘事件
            inputMethodService.enableEventTap()
            // 立即执行一次锁定检查
            enforceInputMethodLock()
        }
    }
    
    // 处理输入法变化事件
    private func handleInputMethodChanged() {
        guard isLockEnabled else { return }
        guard let targetMethod = selectedInputMethod else { return }
        
        // 更新当前输入法状态
        if let current = inputMethodService.updateCurrentInputMethod() {
            if current.id != targetMethod.id {
                Logger.shared.debug("⚠️ 检测到输入法变化: \(current.name)，Event Tap 将在下次按键时恢复")
            }
        }
    }
    
    // 处理应用激活事件
    private func handleApplicationActivated() {
        guard isLockEnabled else { return }
        Logger.shared.debug("应用激活，Event Tap 将在下次按键时确保正确输入法")
    }
    
    // 强制执行输入法锁定
    private func enforceInputMethodLock() {
        guard let targetMethod = selectedInputMethod else { return }
        
        // 更新当前输入法状态
        if let current = inputMethodService.updateCurrentInputMethod() {
            // 如果当前输入法不是目标输入法，切换回目标输入法
            if current.id != targetMethod.id {
                Logger.shared.info("🔄 恢复输入法: \(current.name) -> \(targetMethod.name)")
                _ = inputMethodService.selectInputMethod(targetMethod)
            }
        }
    }
}
