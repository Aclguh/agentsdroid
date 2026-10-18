<div align="center">

<img src="docs/icon.png" width="120" alt="AgentsDroid Icon" />

# AgentsDroid

**A mobile-first open-source AI coding agent workbench designed for Android.**

Code, debug, run tests, and manage Git projects directly from your phone — Zero Root Required, Zero External App Dependencies.

[![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.13-0175C2?logo=dart)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android)](#download--releases)
[![Release](https://img.shields.io/github/v/release/Aclguh/agentsdroid?label=Download)](https://github.com/Aclguh/agentsdroid/releases/latest)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

[简体中文](README.md) · **English**

</div>

---

## Download & Releases

Download the suitable Release APK package for your device from [GitHub Releases](https://github.com/Aclguh/agentsdroid/releases/latest):

| Package Name | Architecture | File Size | Description |
| :--- | :--- | :--- | :--- |
| `AgentsDroid-arm64-v8a-release.apk` | ARM 64-bit (arm64-v8a) | 23.8 MB | Most modern Android smartphones (Recommended) |
| `AgentsDroid-release.apk` | Universal Package | 60.8 MB | Contains all CPU ABIs, broadest compatibility |
| `AgentsDroid-armeabi-v7a-release.apk` | ARM 32-bit (armeabi-v7a) | 21.8 MB | Legacy 32-bit Android devices |
| `AgentsDroid-x86_64-release.apk` | x86_64 | 25.3 MB | 64-bit x86 Android emulators or desktop containers |

---

## Highlights

- **Zero Root Required**: Runs in standard Android user-space with no root privileges and no need to install secondary apps like Termux.
- **Dual Agent Engine Coordination**:
  - **Built-in Native Dart Agent**: Instant startup, direct integration with Anthropic Claude, DeepSeek, Google Gemini, OpenAI, or custom OpenAI-compatible endpoints.
  - **Official Claude Code CLI Adapter**: Runs official `@anthropic-ai/claude-code` and Node.js directly inside the embedded Debian PRoot sandbox.
- **Intelligent ANSI Stream Parser**:
  - Automatically cleans terminal ANSI escape sequences and extracts thoughts, tool commands, unified diffs, and file edits.
  - **Interactive Confirmation Interception**: Seamlessly captures `[y/n]` CLI prompts and presents them as native approval cards, feeding response back to stdin.
- **Unified Native GUI**:
  - Structured chat with interactive **Tool Approval Cards** (`Approve`, `Reject`).
  - Expandable **Reasoning / Thought Cards**.
  - Built-in **Diff Review Screen** with color-coded line numbers and one-click code copy.
  - **Workspace File Explorer**: Create files/folders, clone external Git repositories, and export workspace as a Zip archive.
- **Android Foreground Persistence & WakeLock**: Coordinates partial CPU wake locks and foreground notifications to prevent system throttling during long tasks.
- **Internationalization (i18n)**: Out-of-the-box support for Simplified Chinese and English with in-app language switching.
- **Secure Key Vault**: API keys encrypted via Android Hardware Keystore (`flutter_secure_storage`).
- **Smart Safety Control**:
  - Read-only actions (read file, list dir, search) execute automatically.
  - Modifying actions (patch file, write file, bash command) prompt for user confirmation.
  - Autonomous YOLO mode toggle available for power users.

---

## Architecture Overview

```
agentsdroid/
├── lib/
│   ├── core/
│   │   ├── agent/             # Abstract AgentEngine interface & EngineCoordinator
│   │   ├── builtin/           # BuiltinAgentEngine (LLM tool loop, Diff generation)
│   │   ├── cli/               # ClaudeCodeAdapter & AnsiStreamParser (CLI stream to native cards)
│   │   ├── notification/      # ForegroundServiceManager (Foreground notifications & WakeLock)
│   │   ├── proot/             # PRootManager (Debian-arm64 download, unpack & sandbox exec)
│   │   └── storage/           # KeyVault, WorkspaceService & SessionService (Session History)
│   ├── l10n/                  # AppLocalizations & ARB translation files (zh, en)
│   ├── models/                # AgentEvent, ToolCallEvent, DiffEvent, ChatMessage, ChatSession
│   ├── ui/
│   │   ├── chat/              # Main Workbench: Chat bubbles, engine switch chip, ThoughtCard, ToolApprovalCard
│   │   ├── diff/              # Native DiffViewerScreen with code copy
│   │   ├── explorer/          # WorkspaceExplorerScreen (file tree, Zip export, Git clone)
│   │   ├── settings/          # Provider & Model Settings, Language Switcher, YOLO switch
│   │   └── terminal/          # SubsystemTerminalScreen (Debian console & toolchain status)
│   └── main.dart              # App initialization & dark theme
└── android/                   # Android native manifest, permissions & foreground service
```

---

## Getting Started

### Prerequisites
- Flutter SDK 3.47+ / Dart 3.13+
- Android Studio / Android SDK (API 26+)

### Run Development
```bash
flutter pub get
flutter test
flutter run
```

### Build APK
```bash
flutter build apk --release
```

---

## License

This project is licensed under the [MIT License](LICENSE).
