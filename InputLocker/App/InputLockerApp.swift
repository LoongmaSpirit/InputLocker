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
        
        // 初始化视图模型
        viewModel = MenuBarViewModel()
        
        // 创建菜单栏状态项
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // 设置菜单栏按钮的图标和点击事件
        if let button = statusItem?.button {
            updateStatusItemIcon(button)
            button.action = #selector(statusItemClicked(_:))
            button.target = self
        }
        
        // 设置视图模型的观察者，监听状态变化
        setupViewModelObservers()
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
    
    // 菜单栏按钮点击事件处理
    @objc private func statusItemClicked(_ sender: Any?) {
        // 构建并显示菜单
        let menu = buildMenu()
        menu.delegate = self
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
    }
    
    // 菜单关闭时清空菜单引用
    func menuDidClose(_ menu: NSMenu) {
        statusItem?.menu = nil
    }
    
    // 构建菜单栏菜单
    private func buildMenu() -> NSMenu {
        guard let viewModel = viewModel else { return NSMenu() }
        
        let menu = NSMenu()
        
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
        
        return menu
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
