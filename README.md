# AgentsDroid 🤖📱

**简体中文** | [English](README_en.md)

> **AgentsDroid** 是一款专为 Android 设备打造的移动端开源 AI 编程 Agent 工作台。  
> 让你脱离 PC 电脑，仅凭一台安卓手机即可调度 AI Agent 进行代码审查、编写、Bug 修复、Git 管理及终端命令测试 —— **免 Root 权限，零外部 App 依赖**。

---

## ✨ 核心特性

- **🔒 零 Root 权限原则**：完全基于 Android 用户态运行，无需系统提权越狱，更无需安装 Termux 等辅助工具。
- **⚡ 双 Agent 引擎驱动**：
  - **内置 Dart 原生 Agent 引擎**：开箱即用、毫秒级秒开，直接支持 Anthropic Claude、DeepSeek、Google Gemini、OpenAI 或自定义中转 API。
  - **嵌入式 PRoot Linux 子系统**：在 App 私有沙箱内运行标准 Debian-arm64 环境，支持安装运行官方原版发布的 `@anthropic-ai/claude-code`、`aider`，以及官方 Node.js/Python/Git，拒绝民间魔改版。
- **🎨 统一原生 GUI 交互**：
  - 智能**工具审批卡片**（支持「单次允许」、「本轮全部放行」、「拒绝」）。
  - 可折叠的**推理思考卡片**（展开可查看 Agent 完整思考过程）。
  - 内置**代码 Diff 审查面板**（清晰高亮新增与删除行，支持行号对比）。
  - **移动端项目文件树浏览器**，随手点选查看源码。
- **🌐 国际化支持 (i18n)**：默认简体中文，支持在设置中一键无缝切换至英文。
- **🔐 硬件级安全密钥库**：API Key 通过 Android KeyStore 硬件加密安全持久化。
- **🛡️ 智能分级安全控制**：
  - 只读操作（查看文件、目录列出、文本搜索）自动安全放行。
  - 写文件、打补丁、执行命令等操作弹出原生卡片由用户审批。
  - 为极客与高级用户提供一键开启的完全自主模式 (YOLO Mode)。

---

## 🏗️ 架构概览

```
agentsdroid/
├── lib/
│   ├── core/
│   │   ├── agent/             # Agent 引擎接口与事件契约 (AgentEngine)
│   │   ├── builtin/           # BuiltinAgentEngine (LLM 工具调用循环与 Diff 生成)
│   │   ├── proot/             # PRootManager (Debian-arm64 子系统下载、解压与沙箱执行)
│   │   └── storage/           # KeyVault (硬件加密保险箱) 与 WorkspaceService (POSIX 工作区)
│   ├── l10n/                  # 国际化本地化资源包 (zh, en)
│   ├── models/                # AgentEvent, ToolCallEvent, DiffEvent, ChatMessage
│   ├── ui/
│   │   ├── chat/              # 主工作台：对话流、ThoughtCard、ToolApprovalCard
│   │   ├── diff/              # 原生 DiffViewerScreen 变更对比
│   │   ├── explorer/          # WorkspaceExplorerScreen (项目文件树与查看器)
│   │   └── settings/          # 设置中心：服务商配置、多语言切换、PRoot 子系统管理
│   └── main.dart              # 应用入口、国际化注入与现代深色主题
└── android/                   # 纯粹的 Android 原生工程与权限声明
```

---

## 🚀 快速上手

### 环境要求
- Flutter SDK 3.47+ / Dart 3.13+
- Android Studio / Android SDK (API 26+)

### 本地开发
```bash
# 获取依赖与生成本地化代码
flutter pub get
flutter gen-l10n

# 运行测试与静态检查
flutter test
flutter analyze

# 启动运行
flutter run
```

### 构建 APK
```bash
flutter build apk --release
```
