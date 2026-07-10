import Foundation
import Carbon
import AppKit

// 输入法服务类，负责管理输入法相关的核心功能
// 包括：获取可用输入法列表、切换输入法、监听输入法变化、轮询检测等
class InputMethodService: ObservableObject {
    // 单例模式，全局唯一实例
    static let shared = InputMethodService()
    
    // 当前激活的输入法
    @Published var currentInputMethod: InputMethod?
    // 系统中所有可用的输入法列表
    @Published var availableInputMethods: [InputMethod] = []
    
    // 是否启用输入法锁定功能
    var isLockEnabled: Bool = false
    // 目标输入法（用户希望锁定的输入法）
    var targetInputMethod: InputMethod?
    
    // 轮询定时器，用于定期检测输入法变化
    private var pollTimer: Timer?
    // CGEvent Tap，用于拦截键盘事件
    private var eventTap: CFMachPort?
    // RunLoop Source，用于将 Event Tap 添加到 RunLoop
    private var runLoopSource: CFRunLoopSource?
    // 上次切换输入法的时间，用于防抖
    private var lastSwitchTime: Date = .distantPast
    // 切换冷却时间（秒），防止频繁切换
    private let switchCooldown: TimeInterval = 0.1
    
    // 私有初始化方法，确保单例模式
    private init() {
        Logger.shared.info("InputMethodService 初始化")
        // 加载系统可用的输入法列表
        loadAvailableInputMethods()
        // 获取当前激活的输入法
        updateCurrentInputMethod()
        // 设置输入法变化监听
        setupInputMethodChangeNotification()
        // 启动轮询检测
        startPolling()
    }
    
    // 析构方法，清理资源
    deinit {
        stopMonitoring()
        disableEventTap()
        pollTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    // 加载系统中所有可用的输入法
    func loadAvailableInputMethods() {
        Logger.shared.debug("开始加载可用输入法列表...")
        
        // 使用 Carbon API 获取键盘类型的输入源
        let filter = [kTISPropertyInputSourceCategory!: kTISCategoryKeyboardInputSource!] as CFDictionary
        guard let inputSources = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource] else {
            Logger.shared.error("无法获取输入法列表")
            return
        }
        
        // 用于去重的集合
        var seenIDs = Set<String>()
        var methods: [InputMethod] = []
        
        // 遍历所有输入源，过滤出可用的输入法
        for source in inputSources {
            // 获取输入法的唯一标识符
            guard let id = getStringProperty(source, kTISPropertyInputSourceID) else { continue }
            // 跳过重复的输入法
            if seenIDs.contains(id) { continue }
            
            // 检查输入法是否可被选择（过滤掉系统内部使用的输入法）
            let isSelectCapable = getBoolProperty(source, kTISPropertyInputSourceIsSelectCapable)
            if !isSelectCapable { continue }
            
            seenIDs.insert(id)
            // 获取输入法的本地化名称
            let name = getStringProperty(source, kTISPropertyLocalizedName) ?? id
            methods.append(InputMethod(id: id, name: name, bundleID: ""))
        }
        
        // 按名称排序并保存
        availableInputMethods = methods.sorted { $0.name < $1.name }
        
        Logger.shared.info("成功加载 \(availableInputMethods.count) 个可用输入法")
        for method in availableInputMethods {
            Logger.shared.info("  - \(method.name) [\(method.id)]")
        }
    }
    
    // 更新当前激活的输入法信息
    @discardableResult
    func updateCurrentInputMethod() -> InputMethod? {
        // 使用 Carbon API 获取当前输入法
        guard let currentSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }
        guard let id = getStringProperty(currentSource, kTISPropertyInputSourceID) else { return nil }
        
        let name = getStringProperty(currentSource, kTISPropertyLocalizedName) ?? id
        let newMethod = InputMethod(id: id, name: name, bundleID: "")
        
        // 如果输入法发生变化，记录日志
        if currentInputMethod?.id != id {
            Logger.shared.info("输入法已变化: \(currentInputMethod?.name ?? "无") -> \(name)")
        }
        
        currentInputMethod = newMethod
        return newMethod
    }
    
    // 切换到指定的输入法
    func selectInputMethod(_ inputMethod: InputMethod) -> Bool {
        Logger.shared.info("尝试切换到输入法: \(inputMethod.name) [\(inputMethod.id)]")
        
        // 根据输入法 ID 查找对应的输入源
        let filter = [kTISPropertyInputSourceID!: inputMethod.id as CFString] as CFDictionary
        guard let sources = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource],
              let targetSource = sources.first else {
            Logger.shared.error("找不到目标输入法: \(inputMethod.id)")
            return false
        }
        
        // 使用 Carbon API 切换输入法
        let status = TISSelectInputSource(targetSource)
        if status == noErr {
            Logger.shared.info("✓ 成功切换到输入法: \(inputMethod.name)")
            currentInputMethod = inputMethod
            return true
        } else {
            Logger.shared.error("✗ 切换输入法失败，错误码: \(status)")
            return false
        }
    }
    
    // 设置输入法变化监听（使用 Darwin Notification Center）
    func setupInputMethodChangeNotification() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()
        let notificationName = "com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged" as CFString
        
        // 添加观察者，当输入法变化时触发回调
        CFNotificationCenterAddObserver(
            center,
            observer,
            { _, observer, _, _, _ in
                guard let observer = observer else { return }
                let service = Unmanaged<InputMethodService>.fromOpaque(observer).takeUnretainedValue()
                DispatchQueue.main.async {
                    service.updateCurrentInputMethod()
                    NotificationCenter.default.post(name: .inputMethodChanged, object: nil)
                }
            },
            notificationName,
            nil,
            .deliverImmediately
        )
        
        Logger.shared.info("✓ 已设置输入法变化监听")
    }
    
    // 启动轮询检测，定期检查输入法是否发生变化
    func startPolling() {
        Logger.shared.debug("启动输入法轮询（0.1秒间隔）")
        pollTimer?.invalidate()
        // 每 0.1 秒检查一次输入法状态
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // 如果锁定功能启用，检查输入法是否需要恢复
            if self.isLockEnabled, let target = self.targetInputMethod {
                let oldID = self.currentInputMethod?.id
                self.updateCurrentInputMethod()
                let newID = self.currentInputMethod?.id
                
                // 如果输入法发生变化且不是目标输入法，立即恢复
                if oldID != newID && newID != target.id {
                    Logger.shared.info("⚡ 轮询检测到输入法变化，立即恢复")
                    self.selectInputMethodDirect(target)
                }
            }
        }
    }
    
    // 停止输入法变化监听
    func stopMonitoring() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterRemoveEveryObserver(center, Unmanaged.passUnretained(self).toOpaque())
    }
    
    // MARK: - Event Tap
    
    // 启用 CGEvent Tap，用于拦截键盘事件
    func enableEventTap() {
        guard eventTap == nil else {
            Logger.shared.debug("Event Tap 已经启用")
            return
        }
        
        Logger.shared.info("正在创建 Event Tap...")
        // 监听 keyDown 事件
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        let context = Unmanaged.passUnretained(self).toOpaque()
        
        // 创建 Event Tap
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, type, event, userInfo -> Unmanaged<CGEvent>? in
                guard let userInfo = userInfo else {
                    return Unmanaged.passRetained(event)
                }
                
                let service = Unmanaged<InputMethodService>.fromOpaque(userInfo).takeUnretainedValue()
                
                // 处理 keyDown 事件
                if type == .keyDown && service.isLockEnabled {
                    let flags = event.flags
                    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                    
                    // 检测 Control+Space (Control 键 + Space 键 keyCode 49)
                    if flags.contains(.maskControl) && keyCode == 49 {
                        Logger.shared.info("⚡ Event Tap: 拦截到 Control+Space，阻止输入法切换")
                        // 立即切换回目标输入法
                        if let target = service.targetInputMethod {
                            service.selectInputMethodDirect(target)
                        }
                        // 返回 nil 阻止事件继续传播
                        return nil
                    }
                    
                    // 检测 CapsLock (keyCode 57)
                    if keyCode == 57 {
                        Logger.shared.debug("检测到 CapsLock 按键")
                        // 检查输入法是否需要恢复
                        service.updateCurrentInputMethod()
                        if let current = service.currentInputMethod, 
                           let target = service.targetInputMethod,
                           current.id != target.id {
                            Logger.shared.info("⚡ Event Tap: CapsLock 导致输入法变化，恢复 \(current.name) -> \(target.name)")
                            service.selectInputMethodDirect(target)
                        }
                    }
                    
                    // 检测 Command+Space (keyCode 49 + Command 键)
                    if flags.contains(.maskCommand) && keyCode == 49 {
                        Logger.shared.info("⚡ Event Tap: 拦截到 Command+Space，阻止输入法切换")
                        if let target = service.targetInputMethod {
                            service.selectInputMethodDirect(target)
                        }
                        return nil
                    }
                }
                
                return Unmanaged.passRetained(event)
            },
            userInfo: context
        ) else {
            Logger.shared.error("✗ Event Tap 创建失败 - 请在系统偏好设置中授予 Input Monitoring 权限")
            return
        }
        
        // 将 Event Tap 添加到 RunLoop
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        
        eventTap = tap
        runLoopSource = source
        
        Logger.shared.info("✓ Event Tap 已成功启用")
    }
    
    // 禁用 CGEvent Tap
    func disableEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            }
            eventTap = nil
            runLoopSource = nil
            Logger.shared.info("Event Tap 已禁用")
        }
    }
    
    // 检查是否有输入监控权限
    func checkPermission() -> Bool {
        let trustStatus = CGPreflightListenEventAccess()
        return trustStatus == true
    }
    
    // 请求输入监控权限
    func requestPermission() {
        CGRequestListenEventAccess()
    }
    
    // MARK: - Private Methods
    
    // 直接切换输入法（不触发额外事件）
    private func selectInputMethodDirect(_ inputMethod: InputMethod) {
        let filter = [kTISPropertyInputSourceID!: inputMethod.id as CFString] as CFDictionary
        guard let sources = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource],
              let targetSource = sources.first else { return }
        
        let status = TISSelectInputSource(targetSource)
        if status == noErr {
            currentInputMethod = inputMethod
            // 使用更快的方式强制刷新应用
            DispatchQueue.main.async {
                // 发送一个虚拟的 flagsChanged 事件来触发应用重新读取输入法
                if let source = CGEventSource(stateID: .combinedSessionState) {
                    // 发送一个虚拟的 Control 键按下/释放事件（不会真正触发任何操作）
                    if let flagsDown = CGEvent(keyboardEventSource: source, virtualKey: 0x3B, keyDown: true),
                       let flagsUp = CGEvent(keyboardEventSource: source, virtualKey: 0x3B, keyDown: false) {
                        flagsDown.type = .flagsChanged
                        flagsUp.type = .flagsChanged
                        flagsDown.post(tap: .cgSessionEventTap)
                        flagsUp.post(tap: .cgSessionEventTap)
                    }
                }
            }
        }
    }
    
    // 获取输入法的字符串属性
    private func getStringProperty(_ source: TISInputSource, _ key: CFString) -> String? {
        guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
    }
    
    // 获取输入法的布尔属性
    private func getBoolProperty(_ source: TISInputSource, _ key: CFString) -> Bool {
        guard let pointer = TISGetInputSourceProperty(source, key) else { return false }
        return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(pointer).takeUnretainedValue())
    }
}

// 输入法变化通知的扩展
extension Notification.Name {
    static let inputMethodChanged = Notification.Name("inputMethodChanged")
}
