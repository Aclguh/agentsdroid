# AgentsDroid

[简体中文](README.md) | **English**

> **AgentsDroid** is an open-source, mobile-first AI coding agent workbench designed for Android.  
> Code, debug, run tests, and manage Git projects directly from your phone — **Zero Root Required, Zero External App Dependencies**.

---

## Highlights

- **Zero Root Required**: Runs in standard Android user-space with no root privileges and no need to install secondary apps like Termux.
- **Dual Agent Engine**:
  - **Built-in Native Dart Agent**: Instant startup, direct integration with Anthropic Claude, DeepSeek, Google Gemini, OpenAI, or custom OpenAI-compatible endpoints.
  - **Embedded PRoot Linux Subsystem**: Runs standard Debian-arm64 rootfs directly inside the app sandbox, enabling official `npm install -g @anthropic-ai/claude-code`, `aider`, and standard Node.js/Python/Git.
- **Unified Native GUI**:
  - Structured chat with interactive **Tool Approval Cards** (`Approve`, `Always Allow`, `Reject`).
  - Expandable **Reasoning / Thought Cards**.
  - Built-in **Diff Review Screen** with color-coded additions/deletions.
  - **Workspace File Explorer** to inspect project code on touch devices.
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
│   │   ├── agent/             # Abstract AgentEngine interface & event contracts
│   │   ├── builtin/           # BuiltinAgentEngine (LLM tool calling loop, Diff generation)
│   │   ├── proot/             # PRootManager (Debian-arm64 download, unpack & sandbox exec)
│   │   └── storage/           # KeyVault (Keystore encryption) & WorkspaceService (POSIX storage)
│   ├── l10n/                  # AppLocalizations & ARB translation files (zh, en)
│   ├── models/                # AgentEvent, ToolCallEvent, DiffEvent, ChatMessage
│   ├── ui/
│   │   ├── chat/              # Main Workbench: Chat bubbles, ThoughtCard, ToolApprovalCard
│   │   ├── diff/              # Native DiffViewerScreen
│   │   ├── explorer/          # WorkspaceExplorerScreen (file tree & viewer)
│   │   └── settings/          # Provider & Model Settings, Language Switcher, YOLO switch
│   └── main.dart              # App initialization & dark theme
└── android/                   # Android native manifest & permissions
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
