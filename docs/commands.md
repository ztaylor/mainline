# Command reference

- [Commands](#commands)
- [Finding an app](#finding-an-app)
- [Exit codes](#exit-codes)
- [Configuration](#configuration)
- [Files and output](#files-and-output)
- [Build numbers](#build-numbers)
- [The `asc` helper](#the-asc-helper)
- [The `appicon` helper](#the-appicon-helper)

Progress goes to **stderr**. The few machine-readable results (a screenshot path, an ID) go to **stdout**, so
`path=$(mainline run tally)` works.

## Commands

### Set up

| Command | What it does |
| --- | --- |
| `setup [--team ID] [--prefix com.you] [--tester EMAIL] [--key FILE.p8] [--key-id ID] [--issuer UUID]` | Saves your account settings to `~/.mainline/config.env` and your API key to `~/.mainline/credentials.env`, copying the `.p8` into `~/.mainline` with mode 600. `--tester` can repeat. The key ID is read from the file name (`AuthKey_<ID>.p8`) unless you give it. With no options in a terminal, it asks for each value. Ends by running `doctor`. |
| `doctor` | Checks Xcode and its first-launch components, the Metal toolchain, xcodegen, jq, altool, the helper tools, a simulator, your settings, the credentials file and its permissions, and a live API call. Exits 1 if anything required is missing. |
| `init [dir]` | Makes a workspace for your apps: `apps/`, a `.gitignore`, an `AGENTS.md` (and a `CLAUDE.md` that includes it) pointing agents at `mainline guide`, and a README. Never overwrites existing files. |
| `new <slug> [--name "Name"] [--symbol sf.symbol] [--from #hex] [--to #hex] [--dir DIR]` | Copies the template into `./apps/<slug>` (if `./apps` exists) or `./<slug>`, or into `DIR`. Fills in the names, renders the icon and generates the project. The slug matches `^[a-z][a-z0-9-]*$`. `--name` defaults to the title-cased slug (`habit-streaks` → `Habit Streaks`); the Swift target is the name without spaces or punctuation (`HabitStreaks`). The bundle ID is `BUNDLE_PREFIX.<slug>`. |
| `list` | Each app in `./` and `./apps/`: folder, bundle ID, version, path. |
| `guide` | Prints the [agent guide](agent-guide.md), with links made absolute so they work from any folder. |
| `version` | Prints mainline's version. |

### Develop (simulator; no Apple account needed)

| Command | What it does |
| --- | --- |
| `gen <app>` | Runs XcodeGen on `project.yml` with your settings and `app.env` exported for `${VAR}` expansion. Renders the icon if it's missing. Fails if any `${VAR}` is left unexpanded. Every command below runs `gen` first. |
| `icon <app>` | Renders `Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` (1024×1024, no alpha) from `ICON_SYMBOL` or `ICON_TEXT` on an `ICON_FROM` → `ICON_TO` gradient. If `ICON_SCRIPT` is set, runs that instead and rejects output with an alpha channel. Sets the accent color to `ICON_FROM`. |
| `build <app>` | A Debug build for the simulator. |
| `test <app> [--unit-only] [--only <id>]` | Runs `xcodebuild test` on the simulator (parallel testing off), then prints a summary and each failure. `--unit-only` runs only the `<App>Tests` target. `--only <Target/Class[/method]>` runs just those tests and can repeat. |
| `run <app> [--wait N] [--dark] [--show] [--no-screenshot] [-- <launch args>]` | Builds, boots the simulator, sets a clean status bar (9:41, full battery) and the appearance, installs, launches with the launch arguments, waits `N` seconds (default 3), and saves a screenshot. Prints the screenshot's path. `--show` opens Simulator.app. |
| `screenshots <app>` | Exports the screenshots that UI tests attached (`XCTAttachment`, named, `.keepAlways`) in the last `test` run to `<app>/build/screenshots/tests/<name>.png`, and prints their paths. |

### Release (needs `setup`)

| Command | What it does |
| --- | --- |
| `register <app>` | Registers the bundle ID if it's missing, and looks up the app record. Exit 10 means the record is missing; the web form's values are printed. |
| `ship <app> [--skip-tests] [--no-wait]` | Checks registration → `test` (unless `--skip-tests`) → chooses the build number → archives unsigned → exports a cloud-signed `.ipa` → uploads with `altool` → sets up the TestFlight group and testers → waits for processing (unless `--no-wait`). |
| `status <app> [N]` | The last `N` builds (default 10): version, build number, processing state, internal TestFlight state, upload date. Prints the TestFlight URL. |
| `crashes <app> [N]` | Downloads the last `N` (default 10) crash reports that testers shared from TestFlight to `<app>/build/crashes/`, and prints each one's tester comment, exception, and the crashed thread's frames from the app's binary. |
| `asc <args>` | Runs the [`asc` helper](#the-asc-helper) with your credentials loaded. |

## Finding an app

`<app>` can be:

- **a path** containing a `/` (`./tally`, `~/code/tally`, `apps/tally`), or `.`;
- **a name**, looked up in `./<name>`, `./apps/<name>`, `$MAINLINE_APPS/<name>`, then mainline's own `examples/<name>`;
- **nothing**, meaning the current folder.

An app is any folder with an `app.env`. Its build output goes in its own `build/` folder.

## Exit codes

| Code | Meaning | What to do |
| --- | --- | --- |
| 0 | Success | |
| 1 | Failure: build, test, signing, upload or API error, or `doctor` found problems | Read the printed error lines and `<app>/build/logs/<step>.log` |
| 2 | Timed out waiting for App Store Connect to process the build | Usually fine: `mainline status <app>` later. Don't upload again. |
| 3 | App record not found (`status`, `crashes`) | `mainline register <app>` |
| 10 | App record missing (`register`, `ship`) | Create it on the web: [web steps](web-steps.md#create-the-app-record) |
| 64 | Usage error: bad arguments, unknown app | `mainline help` |
| 78 | Not set up: credentials or `DEVELOPMENT_TEAM` missing | `mainline doctor`, then [setup](setup.md) |

## Configuration

Settings are shell variables, loaded in this order. Later files win.

1. `config/defaults.env` in mainline: the defaults below.
2. `~/.mainline/config.env`: your settings, written by `mainline setup`.
3. `~/.mainline/credentials.env`: your API key.
4. The app's `app.env`: the app's metadata, and any per-app overrides.

### Settings

| Variable | Default | Meaning |
| --- | --- | --- |
| `BUNDLE_PREFIX` | *(none)* | Reverse-DNS prefix you control. New apps get `BUNDLE_PREFIX.<slug>`. Required by `new`. |
| `DEVELOPMENT_TEAM` | *(none)* | Your 10-character Apple Team ID. Required by `ship`. |
| `TESTER_EMAILS` | *(none)* | Comma-separated. Internal testers must be users of your App Store Connect team. |
| `TESTFLIGHT_GROUP` | `Internal` | The internal TestFlight group created on the first ship, with access to every build |
| `SIMULATOR_NAME` | `iPhone 17 Pro` | Preferred simulator, on the newest runtime. Falls back to any iPhone. |
| `BUILD_WAIT_TIMEOUT` | `2700` | Seconds `ship` waits for processing |

### Credentials

| Variable | Meaning |
| --- | --- |
| `ASC_KEY_ID` | The API key's ID |
| `ASC_ISSUER_ID` | The issuer UUID for Team keys. Empty means an Individual key. |
| `ASC_KEY_PATH` | Path to `AuthKey_<ID>.p8`. A leading `~` is expanded. |

### Environment

| Variable | Default | Meaning |
| --- | --- | --- |
| `MAINLINE_HOME` | `~/.mainline` | Where settings, credentials and state live |
| `MAINLINE_CONFIG` | `$MAINLINE_HOME/config.env` | Your settings file |
| `MAINLINE_CREDENTIALS` | `$MAINLINE_HOME/credentials.env` | Your credentials file |
| `MAINLINE_APPS` | *(none)* | An extra folder to look for apps by name |

### `app.env`

| Variable | Meaning |
| --- | --- |
| `APP_NAME` | Xcode target and scheme name (a Swift identifier) |
| `DISPLAY_NAME` | The home-screen name (`CFBundleDisplayName`) |
| `BUNDLE_ID` | The bundle identifier. Permanent once the app record exists. |
| `MARKETING_VERSION` | The user-facing version (`CFBundleShortVersionString`). Bump it for each new release. |
| `ASC_APP_NAME` | The App Store name for the app record: at most 30 characters, unique across the App Store |
| `SKU` | A private App Store Connect identifier |
| `PRIMARY_LOCALE` | For example `en-US` (shown in the app record's form values) |
| `ICON_SYMBOL` / `ICON_TEXT` | The icon's glyph: an SF Symbol name, or text (`ICON_TEXT` wins if set) |
| `ICON_FROM` / `ICON_TO` | Gradient colors (`#RRGGBB`). `ICON_FROM` is also the accent color. |
| `ICON_SCRIPT` | Optional. An executable in the app's folder that renders custom artwork, run as `<script> <out.png>`. |

Any setting above can also be overridden per app in `app.env`. `project.yml` reads `${MARKETING_VERSION}`,
`${DEVELOPMENT_TEAM}`, `${DISPLAY_NAME}` and `${BUNDLE_ID}`, and can read any other variable you add.

Template defaults in `project.yml`: iOS 18.0 deployment target, Swift 6, iPhone only (`TARGETED_DEVICE_FAMILY: "1"`),
portrait, automatic signing, and `ITSAppUsesNonExemptEncryption: false`, which answers TestFlight's export-compliance
question for apps that use only Apple's built-in encryption.

## Files and output

```
<app>/
├── app.env                    metadata: the source of truth
├── project.yml                the XcodeGen spec
├── Sources/                   app code (Models/ and Views/ by convention)
├── Resources/Assets.xcassets  AppIcon (a generated PNG) and AccentColor (generated)
├── Tests/                     <App>Tests: Swift Testing unit tests
├── UITests/                   <App>UITests: XCTest UI tests
├── Generated/Info.plist       generated by XcodeGen (git-ignored)
├── <App>.xcodeproj            generated by XcodeGen (git-ignored)
└── build/                     everything here is disposable (git-ignored)
    ├── DerivedData/           xcodebuild intermediates and the simulator .app
    ├── logs/                  gen, build, test, archive, export, upload, tester logs
    ├── TestResults.xcresult   the latest `test` run
    ├── screenshots/           <timestamp>.png from `run`; tests/<name>.png from `screenshots`
    ├── archives/              <App>-<version>-<build>.xcarchive
    ├── export/<build>/        the signed .ipa
    └── crashes/               TestFlight crash reports from `crashes`

~/.mainline/
├── config.env                 your settings
├── credentials.env            API credentials (mode 600)
├── AuthKey_<ID>.p8            the API private key (mode 600)
└── state/<bundle-id>.last-build   the last build number uploaded from this Mac
```

## Build numbers

`ship` picks the build number (`CFBundleVersion`, passed as `CURRENT_PROJECT_VERSION`):

```
max( the highest integer build number on App Store Connect for this app + 1,
     ~/.mainline/state/<bundle-id>.last-build + 1 )
```

The local file covers a build uploaded minutes ago that the API doesn't list yet. Build numbers are plain integers,
never stored in your repo, and you never edit them.

## The `asc` helper

A small App Store Connect API client in Swift with no dependencies (`tools/MainlineTools/Sources/asc`). It signs ES256
JWTs with CryptoKit, refreshes them every 15 minutes, and retries HTTP 429 and 5xx responses with backoff. Run it as
`mainline asc <command>`, which loads your credentials and builds it if needed.

| Command | stdout | Notes |
| --- | --- | --- |
| `check` | `ok` | Lists the apps the key can see on stderr |
| `bundle-id ensure <identifier> <name>` | bundle ID resource ID | Registers an iOS bundle ID if missing. The name is reduced to letters, digits and spaces. |
| `app find <bundle-identifier>` | app ID | Exit 3 if there's no app record |
| `build next-number <app-id>` | integer | The highest uploaded integer build + 1 (1 if none) |
| `build list <app-id> [--limit N]` | table | Default limit 10 |
| `build wait <app-id> <build-number> [--timeout SECS] [--interval SECS]` | build ID | Defaults 1800 and 30. Exit 0 once `VALID` and the internal TestFlight state has settled; exit 1 on `FAILED` or `INVALID`; exit 2 on timeout. Warns on `MISSING_EXPORT_COMPLIANCE`. |
| `group ensure <app-id> <name> [--external]` | group ID | Finds or creates an internal group with access to all builds (or an external group) |
| `tester add <group-id> <email> [--first NAME] [--last NAME]` | tester ID | Adds a tester to the group, creating the tester if needed. Safe to repeat. |
| `api <METHOD> <path> [json-body]` | JSON | A raw call, e.g. `mainline asc api GET /v1/apps` |

Output contract: the result alone on stdout, diagnostics on stderr. Exit codes: `0` ok · `1` error · `2` timeout ·
`3` not found · `64` usage.

## The `appicon` helper

```sh
tools/MainlineTools/.build/release/appicon --out Icon.png --symbol flame.fill --from "#FF9F1C" --to "#E71D36"
tools/MainlineTools/.build/release/appicon --out Icon.png --text T --from "#1D3557" --to "#457B9D" [--fg "#FFFFFF"] [--scale 0.56]
```

Renders a 1024×1024 sRGB PNG **without an alpha channel** (App Store Connect rejects transparent icons): a diagonal
gradient with a centered white glyph. `mainline icon` calls it for you.
