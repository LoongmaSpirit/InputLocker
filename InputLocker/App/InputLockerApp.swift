import SwiftUI
import AppKit
import Combine

// 应用程序入口点
@main
struct InputLockerApp: App {
    // 应用代理，处理应用生命周期事件
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // 使用空的设置场景，实际 UI 通过菜单栏实现
        Settings {
            EmptyView()
        }
    }
}

// 应用代理类，负责管理菜单栏图标和菜单
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    // 菜单栏状态项
    private var statusItem: NSStatusItem?
    // 视图模型，管理应用状态和业务逻辑
    private var viewModel: MenuBarViewModel?
    // Combine 订阅集合，用于管理响应式绑定
    private var cancellables = Set<AnyCancellable>()
    
    // 应用启动完成时调用
    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.shared.info("InputLocker 启动")
        
        // 作为纯菜单栏（Agent）应用运行，不显示 Dock 图标。
        // Info.plist 中已设置 LSUIElement = YES，二者保持一致。
        NSApp.setActivationPolicy(.accessory)
        
        // 初始化视图模型
        viewModel = MenuBarViewModel()
        
        // 设置视图模型的观察者，监听状态变化
        setupViewModelObservers()
        
        // macOS 15 (Sequoia) 回归修复：
        // SwiftUI App 生命周期下，若在 applicationDidFinishLaunching 内同步创建
        // NSStatusItem，菜单栏窗口尚未就绪，状态项不会出现在菜单栏。
        // 延迟到下一个 RunLoop 周期再创建即可稳定显示。
        DispatchQueue.main.async { [weak self] in
            self?.setupStatusItem()
        }
    }
    
    // 创建菜单栏状态项（需在 RunLoop 已就绪后调用）
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // 设置菜单栏按钮的图标
        if let button = statusItem?.button {
            updateStatusItemIcon(button)
        }
        
        // 将菜单直接挂到 statusItem.menu，由 AppKit 在点击时原生弹出；
        // 不再使用 button.action + performClick(nil) 的手动触发方式
        // （该方式在 macOS 15 下不可靠）。
        let menu = buildMenu()
        statusItem?.menu = menu
    }
    
    // 应用即将退出时调用
    func applicationWillTerminate(_ notification: Notification) {
        Logger.shared.info("InputLocker 退出")
    }
    
    // 设置视图模型的观察者，监听状态变化并更新 UI
    private func setupViewModelObservers() {
        // 监听锁定状态变化，更新菜单栏图标
        viewModel?.$isLockEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                if let button = self?.statusItem?.button {
                    self?.updateStatusItemIcon(button)
                }
            }
            .store(in: &cancellables)
        
        // 监听目标输入法变化，更新菜单栏图标
        viewModel?.$selectedInputMethod
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                if let button = self?.statusItem?.button {
                    self?.updateStatusItemIcon(button)
                }
            }
            .store(in: &cancellables)
    }
    
    // 更新菜单栏按钮图标
    private func updateStatusItemIcon(_ button: NSStatusBarButton) {
        // 锁定启用时显示锁图标，否则显示键盘图标
        let iconName = viewModel?.isLockEnabled == true ? "lock.fill" : "keyboard"
        button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "InputLocker")
    }
    
    // 菜单即将弹出时重建内容，确保勾选状态与视图模型当前值一致
    func menuWillOpen(_ menu: NSMenu) {
        populateMenu(menu)
    }
    
    // 构建菜单栏菜单
    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        populateMenu(menu)
        return menu
    }
    
    // 将当前视图模型状态写入菜单项（每次弹出前调用，保证勾选状态最新）
    private func populateMenu(_ menu: NSMenu) {
        guard let viewModel = viewModel else { return }
        menu.removeAllItems()

        
        // 标题项
        let titleItem = NSMenuItem(title: "Input Lock", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 启用/禁用锁定选项
        let enableLockItem = NSMenuItem(title: "Enable Lock", action: #selector(toggleLock(_:)), keyEquivalent: "")
        enableLockItem.target = self
        enableLockItem.state = viewModel.isLockEnabled ? .on : .off
        menu.addItem(enableLockItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 目标输入法标签
        let targetLabel = NSMenuItem(title: "Target Input Method", action: nil, keyEquivalent: "")
        targetLabel.isEnabled = false
        menu.addItem(targetLabel)
        
        // 显示当前目标输入法
        if let selected = viewModel.selectedInputMethod {
            let selectedItem = NSMenuItem(title: "✓ \(selected.name)", action: nil, keyEquivalent: "")
            selectedItem.isEnabled = false
            menu.addItem(selectedItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // 可用输入法列表标签
        let availableLabel = NSMenuItem(title: "Available Input Methods", action: nil, keyEquivalent: "")
        availableLabel.isEnabled = false
        menu.addItem(availableLabel)
        
        // 添加所有可用输入法选项
        for inputMethod in viewModel.availableInputMethods {
            let item = NSMenuItem(title: inputMethod.name, action: #selector(selectInputMethod(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = inputMethod
            // 标记当前选中的输入法
            if viewModel.selectedInputMethod?.id == inputMethod.id {
                item.state = .on
            }
            menu.addItem(item)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // 开机自启动选项
        let launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        launchAtLoginItem.target = self
        launchAtLoginItem.state = viewModel.launchAtLogin ? .on : .off
        menu.addItem(launchAtLoginItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 退出应用选项
        let quitItem = NSMenuItem(title: "Quit InputLocker", action: #selector(quitApp(_:)), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }
    
    // 切换锁定状态
    @objc private func toggleLock(_ sender: Any?) {
        viewModel?.isLockEnabled.toggle()
    }
    
    // 选择目标输入法
    @objc private func selectInputMethod(_ sender: Any?) {
        guard let menuItem = sender as? NSMenuItem,
              let inputMethod = menuItem.representedObject as? InputMethod else {
            Logger.shared.error("无法获取选中的输入法")
            return
        }
        Logger.shared.info("用户从菜单选择输入法: \(inputMethod.name)")
        viewModel?.selectInputMethod(inputMethod)
    }
    
    // 切换开机自启动状态
    @objc private func toggleLaunchAtLogin(_ sender: Any?) {
        viewModel?.launchAtLogin.toggle()
    }
    
    // 退出应用
    @objc private func quitApp(_ sender: Any?) {
        NSApplication.shared.terminate(nil)
    }
}
