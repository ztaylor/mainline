# Troubleshooting

Start with `mainline doctor`. When a step fails, the CLI prints the relevant error lines and the path of the full log:
`<app>/build/logs/{gen,build,test,archive,export,upload,tester}.log` (`build-device`, `install`, `launch` for `run --device`).

- [Machine & simulator](#machine--simulator)
- [Project generation](#project-generation)
- [Tests](#tests)
- [API credentials](#api-credentials)
- [Signing](#signing)
- [Upload](#upload)
- [Processing & TestFlight](#processing--testflight)
- [App record](#app-record)
- [On a phone](#on-a-phone)
- [Crashes on device](#crashes-on-device)

---

## Machine & simulator

### "CoreSimulator is out of date" / "Unable to find a device matching the provided destination specifier"

```
CoreSimulator is out of date. Current version (1051.49.0) is older than build version (1171.7.0).
xcodebuild: error: Unable to find a device matching the provided destination specifier: { platform:iOS Simulator, id:… }
```

Xcode's first-launch system components aren't installed, which happens when Xcode was installed or updated and never opened.
You may also see `DVTPlugInLoading: Failed to load code for plug-in com.apple.dt.DVTCoreDeviceCore … Symbol not found`
or `Install Failed: Authorization is required to install the packages.` Fix (needs the admin password 🧑):

```sh
sudo xcodebuild -runFirstLaunch
xcodebuild -checkFirstLaunchStatus && echo ok
```

Repeat after every Xcode update.

### "no available iPhone simulator"

```sh
xcodebuild -downloadPlatform iOS
xcrun simctl list devices available | grep iPhone
```

To prefer a different device, set `SIMULATOR_NAME` in `~/.mainline/config.env`.

### Simulator acts strangely (stuck boot, stale app)

```sh
xcrun simctl shutdown all
xcrun simctl erase <udid>        # wipes that simulator
rm -rf <app>/build/DerivedData
```

### "cannot execute tool 'metal' due to missing Metal Toolchain"

Xcode 26+ ships the Metal shader compiler as a separate download. Apps with `.metal` files (custom
shaders) need it once per machine, no admin rights required:

```sh
xcodebuild -downloadComponent MetalToolchain   # ~840 MB
```

`mainline doctor` reports whether it's installed.

## Project generation

### "unexpanded ${VAR} in generated project"

`project.yml` references a variable that wasn't set. `gen` lists the missing names. Check that:
- the variable is set in the app's `app.env` or in `~/.mainline/config.env` (`mainline doctor` shows your settings),
- `app.env` is valid shell (quote values containing spaces: `DISPLAY_NAME="My App"`).

### Changes to the project don't show up

Edit `project.yml`, never the `.xcodeproj`. Every `build`/`test`/`run`/`ship` regenerates the project, so edits made in Xcode are lost.

## Tests

- The summary (`result / passed / failed`) and each failure message are printed. Full log: `<app>/build/logs/test.log`.
- Inspect the result bundle:

  ```sh
  xcrun xcresulttool get test-results summary --path <app>/build/TestResults.xcresult
  xcrun xcresulttool get test-results tests   --path <app>/build/TestResults.xcresult
  ```

- UI test can't find an element: check the `.accessibilityIdentifier`, give `waitForExistence(timeout:)` enough time, and make sure the app reads `-ui-testing` (fresh in-memory store) so leftover data doesn't interfere.
- Faster inner loop: `mainline test <app> --unit-only`.

## API credentials

`doctor` shows "API check failed", or any release command fails with HTTP 401/403:

| Symptom | Fix |
| --- | --- |
| `HTTP 401 NOT_AUTHORIZED` | Wrong `ASC_KEY_ID`/`ASC_ISSUER_ID` pair, wrong `.p8`, or the key was revoked. Recheck all three values on the API keys page. Make sure the Mac's clock is correct (tokens are time-limited). |
| `HTTP 403 FORBIDDEN_ERROR` | The key's role is too low. Use an **Admin** Team key. |
| `HTTP 403 FORBIDDEN.REQUIRED_AGREEMENTS_MISSING_OR_EXPIRED` | Apple published a new Program License Agreement and the team hasn't accepted it. The Account Holder accepts it at developer.apple.com/account (Agreements). It can take **a minute or two** to reach the API after acceptance, so retry before digging further. |
| `config error: API key file not found` | Fix `ASC_KEY_PATH` in `~/.mainline/credentials.env` |
| Issuer left empty by mistake | Empty `ASC_ISSUER_ID` means "Individual key". Fill it in for Team keys. |

Debug any call directly: `mainline asc api GET /v1/apps`.

## Signing

Signing errors show up in the export step (`<app>/build/logs/export.log`).

How mainline signs: `ship` **archives unsigned** (`CODE_SIGNING_ALLOWED=NO`) and signs during
`-exportArchive` with automatic signing, `-allowProvisioningUpdates` and the API key. Xcode then uses a
**Cloud Managed Apple Distribution** certificate (the private key never leaves Apple) and creates the App Store
provisioning profile itself. No keychain, no local certificates, no registered devices. That's why `ship`
works over SSH and in other headless sessions.

Why not sign at archive time? A signed archive uses a *development* identity. Xcode must then create a
development certificate whose private key goes in the login keychain, which is locked in SSH sessions
(`User interaction is not allowed`). It also needs a development profile, which requires a registered device
(`No profiles for '…' were found: … iOS App Development provisioning profiles`). We hit both on the first run.

| Error text (roughly) | Cause → fix |
| --- | --- |
| `User interaction is not allowed` (archive) | Something tried to sign at archive time and touched the locked keychain. Make sure the archive step still passes `CODE_SIGNING_ALLOWED=NO`. |
| `No Accounts` / `No account for team "XXXX"` | Auth flags not applied. Check that the credentials file loads (`mainline doctor`) and that `DEVELOPMENT_TEAM` matches the key's team. |
| `Cloud signing permission error` / `cannot create a Distribution certificate` / `You don't have permission to create…` | The key needs the **Admin** role. Make a new Admin Team key. |
| `No profiles for 'org.example.app' were found` | Usually the same Admin issue. Also confirm the bundle ID is registered: `mainline register <app>`. |
| `Your team has reached the maximum number of certificates` | Too many Apple Distribution certs. Revoke stale ones at developer.apple.com → Certificates, IDs & Profiles → Certificates. 🧑 |
| `Signing requires a development team` | `DEVELOPMENT_TEAM` isn't set. Run `mainline setup --team <TEAM_ID>`. |
| `Invalid authentication key credential` | Key ID / issuer / `.p8` mismatch (see [API credentials](#api-credentials)) |

## Upload

Upload errors are in `<app>/build/logs/upload.log` (from `xcrun altool --upload-package`).

| Error text (roughly) | Fix |
| --- | --- |
| `The bundle version must be higher than the previously uploaded version` / `Redundant Binary Upload` | Build-number collision. Re-run `mainline ship <app>`: it picks max + 1 from App Store Connect and from `~/.mainline/state/`. |
| `Invalid large app icon … can't be transparent or contain an alpha channel` | Re-render with `mainline icon <app>` (always opaque). Don't replace `AppIcon.png` with a transparent image. |
| `No suitable application records were found` | The app record is missing or has a different bundle ID. Run `mainline register <app>`. |
| `CFBundleShortVersionString … must be higher than …` / train closed | That version was already released on the App Store. Bump `MARKETING_VERSION` in `app.env`. |
| `Unable to authenticate` / 401 | See [API credentials](#api-credentials) |

## Processing & TestFlight

### `ship` exited 2 (timed out)

Apple is still processing; this is normal at busy times. **Don't re-upload.** Check:

```sh
mainline status <app>
```

`ship` waits `BUILD_WAIT_TIMEOUT` seconds (default 2700). Raise it in `~/.mainline/config.env` if this happens often.

### Build is `INVALID` / `FAILED`

Apple emails the account holder with the reason (missing Info.plist keys, invalid binary, …). Fix it, then ship again.

### `MISSING_EXPORT_COMPLIANCE`

The build is waiting for the encryption question. The template sets `ITSAppUsesNonExemptEncryption: false`
in `project.yml`, which is correct for apps that use only Apple's built-in HTTPS/TLS. If you removed it or your app
uses custom encryption, answer the question on the build's TestFlight page, or restore the key.

### Testers don't see the build

- Internal testers must be **users of the App Store Connect team**. On an individual account, that's the account holder's Apple ID.
- `tester add` failures are logged in `<app>/build/logs/tester.log` (as a warning; `ship` continues).
- Install from the **TestFlight** app on the device, signed in with the tester's Apple ID.

## App record

### `register`/`ship` exit 10

There's no app record for the bundle ID yet. Create it on the web: [web-steps.md](web-steps.md#create-the-app-record).

### "The app name you entered is already being used"

Store names are unique across the App Store. Pick a fallback (`Tally Counter`, `Tally by <name>`), update
`ASC_APP_NAME` in `app.env`, and create the record again. `DISPLAY_NAME` (home-screen name) can stay as is.

### Bundle ID missing from the New App dropdown

Run `mainline register <app>` (it registers the bundle ID), then reload the New App form.

## On a phone

`run --device` exits 11 when the phone needs a person, and prints the step. Once per phone: connect it to the Mac with
a cable, unlock it, tap **Trust**, then turn on **Settings → Privacy & Security → Developer Mode** (the phone
restarts). After that it also works over Wi-Fi on the same network, while the phone is unlocked.

Unlike `ship`, a phone build uses **development signing**: on first use, Xcode registers the phone with your team (it
counts toward the 100 iPhones a year a membership allows) and creates an Apple Development certificate, whose private
key goes in the login keychain. The build log is `<app>/build/logs/build-device.log`.

| Error text (roughly) | Cause → fix |
| --- | --- |
| `no phone is ready` / `… not reachable` | Connect the phone with a cable, or put it on the Mac's Wi-Fi network and unlock it. `xcrun devicectl list devices` shows what the Mac sees. 🧑 |
| `several phones are ready` | Pick one: `--device="Duke's iPhone"`, or set `DEVICE_NAME` in `~/.mainline/config.env`. |
| `Developer Mode is off` | Settings → Privacy & Security → Developer Mode, then restart the phone. 🧑 |
| `unlock the phone` | The phone is locked. Unlock it and run again. 🧑 |
| `User interaction is not allowed` / `errSecInteractionNotAllowed` (build-device) | The login keychain is locked, which is normal over SSH. Run once at the Mac, or `security unlock-keychain ~/Library/Keychains/login.keychain-db` in that session. 🧑 |
| `Your team has reached the maximum number of certificates` | Too many Apple Development certs. Revoke stale ones at developer.apple.com → Certificates, IDs & Profiles. 🧑 |
| `Cloud signing permission error` / `You don't have permission to create…` | The API key needs the **Admin** role to create certificates and register devices. |
| The app opens and closes at once | The launch arguments may be wrong, or it crashed. Run again with `--console` to see its output. |

## Crashes on device

Start with `mainline crashes <app>`. It downloads the crash reports testers shared from TestFlight and prints the
crashed thread's frames from your app. Trust those frames; the system-library symbols in TestFlight logs are often wrong.
To reproduce in the simulator, write a UI test for the same action. The simulator's own crash reports
(`~/Library/Logs/DiagnosticReports/<App>-*.ips`) are fully symbolicated.

### `EXC_BREAKPOINT` in `_dispatch_assert_queue_fail` / `swift_task_checkIsolated`

Swift 6's runtime actor check: a closure that is main-actor isolated ran on another queue. The usual cause is a
completion or change block passed to an Apple framework from inside a `@MainActor` class or a view. The closure inherits
main-actor isolation, and the framework calls it on a background queue. Make the closure nonisolated:

```swift
try await PHPhotoLibrary.shared().performChanges { @Sendable in      // not main-actor isolated
    let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject   // capture IDs, not objects
    ...
}
```

Tests on fake data won't catch it. Exercise the real framework call in a UI test. For PhotoKit, a test can favorite a
photo and then undo, or empty a bin and decline the system's delete confirmation: the change block has already run by then.
