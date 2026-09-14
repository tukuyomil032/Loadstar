# Decision Ledger

## Active decision groups

| ADR | Group |
| --- | --- |
| 0001 | Product scope and parity |
| 0002 | Product identity and macOS platform |
| 0003 | Architecture and dependencies |
| 0004 | Settings, Guide, and Accessibility |
| 0005 | Persistence and security |
| 0006 | Server lifecycle and Java |
| 0007 | Files and editor |
| 0008 | Backup and destructive actions |
| 0009 | Plugins and artifact trust |
| 0010 | Users, network, and ngrok |
| 0011 | Console, dashboard, and notifications |
| 0012 | Proxy and forwarding |
| 0013 | Operations and automation |
| 0014 | App state and errors |
| 0015 | Release and distribution |
| 0016 | Tooling and CI |
| 0017 | Test, parity, and readiness |

## Fixed cross-cutting decisions

- LoadStar, macOS 26+, universal arm64/x86_64, bundle IDs com.tukuyomi032.loadstar and .debug.
- SwiftUI first, AppKit escape hatch, Swift 6 strict concurrency, eight SPM targets, Apple APIs first.
- Sparkle, Defaults, and STTextView are required; TourKit is not used.
- Fixed Application Support/LoadStar managed root, schema-versioned JSON, unknown-field retention, provenance, Keychain secrets, and checksum fail-closed.
- Process-group lifecycle, explicit EULA, running/SLP separation, transactional backup/restore, exact proxy matrix, compatible-only artifacts, native Settings, Main-only frame persistence, all-screen Accessibility.
- version.env, Stable/Beta, one Appcast, canonical DMG, Stable Homebrew cask, duplicate-release cancellation, and layered parity evidence.

When a detail changes, update the relevant active ADR and its canonical Phase file. Do not create a duplicate ADR for a detail that belongs to an existing group.
