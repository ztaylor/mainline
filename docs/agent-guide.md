# mainline: the agent guide

You're an AI agent, and someone asked you to build an iOS app, change one, or ship one to TestFlight.
`mainline` does every step from the command line: scaffold, build, test, screenshot, sign, upload, TestFlight.
You write the Swift, run the commands, look at the screenshots, and fix what you see. The human only does what needs
their identity: passwords, 2FA, payments, legal agreements, and the names that become permanent.

Run `mainline help` for every command and its options. The human-facing version of this guide is the [playbook](playbook.md).

## Rules

1. **Never open or edit an `.xcodeproj`.** It's generated. Change the app's `project.yml` (targets, build settings,
   Info.plist keys, packages) or `app.env` (names, bundle ID, version, icon). Every command regenerates the project.
2. **Never print, copy or commit secrets.** Credentials live in `~/.mainline/` (`credentials.env`, `AuthKey_*.p8`).
   Don't read those files into the conversation, and don't copy them into a repo, a log or a message.
3. **Tests gate everything.** Run `mainline test <app>` and fix failures before shipping. `ship` runs the tests itself.
   Use `--skip-tests` only when the human explicitly asks.
4. **Look at the app with your own eyes.** `mainline run <app> -- -seed-sample-data` prints a screenshot path. Read
   the image, and check it in dark mode with `--dark`. Iterate until it looks right. Compiling isn't the same as working.
5. **Keep v1 small:** one or two screens, local data, no accounts or servers, no third-party packages unless asked.
6. **Ask the human only for** `sudo` passwords, 2FA codes, payments, legal agreements, and naming decisions:
   confirm the store name and permanent bundle ID. Decide everything else yourself and say what you chose.
7. **Don't change `BUNDLE_ID`** once the app record exists. Don't bump `MARKETING_VERSION` unless it's a new
   user-facing release; build numbers are automatic.

## The steps

### 0. Preflight

Run `mainline doctor`. Toolchain problems are fixed in [setup](setup.md); hand `sudo` steps to the human. Missing
Apple credentials block only steps 5 and 6, so you can build and test without them. If the bundle prefix isn't set,
ask the human what it should be (it's usually their reverse domain, like `com.theirname`), then run `mainline setup --prefix <it>`.

### 1. Spec and scaffold

- Turn the idea into a one-paragraph spec and a v1 list of 3 to 5 features. Park everything else under "later".
- Choose a slug (`habit-streaks`), a display name, a store name (≤30 characters, unique across the whole App Store;
  have two fallbacks ready), an SF Symbol and two hex colors for the starter icon. Confirm names with the human if they
  haven't given them.
- `mainline new <slug> --name "<Name>" --symbol <sf.symbol> --from "#RRGGBB" --to "#RRGGBB"`. It creates `./<slug>`, a
  self-contained folder that can be its own repo, or `apps/<slug>` inside a workspace. Inside the app's folder, commands
  need no app name (`mainline test`, `mainline ship`).
- Set `ASC_APP_NAME` in `app.env` if the store name differs from the display name.

### 2. Implement

- SwiftUI in `Sources/`: `<App>App.swift` for the entry point and the SwiftData `ModelContainer`, `Models/` for logic
  (keep it unit-testable), `Views/` with one view per file and a `#Preview` each.
- Handle these launch arguments in the app's `init`:
  - `-ui-testing`: an in-memory store, so every UI test starts fresh.
  - `-seed-sample-data`: an in-memory store filled with realistic demo data, for screenshots.
- Put `.accessibilityIdentifier(…)` on every control a UI test touches. The root view keeps the identifier `home`.
- Compile with `mainline build <app>` while you work.

### 3. Test

- Unit tests with Swift Testing (`import Testing`, `@Test`, `#expect`) for the model logic and its edge cases.
- At least one XCTest UI test that drives the main feature end to end, launched with `-ui-testing`.
- `mainline test <app>` must pass, and a run with no tests fails. The starter has only a UI launch test, so add
  unit tests before you use `--unit-only`. Use `--unit-only` for a quick loop and `--only <Target/Class[/method]>` for one test.
  It prints each failure; the full log is in `<app>/build/logs/test.log`.

### 4. Look at it

- `mainline run <app> -- -seed-sample-data`, then `mainline run <app> --dark -- -seed-sample-data`. Read each image.
- Fix layout, truncation, contrast, empty states and dark mode. Repeat steps 2 to 4 until it's right.
- For a screen behind a tap, add launch hooks (`-tab <name>`, `-open <screen>`) and pass them after `--`.
- For scrolled or multi-step screens, write a "screenshot tour" UI test that attaches named screenshots
  (`XCTAttachment(screenshot:)` with `lifetime = .keepAlways`), run `mainline test <app>`, then
  `mainline screenshots <app>` and read the PNGs it lists.
- `--console` (simulator or phone) stays attached and prints the app's `print` output, for debugging. It blocks until
  the app exits, so run it in the background or stop it yourself.
- **On the human's phone:** `mainline run <app> --device -- -seed-sample-data` installs, launches and screenshots on a
  connected iPhone. Use it for what the simulator fakes (camera, location, haptics, the real photo library,
  performance), and when the human asks to try it on their phone. **Exit 11** means the phone needs the human:
  relay the printed step (connect and tap Trust, turn on Developer Mode, unlock it) and run again. The screenshot is
  of their real phone, so it can show their notifications and status bar; don't share it beyond the human.

### 5. Register

- `mainline register <app>` registers the bundle ID and checks for the App Store Connect app record.
- **Exit 10** means the record is missing. Apple's API can't create it, so it's a one-time web form, and the command
  printed every value. If you can drive a browser, fill it in following [web steps](web-steps.md#create-the-app-record).
  Otherwise give the human the values and the link, and wait. If the store name is taken, use a fallback and update
  `ASC_APP_NAME`.
- Run `register` again until it exits 0.

### 6. Ship

- `mainline ship <app>`. It takes 5 to 25 minutes, mostly Apple's processing. It tests, archives, signs in the cloud,
  uploads, adds the TestFlight group and testers, and waits until the build can be installed.
- On exit 1, read the error lines it printed, then `<app>/build/logs/`, then [troubleshooting](troubleshooting.md).
  If upload already succeeded, check `mainline status <app>` and resolve the reported TestFlight or compliance issue
  before uploading again. Run only one `ship` per app at a time.

### 7. Report

- Tell the human the version and build number, the TestFlight link that `ship` printed, and "install it from the
  TestFlight app". `mainline status <app>` shows the build's state.
- If the human wants commits: commit the app, but never `build/`, the `.xcodeproj` or anything from `~/.mainline`.

## Exit codes

| Code | Meaning | What to do |
| --- | --- | --- |
| 0 | ok | |
| 1 | failure | Read the printed error lines, then the log, then [troubleshooting](troubleshooting.md). |
| 2 | Apple's processing timed out | Run `mainline status <app>` later. **Don't upload again.** |
| 3 | not found (`status`) | `mainline register <app>` |
| 10 | app record missing | The web step in step 5. |
| 11 | phone not ready (`run --device`) | Relay the printed step to the human, then run again. |
| 64 | usage error | Fix the arguments (`mainline help`). |
| 78 | not set up | `mainline doctor`, then [setup](setup.md). |

## Updates and crashes

- Change, `test`, `run` and look, then `ship`. Bump `MARKETING_VERSION` in `app.env` only for a new user-facing release.
- A tester reported a crash? `mainline crashes <app>` downloads TestFlight's crash reports and prints the tester's
  comment and the crashed thread's frames from the app. Trust the app's frames; TestFlight often mislabels system
  frames. Reproduce the crash in a test before you fix it, then ship again.

## Make it good, not just working

- **Brand from the first build.** Pick a palette and a type treatment and put them in one file (`Sources/Brand/`).
  For a real icon, draw it in SwiftUI with no UIKit or AppKit types, and point `ICON_SCRIPT` in `app.env` at a script
  that renders that view to a 1024×1024 PNG with no alpha channel (`ImageRenderer` in a small macOS Swift script works).
  Render it, look at it, and iterate.
- **Data the user owns** (photos, contacts, health) goes behind a provider protocol with two implementations: the real
  framework, and a deterministic demo used by UI tests and screenshots. Test the real one too (see the pitfalls).
- **Seed data sells the screenshot.** `-seed-sample-data` should look like a real person's month with the app, not "Item 1".
- **Charts:** prefer one hue over a rainbow, label directly, and check colors for color-blind safety.

## Pitfalls we've hit (save yourself the debugging)

**Swift 6 concurrency**
- **Closures handed to a framework that calls back on its own queue must not be main-actor isolated.** Written inside a
  `@MainActor` type or a view they are by default, and Swift 6 traps at runtime (`EXC_BREAKPOINT` in
  `_dispatch_assert_queue_fail` / `swift_task_checkIsolated`). This bites `PHPhotoLibrary.performChanges`,
  `PHAssetResourceManager` and `PHImageManager` callbacks, and similar AVFoundation, CoreLocation and `NotificationCenter`
  handlers. Mark them `{ @Sendable in … }` and capture only Sendable values (IDs, not `PHAsset`s). Demo-data tests can't
  catch it, so write a UI test that does the real framework write.
- **Don't run blocking work in parallel on the cooperative thread pool.** Dozens of `Task.detached` Vision requests or
  pixel loops starve it and the app hangs. Funnel the work through one serial `DispatchQueue` behind
  `withCheckedContinuation`, and start it lazily (inside a `LazyVStack`, or `.task` on the visible row).

**SwiftUI**
- `.clipped()` clips drawing, **not hit-testing**. An aspect-filled image that overflows its frame silently swallows
  taps on the buttons next to it. Give display-only images `.allowsHitTesting(false)` and the container
  `.contentShape(Rectangle())`. Images rendered at exact size (like demo art) hide this bug; test with real photos.
- An `.accessibilityIdentifier` on a container **overrides its children's identifiers**. Put identifiers on leaf controls.
- Don't mix `NavigationLink(value:)` and `.navigationDestination` inside a screen that was itself pushed with a
  view-based `NavigationLink { … }`. Taps silently do nothing. Use view-destination links there.
- `@Query` results update synchronously after `context.insert`. Read counts *before* you insert.
- Mutating a `@State` object inside `App.init` doesn't reach the installed instance. Build it, then `_x = State(initialValue: x)`.

**Tests and the simulator**
- In unit tests, keep the `ModelContainer` alive as long as its `mainContext` is in use, or SwiftData crashes.
- `xcrun simctl privacy … grant photos` doesn't authorize PhotoKit on recent iOS. Have the UI test tap the system prompt:
  `XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Allow Full Access"]`. Reinstalling resets the grant.
- System sheets have their own identifiers. The share sheet is `app.otherElements["ActivityListView"]`, closed with
  `app.buttons["header.closeButton"]`. Delete confirmations from Photos are springboard alerts.
- The simulator can't encode HEIC. Use another format in tests that write images.
- Map tiles load slowly in the simulator. Give them 15 to 20 seconds (`mainline run <app> --wait 20`) and judge maps
  from wider shots.

**Toolchain**
- `.metal` files need the Metal toolchain: `xcodebuild -downloadComponent MetalToolchain`, once per machine. `doctor` checks.
- A type-checker timeout on a big literal (a catalog of 40 structs) goes away when you split it into several `static let`s.
