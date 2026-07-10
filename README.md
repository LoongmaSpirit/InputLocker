# InputLocker

一款 macOS 输入法锁定工具，解决 macOS 系统自动切换输入法的问题。

## 功能特性

- **输入法锁定**：锁定指定输入法，防止系统自动切换
- **自动恢复**：检测到输入法变化后自动恢复到目标输入法
- **开机自启动**：支持随系统启动自动运行
- **菜单栏应用**：轻量级菜单栏应用，不占用桌面空间
- **设置持久化**：所有配置自动保存，重启后保持

## 技术栈

- **语言**：Swift 5
- **框架**：SwiftUI, AppKit
- **最低系统要求**：macOS 12.4+
- **架构**：MVVM

## 安装使用

### 编译运行

1. 使用 Xcode 打开项目：
   ```bash
   open InputLocker.xcodeproj
   ```

2. 编译 Release 版本：
   ```bash
   xcodebuild -project InputLocker.xcodeproj -scheme InputLocker -configuration Release clean build
   ```

### 使用说明

1. 启动应用后，菜单栏会出现应用图标
2. 点击图标打开菜单
3. 勾选 "Enable Lock" 启用输入法锁定
4. 从列表中选择要锁定的输入法
5. 可选勾选 "Launch at Login" 实现开机自启动

## 项目结构

```
InputLocker/
├── App/                          # 应用入口和菜单栏管理
│   └── InputLockerApp.swift
├── Models/                       # 数据模型
│   └── InputMethod.swift
├── Services/                     # 服务层
│   ├── InputMethodService.swift  # 输入法核心服务
│   ├── PersistenceService.swift  # 持久化服务
│   └── LaunchAtLoginService.swift # 开机自启动服务
├── ViewModels/                   # 视图模型
│   └── MenuBarViewModel.swift
├── Views/                        # 视图层
│   ├── MenuBarView.swift
│   └── MenuBarLabel.swift
├── Utilities/                    # 工具类
│   └── Logger.swift
├── Resources/                    # 资源文件
│   └── AppIcon.svg
└── Assets.xcassets/             # 图标资源
    └── AppIcon.appiconset/
```

## 注意事项

### 权限要求

首次运行时，系统可能会提示需要"输入监控"权限：
1. 打开"系统偏好设置"
2. 进入"安全性与隐私" > "隐私" > "输入监控"
3. 勾选 InputLocker

### 已知限制

由于 macOS 系统机制，Control+Space 等系统级快捷键无法完全阻止。但 InputLocker 会在检测到变化后立即恢复（约 0.1 秒内）。

### 兼容性

- 支持所有第三方输入法（搜狗、微信、Rime 等）
- 支持 macOS 12.7 版本
- 支持 Intel 芯片

## 开发说明

### 调试日志

应用内置详细的日志系统，可通过以下命令查看：
```bash
log show --predicate 'subsystem == "com.inputlocker.app"' --last 2m
```

## 反馈与支持

如有问题或建议，欢迎提交 Issue。
