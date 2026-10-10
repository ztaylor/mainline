# Changelog

## 0.1.0

The first release.

- `mainline`, a command-line tool that takes an iOS app from idea to TestFlight without the Xcode GUI.
  - **Set up:** `setup` saves your account settings and API key to `~/.mainline`; `doctor` checks the toolchain, the
    settings and a live API call; `init` makes a workspace; `new` creates an app from the template.
  - **Develop:** `build`, `test` (with `--unit-only` and `--only`), `run` (launches and screenshots, light or dark),
    `screenshots` (exports the screenshots UI tests attach), `icon`, and `gen`.
  - **Release:** `register`, and `ship`, which tests, archives unsigned, signs at export with Apple's cloud-managed
    certificate, uploads, sets up the TestFlight group and testers, and waits for processing. `status` shows builds,
    and `crashes` downloads TestFlight crash reports and prints the app's frames from each.
  - Apps can live anywhere: a path, the current folder, `./apps/<name>`, or the bundled examples by name.
- `asc`, a dependency-free App Store Connect API client in Swift, and `appicon`, an icon renderer.
- An app template: SwiftUI, SwiftData, Swift Testing unit tests, XCTest UI tests, launch arguments for tests and
  screenshots, iOS 18 and later.
- `examples/tally`, a complete example app.
- The agent guide (`mainline guide`), with the steps, rules, exit codes and the SwiftUI and Swift 6 pitfalls we hit.
- A Claude Code plugin with a `ship-ios-app` skill.
- Docs: setup, playbook, agents, how it works, commands, web steps and troubleshooting.
