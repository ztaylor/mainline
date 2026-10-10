# Setup

Do part A once per Mac and part B once per Apple developer account. Allow time for Xcode and the simulator runtime to download; installation time depends on your connection. After that, each new app needs only one web step: creating its App Store Connect record ([web steps](web-steps.md#create-the-app-record)).

| Marker | Meaning |
| --- | --- |
| 🧑 **You** | Needs your password, 2FA, a payment, or a decision |
| 🤖 **Agent** | An AI agent can do it: in the terminal, or in your browser if it can drive one |

You're done when `mainline doctor` ends with **All checks passed**.

---

## A. Your Mac

### A1. Xcode 🧑

Install Xcode from the Mac App Store and select it:

```sh
sudo xcode-select -s /Applications/Xcode.app
xcodebuild -version
```

You never have to open the Xcode app, but it has to be installed. mainline is tested with Xcode 26 and 27; apps
created from the template target iOS 18 and later.

### A2. Xcode's first-launch components 🧑 (needs `sudo`)

```sh
sudo xcodebuild -runFirstLaunch
```

Xcode installs these system components the first time you open it. If you never open it, they're missing, and every
simulator build fails with errors like `CoreSimulator is out of date` or `Unable to find a device matching the
provided destination specifier`. Run this again after every major Xcode update.

### A3. An iOS simulator 🤖

```sh
xcrun simctl list devices available | grep iPhone || xcodebuild -downloadPlatform iOS
```

mainline prefers the simulator named in `SIMULATOR_NAME` (default `iPhone 17 Pro`) and falls back to any iPhone.

### A4. mainline and its two dependencies 🤖

```sh
brew install xcodegen jq
git clone https://github.com/ztaylor/mainline ~/mainline
export PATH="$HOME/mainline/bin:$PATH"     # add this to ~/.zshrc to keep it
```

[XcodeGen](https://github.com/yonaskolb/XcodeGen) generates each app's Xcode project from a short YAML file, and
[jq](https://jqlang.org) reads JSON in the scripts. mainline's own helpers (`asc`, `appicon`) are a small Swift package
with no dependencies that builds itself the first time it's needed. To update mainline later, `git pull` in its folder.

### A5. Check 🤖

```sh
mainline doctor
```

The toolchain section should pass now. You can already build, test and run apps in the simulator: try
`mainline test tally` to run the example app's tests. The rest of `doctor` passes after part B.

---

## B. Your Apple developer account

### B1. Apple Developer Program 🧑

Uploading to TestFlight needs a paid membership, as an individual or an organization: <https://developer.apple.com/programs/enroll/>.
Enrollment is a payment and an identity check, so only you can do it.

### B2. Team ID and bundle prefix 🤖

Your Team ID is on <https://developer.apple.com/account> under **Membership details**: 10 letters and digits, like
`ABCDE12345`. The bundle prefix is a reverse-DNS name you control, like `com.yourname`; each app's bundle ID becomes
`<prefix>.<app>`. Add yourself as a TestFlight tester while you're at it (internal testers must be users of your App
Store Connect team, so on an individual account that's your Apple ID's email):

```sh
mainline setup --team ABCDE12345 --prefix com.yourname --tester you@example.com
```

These go in `~/.mainline/config.env`. Run `mainline setup` with no options to be asked for each value instead.

### B3. App Store Connect API key

mainline does everything Apple-side (signing, upload, TestFlight) with one **Team** API key with the **Admin** role.
An agent that can drive your browser can do this; the click-by-click version is in [web steps](web-steps.md#create-the-app-store-connect-api-key).

1. In [App Store Connect](https://appstoreconnect.apple.com/access/integrations/api), go to **Users and Access** →
   **Integrations** → **App Store Connect API** → **Team Keys**.
   The first time, the Account Holder may need to click **Request Access** and accept the terms. 🧑
2. **Generate API Key**: name it `mainline`, give it **Admin** access.
3. Note the **Issuer ID** (the UUID above the table) and the new key's **Key ID**.
4. **Download** the key, `AuthKey_<KEYID>.p8`. ⚠️ Apple lets you download it **only once**. If you lose it, revoke the
   key and make a new one.

Then hand it to mainline, which copies the key into `~/.mainline/` with private permissions and reads the Key ID from the file name:

```sh
mainline setup --key ~/Downloads/AuthKey_ABC123DEFG.p8 --issuer 00000000-0000-0000-0000-000000000000
rm ~/Downloads/AuthKey_ABC123DEFG.p8     # once doctor passes
```

**Why Admin?** At export time, `xcodebuild -allowProvisioningUpdates` uses the key to create Apple's cloud-managed
distribution certificate and the App Store provisioning profile. Keys with the App Manager role or lower tend to fail
at exactly that step. Admin also lets mainline register bundle IDs and manage TestFlight groups.

**Individual keys.** App Store Connect also offers per-user Individual keys. Leave the issuer empty to use one
(`--issuer ""`); mainline then signs its tokens as a user key. Apple restricts what Individual keys can do, signing in
particular, so prefer a Team key.

### B4. Check 🤖

```sh
mainline doctor
```

```
==> App Store Connect API key (~/.mainline/credentials.env)
    ✓ ASC_KEY_ID=ABC123DEFG
    ✓ ASC_ISSUER_ID set (Team key)
    ✓ key file ~/.mainline/AuthKey_ABC123DEFG.p8
    ✓ App Store Connect API reachable, credentials valid

    ✓ All checks passed. Ready to ship.
```

If the API check fails, see [troubleshooting](troubleshooting.md#api-credentials).

---

## What's where

```
~/.mainline/
├── config.env          your settings: DEVELOPMENT_TEAM, BUNDLE_PREFIX, TESTER_EMAILS, and any overrides
├── credentials.env     API key ID, issuer and key path (mode 600)
├── AuthKey_<ID>.p8     the API private key (mode 600)
└── state/              the last build number uploaded per app, from this Mac
```

Account configuration and API credentials stay outside your repositories. Generated projects and logs contain the
Team ID and bundle ID; each app records its bundle ID in `app.env`. Set `MAINLINE_HOME` to move `~/.mainline`, or
`MAINLINE_CONFIG` / `MAINLINE_CREDENTIALS` to point at individual files (handy for CI).

Next: the [playbook](playbook.md), or hand it to your agent ([agents](agents.md)).
