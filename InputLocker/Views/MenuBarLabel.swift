import SwiftUI

// 菜单栏标签视图，显示菜单栏图标
struct MenuBarLabel: View {
    // 视图模型，用于获取锁定状态
    @StateObject private var viewModel = MenuBarViewModel()
    
    var body: some View {
        HStack(spacing: 2) {
            // 根据锁定状态显示不同的图标
            // 锁定启用时显示锁图标，否则显示键盘图标
            Image(systemName: viewModel.isLockEnabled ? "lock.fill" : "keyboard")
                .foregroundColor(viewModel.isLockEnabled ? .blue : .secondary)
        }
    }
}
