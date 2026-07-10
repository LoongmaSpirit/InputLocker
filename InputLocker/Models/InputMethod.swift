import Foundation

// 输入法模型，表示系统中可用的输入法
struct InputMethod: Identifiable, Equatable, Codable {
    // 输入法的唯一标识符（如：com.sogou.inputmethod.sogou.pinyin）
    let id: String
    // 输入法的本地化显示名称（如：搜狗拼音）
    let name: String
    // 输入法的 Bundle ID
    let bundleID: String
    
    // 显示名称，如果 name 为空则使用 id
    var displayName: String {
        name.isEmpty ? id : name
    }
    
    // 判断两个输入法是否相同（基于 id）
    static func == (lhs: InputMethod, rhs: InputMethod) -> Bool {
        lhs.id == rhs.id
    }
}
