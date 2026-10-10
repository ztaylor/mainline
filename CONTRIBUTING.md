# Contributing

Thanks for wanting to help. Fixes, docs, new pitfalls for the agent guide, and support for more of Apple's
workflow are all welcome.

## Build and test

```sh
shellcheck -x bin/mainline lib/common.sh tests/cli.sh        # the CLI must stay clean, and bash 3.2 compatible
/bin/bash tests/cli.sh                         # offline CLI checks, isolated temporary settings
swift test --package-path tools/MainlineTools  # offline API, token, argument and release-state tests
swift build -c release --package-path tools/MainlineTools
bin/mainline test tally                         # the example app, end to end in the simulator
```

Release commands (`register`, `ship`, `status`, `crashes`) talk to App Store Connect, so test them against your own
account with your own copy of the example: `mainline setup`, then `mainline ship tally` with your own `ASC_APP_NAME`.

## Ground rules

- **bash 3.2.** `bin/mainline` and `lib/common.sh` run on the stock macOS bash: no associative arrays, no `mapfile`,
  no `readlink -f`, no `${var,,}`.
- **No dependencies** beyond Xcode, XcodeGen and jq. The Swift helpers in `tools/MainlineTools` use only Apple's frameworks.
- **The agent contract.** Results go to stdout and progress to stderr. Each failure mode has its own exit code
  ([the table](docs/commands.md#exit-codes)). Long tool output goes to a log, and only the lines that matter are printed.
  New behavior should keep all three.
- **Nothing personal in the repo.** Team IDs, bundle prefixes, emails and key IDs belong in `~/.mainline`.
- **Docs move with the code.** Update `docs/` and `CHANGELOG.md` in the same pull request. `docs/agent-guide.md` is
  what `mainline guide` prints, so keep it accurate and short.

## The agent guide's pitfalls

If you or your agent lost an hour to an iOS, SwiftUI or Xcode behavior that a one-line warning would have prevented,
add it to the "Pitfalls" section of [`docs/agent-guide.md`](docs/agent-guide.md): the symptom, the cause, and the fix.

## Pictures

The README's pictures come from real simulator screenshots:

```sh
swift tools/media/render-media.swift fan docs/media/tally.png <back.png> <front.png>
swift tools/media/render-media.swift social docs/media/social.png <left.png> <middle.png> <right.png>
```

The hero (`docs/media/hero-*.svg`) is hand-written SVG; edit it directly.

## Pull requests

Keep a pull request to one change, say what it changes and why, and say how you tested it (which commands, and against
which Xcode).
