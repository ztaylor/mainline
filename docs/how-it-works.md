# How it works

Shipping an iOS app normally means Xcode's GUI at several points: creating the project, editing its settings, managing
certificates and profiles, archiving, uploading, and setting up TestFlight. mainline replaces each of those with a
command, and comes down to three ideas.

```
 idea ──▶ new ──▶ build · test · run ──▶ register ──▶ ship ─────────────────────────────────────────▶ TestFlight
          │       │                      │            │
          │       │                      │            ├─ test (the gate)
          │       │                      │            ├─ archive, unsigned
          │       │                      │            ├─ export, signed in Apple's cloud
          │       │                      │            ├─ upload (altool)
          │       │                      │            ├─ TestFlight group + testers (API)
          │       │                      │            └─ wait for processing (API)
          │       │                      └─ bundle ID (API); app record (the one web step)
          │       └─ xcodebuild on the simulator; screenshots you (or your agent) look at
          └─ template → app folder → XcodeGen project
```

## 1. The project is generated

An Xcode project file is thousands of lines of machine-written text that nobody can review, and editing it by hand (or
by agent) breaks it. mainline never stores one. Each app has a short `project.yml` and an `app.env`, and
[XcodeGen](https://github.com/yonaskolb/XcodeGen) generates the `.xcodeproj` from them before every command. Settings
live in a file a person can read in a minute, diffs stay small, and a bad edit fails loudly instead of corrupting the project.

## 2. Signing without certificates

Code signing is where most command-line iOS pipelines get stuck: certificates with private keys in the login keychain,
provisioning profiles tied to registered devices, and a keychain that's locked whenever you're not sitting at the Mac.

mainline sidesteps all of it:

1. `ship` **archives unsigned** (`CODE_SIGNING_ALLOWED=NO`). Nothing touches the keychain.
2. It signs during `xcodebuild -exportArchive`, with automatic signing, `-allowProvisioningUpdates`, and the App Store
   Connect API key. Xcode then uses a **cloud-managed Apple Distribution certificate**, whose private key never
   leaves Apple, and creates the App Store provisioning profile on the spot.

So there are no certificates to create, export or renew, no registered devices, and no keychain prompts. `ship` works
the same over SSH, in a CI runner, or from an agent's shell. (Signing at archive time would use a *development*
identity, which needs a key in the login keychain and a registered device. That's the trap this avoids.)

## 3. Apple's API for everything else, and one web step

A dependency-free Swift client for the [App Store Connect API](https://developer.apple.com/documentation/appstoreconnectapi)
(`asc`) registers bundle IDs, finds the app, numbers builds, creates the TestFlight group, adds testers, waits for
processing, and downloads crash reports. Apple's own `altool` does the upload.

One step has no API: **creating the app's record in App Store Connect**, once per app. mainline can't do it, so it does
the next best thing: `register` exits with code 10 and prints every value the form needs. A person fills it in in about
a minute, or an agent that can drive a browser does it for them.

## Built for agents

mainline works fine by hand, but every part of it is shaped so an AI agent can run it unattended:

- **Exit codes are instructions.** Each failure mode has its own code and its own next step: 10 means "do the web step",
  2 means "wait, don't upload again", 78 means "not set up". An agent doesn't have to parse prose to know what to do.
- **Quiet on success, specific on failure.** Full logs go to files. On failure, mainline prints only the error lines
  and the end of the log, which keeps an agent's context small and on point.
- **Results on stdout, progress on stderr.** `run` prints a screenshot path and nothing else on stdout, so the agent
  can read the image right away.
- **Eyes, not just a compiler.** `run` and `screenshots` turn the simulator into images, and the guide tells the agent
  to look at them in light and dark mode. Most UI bugs compile fine.
- **Tests are the gate.** `ship` won't upload a build that fails its tests.
- **A playbook that ships with the tool.** `mainline guide` prints the procedure, the rules, when to ask the human,
  and the pitfalls that cost us hours, matched to the installed version.
- **Secrets stay out of reach.** Credentials live in `~/.mainline` with private permissions. Nothing in an app or a
  log contains them, and the guide tells agents never to read them.

## Why not fastlane?

[fastlane](https://fastlane.tools) is excellent, covers far more (App Store metadata, screenshots, Android), and you
should use it if you need that. mainline is deliberately smaller: Apple's own tools, two small Homebrew packages, and
about 1,400 lines of bash and Swift that you (or your agent) can read in one sitting. No Ruby, no gems, no
plugins, and no match repo, because cloud signing makes certificate syncing unnecessary.

## What it doesn't do (yet)

- **TestFlight, not the App Store.** mainline gets builds to internal testers. Submitting for App Store review, store
  metadata and store screenshots are still done in App Store Connect.
- **Internal testers only.** External TestFlight testing needs Apple's beta review; `mainline asc group ensure --external`
  creates the group, but the review is up to you.
- **iOS apps.** The template is an iPhone app. iPad is a setting in `project.yml`; macOS, watchOS and visionOS apps
  aren't supported yet.
- **A Mac is required.** Xcode only runs on macOS.
- **Tested** with Xcode 26 and 27, a Team API key, and an individual developer account. Organization accounts should
  work the same way; reports welcome.
