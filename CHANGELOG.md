# Changelog

## Unreleased

- Quote settings and generated app names literally, validate missing option values and icon colors, and honor
  `setup --issuer ""`. Settings files are private from creation.
- Stop release registration immediately if bundle registration fails; select simulator runtimes numerically.
- Restrict authenticated API calls to Apple, reject redirects, retry mutations only on HTTP 429 (never on 5xx),
  and report incomplete pagination instead of returning partial results.
- Validate helper arguments before loading credentials. Return exit 78 for configuration errors. Require a ready
  internal TestFlight state before reporting success, and reject incompatible existing TestFlight groups.
- Validate icon-helper options and scale, provide `--help`, and distinguish rendering failures from usage errors.
- Add offline CLI and Swift API regression tests to CI. Replace the starter's always-passing unit test with guidance
  to add real model tests; retain its UI launch test. `mainline test` fails when no tests ran.
- `mainline new` and `setup` write names in single quotes, keeping `app.env` readable and its comments intact.
- `ship` exits 1, not 78, when the TestFlight group needs fixing after an upload.
- Clarify early-release scope, installation, trusted project configuration and concurrent-shipping limitations.

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
  - Apps can live anywhere, each as its own repo: run commands from inside the app's folder, or name it by path,
    by folder name (`./<name>` or `./apps/<name>` in a workspace), or by example name.
- `asc`, a dependency-free App Store Connect API client in Swift, and `appicon`, an icon renderer.
- An app template: SwiftUI, a Swift Testing unit-test target and an XCTest UI launch test, iOS 18 and later.
  The Tally example demonstrates SwiftData and launch arguments for tests and screenshots.
- `examples/tally`, a complete example app.
- The agent guide (`mainline guide`), with the steps, rules, exit codes and the SwiftUI and Swift 6 pitfalls we hit.
- A Claude Code plugin with a `ship-ios-app` skill.
- Docs: setup, playbook, agents, how it works, commands, web steps and troubleshooting.
