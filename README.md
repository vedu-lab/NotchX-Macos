# NotchX

**The Definitive MacBook Notch Overlay & Dynamic Dynamic Island for macOS**

[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)](https://apple.com/macos)
[![Apple Silicon](https://img.shields.io/badge/Architecture-Apple%20Silicon%20(arm64)-black)](https://apple.com)
[![License: Proprietary](https://img.shields.io/badge/License-Proprietary%20All%20Rights%20Reserved-red)](LICENSE)
[![Security: Hardened](https://img.shields.io/badge/Security-Hardened%20Runtime%20%2B%20Anti--Tamper-success)](NotchX.entitlements)

NotchX transforms your MacBook's camera notch into an ultra-luxurious, interactive command center featuring live audio routing, per-app volume sliders, zero-latency aural haptics, multi-source media controls, a 21-day scrollable calendar, and a drag-and-drop file shelf.

---

## ⚡ 1-Click Installation & Launch for Anyone

NotchX is distributed as a self-contained, pre-packaged universal release with **zero developer tools or terminal commands required**.

### Installing from DMG:
1. Download **`NotchX.dmg`**.
2. Double-click **`NotchX.dmg`** to open the installer disk image.
3. Drag **`NotchX.app`** into the **Applications** folder shortcut.
4. **First Launch**:
   - Double-click **`Open NotchX.command`** inside the DMG for an **instant 1-click launch** (automatically bypasses Gatekeeper quarantine), OR
   - Right-click `NotchX.app` in Applications $\to$ Select **Open** $\to$ Click **Open**.
5. NotchX starts seamlessly in your menu bar (look for the **NX** icon) and hugs your MacBook notch!

---

## 🛡️ Security Architecture & Anti-Tamper Protection

NotchX is engineered with enterprise-grade defenses against cracking, memory tampering, and unauthorized reverse engineering:

1. **Kernel-Level Anti-Debugging (`PT_DENY_ATTACH`)**:
   Blocks external debuggers (LLDB, GDB, Frida, Hopper) at the Darwin kernel level from attaching to the process or inspecting memory.
2. **Dynamic Library Injection Defense**:
   Blocks `DYLD_INSERT_LIBRARIES` and unauthorized library hijacking via Apple Hardened Runtime and proactive environment scans.
3. **Cryptographic Code-Signature Self-Check**:
   Validates Mach-O binary integrity on disk via Apple `Security.framework` (`SecCodeCheckValidity`) to detect unauthorized hex edits or patching.
4. **Runtime Integrity Watchdog**:
   A dedicated background sentinel monitors process tracing and thread state continuously.
5. **Hardened Runtime Entitlements**:
   Strictly forbids unsigned executable memory (`allow-unsigned-executable-memory: false`) and disables task debugging (`get-task-allow: false`).

---

## 💎 Features Overview

- **Aural Haptics Engine**: In-memory synthesized 44.1kHz acoustic cues (.tock, .whoosh, .mechanicalClick, .sparkleTick, .completionChime) coupled with Force Touch trackpad haptics.
- **Audio Routing & Per-App Volume**: 1-click output switching between MacBook speakers, AirPods, and external displays, with individual volume sliders for Spotify, Zoom, Chrome, etc.
- **Microphone Privacy Veil**: Hardware-styled active microphone LED indicator with a 1-click global kill switch.
- **File Shelf**: Drag and drop any file or photo into the notch to hold it temporarily while switching apps.
- **Interactive Calendar**: 21-day horizontal scrollable calendar strip with macOS Calendar event synchronization.
- **Shortcuts & Macro Engine**: Quick-launch apps, web bookmarks, system toggles, and record custom AppleScript workflows.
- **Dynamic HUD**: Real-time sparkling visual overlays for volume and screen brightness adjustments.
- **Dynamic Wallpapers**: Flowing gradients, floating particle fields, and aurora borealis.

---

## 📄 Legal, Copyright & License

Copyright © 2026 Vedant. All Rights Reserved.

The NotchX application, its source code, compiled binaries, documentation, sound designs, user interface layouts, and the "NX" logo are the proprietary intellectual property of Vedant. Unauthorized decompilation, reverse engineering, redistribution, or resale is strictly prohibited. See [LICENSE](LICENSE) and [COPYRIGHT](COPYRIGHT) for full terms.
