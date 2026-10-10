---
name: ship-ios-app
description: Build an iOS app from an idea, change one, or ship it to TestFlight with the mainline CLI, without opening Xcode. Use when the user wants a new iPhone app, wants to test, screenshot or ship an existing mainline app (a folder with app.env), or asks about TestFlight builds or crash reports.
---

# Ship an iOS app with mainline

mainline is a command-line tool that takes iOS apps from idea to TestFlight: scaffold, build, test, screenshot,
cloud signing, upload, TestFlight, crash reports. The playbook ships with the tool, so it always matches the
installed version.

1. Check that it's installed: `command -v mainline || ls ~/mainline/bin/mainline`.
   - If it's missing, tell the user and offer to install it (it needs Homebrew and a Mac with Xcode):
     ```sh
     brew install xcodegen jq
     git clone https://github.com/ztaylor/mainline ~/mainline
     export PATH="$HOME/mainline/bin:$PATH"  # persist in ~/.zshrc for later sessions
     ```
     Setup steps that need the user (Xcode, `sudo`, their Apple account): https://github.com/ztaylor/mainline/blob/main/docs/setup.md
2. Run `mainline guide` and follow it. It has the steps in order, the rules (never edit the `.xcodeproj`, never read
   `~/.mainline`, tests gate shipping, look at every screenshot), the exit codes, when to ask the user, and the
   SwiftUI and Swift 6 pitfalls to avoid.
3. Run `mainline doctor` before you start, and `mainline help` for every command.
