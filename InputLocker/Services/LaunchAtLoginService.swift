import Foundation
import ServiceManagement

// 开机自启动服务类，负责管理应用的开机自启动功能
// 使用 Apple 官方推荐的 SMAppService API（macOS 13.0+）
@available(macOS 13.0, *)
class LaunchAtLoginService {
    // 单例模式，全局唯一实例
    static let shared = LaunchAtLoginService()
    
    // 私有初始化方法
    private init() {}
    
    // 是否启用开机自启动
    var isEnabled: Bool {
        get {
            // 检查 SMAppService 的状态是否为已启用
            return SMAppService.mainApp.status == .enabled
        }
        set {
            do {
                if newValue {
                    // 注册开机自启动
                    try SMAppService.mainApp.register()
                    Logger.shared.info("已启用开机自启动")
                } else {
                    // 取消注册开机自启动
                    try SMAppService.mainApp.unregister()
                    Logger.shared.info("已禁用开机自启动")
                }
            } catch {
                Logger.shared.error("设置开机自启动失败: \(error.localizedDescription)")
            }
        }
    }
}
