# Agent instructions

This repo is **mainline**, a command-line tool that takes iOS apps from idea to TestFlight without the Xcode GUI.

## If you're asked to build, change or ship an app

Run `bin/mainline guide` and follow it. It's the playbook: the steps in order, the rules, the exit codes, when to ask
the human, and the SwiftUI pitfalls to avoid. Apps created inside this clone go in `apps/`, which git ignores; for
apps that should live in their own repo, suggest `bin/mainline init <dir>`.

## If you're changing mainline itself

- `bin/mainline` and `lib/common.sh` must stay **bash 3.2** compatible (the stock macOS bash: no associative arrays,
  no `mapfile`, no `readlink -f`). Run `shellcheck -x bin/mainline lib/common.sh` before you finish.
- `tools/MainlineTools` (the `asc` and `appicon` helpers) must stay dependency-free Swift. It rebuilds itself when its
  sources change.
- `templates/app/` is what `mainline new` copies. Placeholders: `__APP_NAME__`, `__DISPLAY_NAME__`, `__SLUG__`,
  `__BUNDLE_ID__`, `__ICON_SYMBOL__`, `__ICON_FROM__`, `__ICON_TO__`.
- Keep the agent contract: results on stdout, progress on stderr, a distinct exit code per failure mode
  (see `docs/commands.md#exit-codes`), and quiet logs that print only the relevant lines on failure.
- Never write personal values (team IDs, bundle prefixes, emails, key IDs) into the repo. They belong in `~/.mainline`.
- Check changes against the example: `bin/mainline test tally`.
- Update `docs/` and `CHANGELOG.md` when behavior changes. `docs/agent-guide.md` is what `mainline guide` prints.
