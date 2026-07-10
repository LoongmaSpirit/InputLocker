import Foundation
import os.log

// 日志工具类，提供统一的日志记录功能
// 支持不同级别的日志：debug、info、warning、error
class Logger {
    // 单例模式，全局唯一实例
    static let shared = Logger()
    
    // Apple 系统日志记录器
    private let logger: os.Logger
    // 日期格式化器，用于格式化日志时间戳
    private let dateFormatter: DateFormatter
    
    // 私有初始化方法
    private init() {
        // 创建系统日志记录器，指定子系统名称和分类
        logger = os.Logger(subsystem: "com.inputlocker.app", category: "InputLocker")
        // 配置日期格式化器
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
    }
    
    // 格式化日志消息，添加时间戳和日志级别
    private func formatMessage(_ level: String, _ message: String) -> String {
        let timestamp = dateFormatter.string(from: Date())
        return "[\(timestamp)] [\(level)] \(message)"
    }
    
    // 记录调试级别日志
    func debug(_ message: String) {
        logger.debug("\(message)")
        #if DEBUG
        print(formatMessage("DEBUG", message))
        #endif
    }
    
    // 记录信息级别日志
    func info(_ message: String) {
        logger.info("\(message)")
        #if DEBUG
        print(formatMessage("INFO", message))
        #endif
    }
    
    // 记录警告级别日志
    func warning(_ message: String) {
        logger.warning("\(message)")
        #if DEBUG
        print(formatMessage("WARN", message))
        #endif
    }
    
    // 记录错误级别日志
    func error(_ message: String) {
        logger.error("\(message)")
        #if DEBUG
        print(formatMessage("ERROR", message))
        #endif
    }
}
