import SwiftUI

// 菜单栏主视图，显示应用的所有菜单项
@available(macOS 13.0, *)
struct MenuBarView: View {
    // 视图模型，管理应用状态
    @StateObject private var viewModel = MenuBarViewModel()
    // 是否显示调试信息窗口
    @State private var showDebugInfo = false
    
    // 主视图内容
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            headerSection
            Divider()
            enableLockSection
            Divider()
            targetMethodSection
            Divider()
            availableMethodsSection
            Divider()
            bottomSection
        }
        .padding(8)
        .frame(width: 280)
        .sheet(isPresented: $showDebugInfo) {
            DebugInfoView(viewModel: viewModel)
        }
    }
    
    // 标题区域
    private var headerSection: some View {
        Text("Input Lock")
            .font(.headline)
    }
    
    // 启用锁定选项
    private var enableLockSection: some View {
        Toggle("Enable Lock", isOn: $viewModel.isLockEnabled)
            .toggleStyle(.checkbox)
    }
    
    // 目标输入法显示区域
    private var targetMethodSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Target Input Method")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let selected = viewModel.selectedInputMethod {
                Text("✓ \(selected.name)")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 2)
    }
    
    // 可用输入法列表区域
    private var availableMethodsSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Available Input Methods")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // 遍历所有可用输入法
            ForEach(viewModel.availableInputMethods) { inputMethod in
                Button(action: {
                    // 点击时选择该输入法
                    viewModel.selectInputMethod(inputMethod)
                }) {
                    HStack {
                        Text(inputMethod.name)
                        Spacer()
                        // 如果是当前选中的输入法，显示勾选标记
                        if viewModel.selectedInputMethod?.id == inputMethod.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // 底部操作区域
    private var bottomSection: some View {
        VStack(spacing: 4) {
            // 开机自启动选项
            launchAtLoginSection
            Divider()
            // 显示调试信息按钮
            Button("Show Debug Info") {
                showDebugInfo.toggle()
            }
            // 退出应用按钮
            Button("Quit InputLocker") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
    
    // 开机自启动选项
    private var launchAtLoginSection: some View {
        Toggle("Launch at Login", isOn: $viewModel.launchAtLogin)
            .toggleStyle(.checkbox)
    }
}

// 调试信息视图，显示应用的状态和可用输入法列表
@available(macOS 13.0, *)
struct DebugInfoView: View {
    // 视图模型
    @ObservedObject var viewModel: MenuBarViewModel
    // 环境对象，用于关闭视图
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题栏
            HStack {
                Text("Debug Information")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("Close") {
                    dismiss()
                }
            }
            
            Divider()
            
            // 可滚动的内容区域
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    lockStatusSection
                    Divider()
                    targetMethodDetailSection
                    Divider()
                    availableMethodsDetailSection
                }
            }
        }
        .padding(20)
        .frame(width: 450, height: 500)
    }
    
    // 锁定状态显示
    private var lockStatusSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Lock Status")
                .font(.headline)
            Text(viewModel.isLockEnabled ? "Enabled" : "Disabled")
                .foregroundColor(viewModel.isLockEnabled ? .green : .secondary)
        }
    }
    
    // 目标输入法详细信息
    private var targetMethodDetailSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Target Input Method")
                .font(.headline)
            if let selected = viewModel.selectedInputMethod {
                Text("Name: \(selected.name)")
                Text("ID: \(selected.id)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Not set")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // 可用输入法详细信息列表
    private var availableMethodsDetailSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Available Input Methods (\(viewModel.availableInputMethods.count))")
                .font(.headline)
            
            // 遍历所有可用输入法，显示详细信息
            ForEach(viewModel.availableInputMethods) { method in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(method.name)
                            .fontWeight(.medium)
                        // 标记当前选中的输入法
                        if viewModel.selectedInputMethod?.id == method.id {
                            Text("(Selected)")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }
                    // 显示输入法 ID
                    Text(method.id)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
    }
}
