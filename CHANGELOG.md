# Changelog

## 0.1.0 (2026-10-10)

The first release.

- `mainline`, a command-line tool that takes an iOS app from idea to TestFlight without the Xcode GUI.
  - **Set up:** `setup` saves your account settings and API key to `~/.mainline`; `doctor` checks the toolchain, the
    settings and a live API call; `init` makes a workspace; `new` creates an app from the template.
  - **Develop:** `build`, `test` (with `--unit-only` and `--only`), `run` (launches and screenshots, light or dark),
    `screenshots` (exports the screenshots UI tests attach), `icon`, and `gen`.
  - **Release:** `register`, and `ship`, which tests, archives unsigned, signs at export with Apple's cloud-managed
    certificate, uploads, sets up the TestFlight group and testers, and waits for processing. `status` shows builds,
    and `crashes` downloads TestFlight crash reports and prints the app's frames from each.
  - Apps can live anywhere, each as its own repo: run commands from inside the app's folder, or name it by path,
    by folder name (`./<name>` or `./apps/<name>` in a workspace), or by example name.
- `asc`, a dependency-free App Store Connect API client in Swift, and `appicon`, an icon renderer.
- An app template: SwiftUI, a Swift Testing unit-test target and an XCTest UI launch test, iOS 18 and later.
  The Tally example demonstrates SwiftData and launch arguments for tests and screenshots.
- `examples/tally`, a complete example app.
- The agent guide (`mainline guide`), with the steps, rules, exit codes and the SwiftUI and Swift 6 pitfalls we hit.
- A Claude Code plugin with a `ship-ios-app` skill.
- Docs: setup, playbook, agents, how it works, commands, web steps and troubleshooting.
- Safety and reliability:
  - The API helper sends tokens only to `api.appstoreconnect.apple.com`, refuses redirects, never replays a create
    after a server error, and fails rather than return a truncated list.
  - `ship` reports success only once the build is ready for internal testing, and stops if any release step fails.
  - Settings and app names are saved literally and readably (single quotes), settings files are private from
    creation, and every option is validated before anything runs.
  - `test` fails when no tests ran, so an empty target can't gate a release.
- Offline tests for the CLI and the API helper, run in CI with the example app and fresh apps from the template.
