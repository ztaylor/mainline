# Playbook: idea → TestFlight

The whole procedure, in order. You can follow it yourself, or let an agent follow its own version,
[the agent guide](agent-guide.md) (`mainline guide` prints it).

Before you start, [setup](setup.md) should be done and `mainline doctor` should pass. Steps 0 to 4 need only the
toolchain; you can build and test without an Apple account.

`<app>` below is the app's name or folder: `mainline` looks in `./<name>`, then `./apps/<name>`, and leaves out the
argument when you're inside the app's folder.

---

## 0. Turn the idea into a spec

Write one paragraph and a **small v1 feature list**, three to five items. For example:

> **Tally**: named counters for anything: glasses of water, push-ups, pages read. Tap a card to count up.
> v1: create a counter with a name and color · tap to count up, a button to count down (never below 0) ·
> press and hold to reset or delete · data survives relaunch · an empty state.

Rules of thumb for a v1:
- One or two screens. iPhone only (the template's default). No accounts, servers, payments or third-party packages.
- Local data with SwiftData, if it needs any.
- Everything else goes on a "later" list.

Choose the names now:

| Thing | Example | Notes |
| --- | --- | --- |
| slug | `tally` | lowercase letters, digits and hyphens; the folder name and the end of the bundle ID |
| display name | `Tally` | under the home-screen icon |
| store name | `Tally Counter` | `ASC_APP_NAME`: at most 30 characters and **unique across the whole App Store**, so have two fallbacks |
| icon | `plus.forwardslash.minus`, `#FF8A3D` → `#E5383B` | any [SF Symbol](https://developer.apple.com/sf-symbols/) on a two-color gradient, until you draw a real one |

The bundle ID becomes `<your prefix>.<slug>`, like `com.yourname.tally`, and is **permanent** once the app record exists.

## 1. Scaffold

To keep several apps together in one repo, make a workspace first. It adds an `apps/` folder, a `.gitignore`, and an
`AGENTS.md` that points agents at the guide:

```sh
mainline init my-apps && cd my-apps
```

Then create the app:

```sh
mainline new tally --name "Tally" --symbol plus.forwardslash.minus --from "#FF8A3D" --to "#E5383B"
```

This copies the template into `apps/tally/` (or `./tally/` outside a workspace), renders the icon and generates the
Xcode project. Edit `app.env` if the store name should differ from the display name.

```
tally/
├── app.env          names, bundle ID, version, store details, icon: the app's single source of truth
├── project.yml      the XcodeGen spec: targets, build settings, Info.plist keys
├── Sources/         TallyApp.swift, Models/, Views/
├── Tests/           Swift Testing unit tests
├── UITests/         XCTest UI tests
└── Resources/       the asset catalog (the icon PNG is generated)
```

**The icon.** Change `ICON_*` in `app.env` and run `mainline icon tally`. For a real brand, draw the mark in SwiftUI
(no UIKit or AppKit types, so it compiles for macOS too) and set `ICON_SCRIPT` to a script that renders it to a
1024×1024 PNG without an alpha channel. A small macOS Swift script using `ImageRenderer` does it. mainline runs the
script and checks the result.

## 2. Implement

Write SwiftUI in `Sources/` (the example in `examples/tally` is complete):

- `Sources/<App>App.swift`: the `@main` entry point. Set up the SwiftData `ModelContainer` here.
- `Sources/Models/`: `@Model` types and plain logic. Keeping logic here keeps it testable.
- `Sources/Views/`: one view per file, with a `#Preview` each.
- **Launch arguments**, handled in the app's `init`:
  - `-ui-testing`: an in-memory store, so every UI test starts fresh.
  - `-seed-sample-data`: an in-memory store with realistic demo data, for screenshots.
- **Accessibility identifiers** on everything a UI test touches: `.accessibilityIdentifier("addCounter")`.
  Keep the root view's identifier `home`; the template's smoke test looks for it.
- Build settings, Info.plist keys and targets go in `project.yml`; names, version and bundle ID in `app.env`.
  **Never edit the `.xcodeproj`.** Every command regenerates it.

Compile while you work:

```sh
mainline build tally
```

## 3. Test

- Unit tests in `Tests/` with **Swift Testing** (`import Testing`, `@Test`, `#expect`) for the model logic and edge cases.
- At least **one UI test** in `UITests/` (XCTest) that drives the main feature end to end, launched with `-ui-testing`.

```sh
mainline test tally                                         # unit and UI tests
mainline test tally --unit-only                             # a faster loop
mainline test tally --only TallyUITests/TallyUITests        # one class (or Class/method)
```

It prints the result, the counts and every failure. The full log is `tally/build/logs/test.log`, and the result bundle
is `tally/build/TestResults.xcresult`.

## 4. Look at it

```sh
mainline run tally -- -seed-sample-data          # light mode
mainline run tally --dark -- -seed-sample-data   # dark mode
```

The last line is the screenshot's path. **Open it** and check layout, truncation, contrast, empty states and dark mode.
Options: `--wait N` (seconds before the screenshot, default 3), `--show` (open Simulator.app), `--no-screenshot`.

**Screens behind taps.** Give the app hooks such as `-tab <name>` to open a tab and `-open <screen>` to present a
sheet, and pass them after `--`. For scrolled or multi-step screens, write a "screenshot tour" UI test that attaches
named screenshots:

```swift
let shot = XCTAttachment(screenshot: app.screenshot())
shot.name = "settings-scrolled"
shot.lifetime = .keepAlways
add(shot)
```

Run `mainline test tally`, then `mainline screenshots tally` to export them as PNGs.

Repeat steps 2 to 4 until the v1 list is done and the screenshots look right.

## 5. Register with App Store Connect

```sh
mainline register tally
```

This registers the bundle ID (safe to repeat) and looks up the app's **App Store Connect record**:

- **Found:** `✓ ready to ship`, exit 0.
- **Missing:** it prints the exact form values and exits **10**. Apple's API can't create app records, so create it once
  on the web ([web steps](web-steps.md#create-the-app-record)); an agent with your browser can do it. If the store name is
  taken, choose a fallback, update `ASC_APP_NAME` and try again.

Run `register` again until it exits 0.

## 6. Ship

```sh
mainline ship tally
```

It takes 5 to 25 minutes, mostly Apple's processing:

1. Checks the bundle ID and the app record (exit 10 if the record is missing).
2. Runs the full test suite. **Failing tests stop the upload.**
3. Chooses the build number: one more than the highest on App Store Connect.
4. Archives an **unsigned** Release build.
5. Exports a signed `.ipa` with Apple's cloud-managed distribution certificate. The provisioning profile is created
   for you, and no keychain is involved ([how it works](how-it-works.md#2-signing-without-certificates)).
6. Uploads it with `altool`.
7. Creates or reuses the internal TestFlight group (`TESTFLIGHT_GROUP`, default `Internal`), which gets every build,
   and adds your testers.
8. Waits until Apple has processed the build (up to `BUILD_WAIT_TIMEOUT`, 45 minutes by default).

```
==> Shipped Tally 1.0.0 (1) in 4m49s
    TestFlight: https://appstoreconnect.apple.com/apps/6740000000/testflight/ios
```

Options: `--skip-tests` (emergencies only) and `--no-wait` (return right after the upload). A timeout (exit 2) usually
just means Apple is slow: check with `status`, and don't upload again.

## 7. Install it

```sh
mainline status tally
```

```
VERSION   BUILD  PROCESSING  TESTFLIGHT (internal)        UPLOADED
1.0.0     1      VALID       IN_BETA_TESTING              2026-10-10T08:12:44-07:00
```

`VALID`, with `READY_FOR_BETA_TESTING` or `IN_BETA_TESTING`, means it's ready: open the **TestFlight** app on your
iPhone and install it. Internal testers must be users of your App Store Connect team; on an individual account, that's you.

---

## Shipping an update

1. Make the change. `mainline test`, `mainline run`, and look at the screenshot.
2. **Bump `MARKETING_VERSION`** in `app.env` only for a new user-facing release (`1.0.0` → `1.1.0`). For more TestFlight
   builds of the same version, leave it alone; build numbers go up by themselves.
3. `mainline ship tally`. Your testers get the new build.

**A crash report from a tester?** `mainline crashes tally` downloads the reports testers shared from TestFlight and prints
each one's comment, exception and the crashed thread's frames from your app. Reproduce it in a test, fix it, and ship
again ([troubleshooting](troubleshooting.md#crashes-on-device)).

## Definition of done

- [ ] Spec and v1 list written; "later" ideas parked
- [ ] Names, store name and icon final; screenshots reviewed in light **and** dark mode
- [ ] Model logic covered by unit tests, at least one UI flow test, and `mainline test` green
- [ ] Empty states and edge cases (long names, zero, big numbers) checked on screen
- [ ] `mainline register` exits 0
- [ ] `mainline ship` finished with "Shipped …"
- [ ] The build installs from TestFlight
- [ ] Changes committed, with no secrets, no `build/` and no `.xcodeproj`
