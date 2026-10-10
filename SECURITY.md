# Security

## How mainline handles your credentials

- Your App Store Connect API key and its IDs live in `~/.mainline/` (the folder is mode 700, the files 600).
  `mainline setup` copies the key there; nothing else ever writes it anywhere.
- mainline never prints the key, puts it in a log, or writes it into an app, a project file or this repo.
  Build logs can contain your Team ID and bundle IDs, which aren't secret.
- The API key signs short-lived tokens (15 minutes) locally with CryptoKit. It's sent only to Apple: to
  `api.appstoreconnect.apple.com` by the `asc` helper, and to Apple's services by `xcodebuild` and `altool`.
- An API key with the Admin role can manage your App Store Connect account. Keep it like a password. If it leaks,
  revoke it in App Store Connect (Users and Access → Integrations) and make a new one.
- If an AI agent runs mainline for you, keep it from reading `~/.mainline`. [Agents](docs/agents.md#permissions)
  shows the Claude Code settings.

## Reporting a vulnerability

Please report security problems privately, through GitHub's
[private vulnerability reporting](https://github.com/ztaylor/mainline/security/advisories/new), rather than in a
public issue. You'll get a reply within a few days.
