import Foundation
import ServiceManagement

// 开机自启动服务类，负责管理应用的开机自启动功能
// 同时支持 macOS 13.0+ 的 SMAppService 和旧版本的 LSSharedFileList
class LaunchAtLoginService {
    // 单例模式，全局唯一实例
    static let shared = LaunchAtLoginService()
    
    // 私有初始化方法
    private init() {}
    
    // 是否启用开机自启动
    var isEnabled: Bool {
        get {
            if #available(macOS 13.0, *) {
                // macOS 13.0+ 使用 SMAppService
                return SMAppService.mainApp.status == .enabled
            } else {
                // macOS 12 及以下使用 LSSharedFileList
                return isLaunchAtLoginEnabledLegacy()
            }
        }
        set {
            do {
                if newValue {
                    // 启用开机自启动
                    if #available(macOS 13.0, *) {
                        try SMAppService.mainApp.register()
                    } else {
                        enableLaunchAtLoginLegacy()
                    }
                    Logger.shared.info("已启用开机自启动")
                } else {
                    // 禁用开机自启动
                    if #available(macOS 13.0, *) {
                        try SMAppService.mainApp.unregister()
                    } else {
                        disableLaunchAtLoginLegacy()
                    }
                    Logger.shared.info("已禁用开机自启动")
                }
            } catch {
                Logger.shared.error("设置开机自启动失败: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Legacy Methods (macOS 12 及以下)
    
    // 检查是否已启用开机自启动（旧版 API）
    private func isLaunchAtLoginEnabledLegacy() -> Bool {
        guard let loginItemsRef = LSSharedFileListCreate(
            nil,
            kLSSharedFileListSessionLoginItems.takeRetainedValue(),
            nil
        )?.takeRetainedValue() else {
            return false
        }
        
        let loginItems = LSSharedFileListCopySnapshot(loginItemsRef, nil)?.takeRetainedValue() as? [LSSharedFileListItem] ?? []
        
        guard let appURL = Bundle.main.bundleURL as CFURL? else {
            return false
        }
        
        for item in loginItems {
            var itemURL: Unmanaged<CFURL>?
            let result = LSSharedFileListItemResolve(item, 0, &itemURL, nil)
            if result == noErr, let url = itemURL?.takeRetainedValue() as URL?, url == appURL as URL {
                return true
            }
        }
        
        return false
    }
    
    // 启用开机自启动（旧版 API）
    private func enableLaunchAtLoginLegacy() {
        guard let loginItemsRef = LSSharedFileListCreate(
            nil,
            kLSSharedFileListSessionLoginItems.takeRetainedValue(),
            nil
        )?.takeRetainedValue() else {
            Logger.shared.error("无法创建登录项列表")
            return
        }
        
        guard let appURL = Bundle.main.bundleURL as CFURL? else {
            Logger.shared.error("无法获取应用 URL")
            return
        }
        
        LSSharedFileListInsertItemURL(
            loginItemsRef,
            kLSSharedFileListItemBeforeFirst.takeRetainedValue(),
            nil,
            nil,
            appURL,
            nil,
            nil
        )
        
        Logger.shared.info("已使用旧版 API 启用开机自启动")
    }
    
    // 禁用开机自启动（旧版 API）
    private func disableLaunchAtLoginLegacy() {
        guard let loginItemsRef = LSSharedFileListCreate(
            nil,
            kLSSharedFileListSessionLoginItems.takeRetainedValue(),
            nil
        )?.takeRetainedValue() else {
            Logger.shared.error("无法创建登录项列表")
            return
        }
        
        let loginItems = LSSharedFileListCopySnapshot(loginItemsRef, nil)?.takeRetainedValue() as? [LSSharedFileListItem] ?? []
        
        guard let appURL = Bundle.main.bundleURL as CFURL? else {
            Logger.shared.error("无法获取应用 URL")
            return
        }
        
        for item in loginItems {
            var itemURL: Unmanaged<CFURL>?
            let result = LSSharedFileListItemResolve(item, 0, &itemURL, nil)
            if result == noErr, let url = itemURL?.takeRetainedValue() as URL?, url == appURL as URL {
                LSSharedFileListItemRemove(loginItemsRef, item)
                Logger.shared.info("已使用旧版 API 禁用开机自启动")
                break
            }
        }
    }
}
