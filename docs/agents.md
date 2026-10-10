# Using mainline with an AI agent

mainline was built to be driven by an agent. You describe the app; the agent writes it, tests it, looks at it, and
ships it, and you install it from TestFlight. This page is for you, the human. The agent's own instructions are the
[agent guide](agent-guide.md), which `mainline guide` prints.

## Who does what

| You | Your agent |
| --- | --- |
| Install Xcode and run the one `sudo` step ([setup](setup.md)) | Install mainline and its dependencies, check with `doctor` |
| Enroll in the Apple Developer Program | Create the API key in your browser, if it can drive one |
| Approve 2FA prompts and Apple's agreements | Scaffold, write the Swift, test, screenshot, fix |
| Decide names: the store name and bundle ID are permanent | Register, create the app record, ship, check status |
| Install from TestFlight and try it | Read crash reports, reproduce, fix, ship again |

## Claude Code

Install the plugin. It adds a skill that knows when to reach for mainline:

```
/plugin marketplace add ztaylor/mainline
/plugin install mainline@mainline
```

(Or from your shell: `claude plugin marketplace add ztaylor/mainline && claude plugin install mainline@mainline`.)

Then ask for what you want, in plain words:

> Make me an iPhone app for tracking which houseplants I've watered, with reminders. Ship it to TestFlight.

> Add a dark-mode app icon to tally and ship a new build.

> My tester says the app crashed when they tapped Share. Check the crash logs and fix it.

The skill also runs on its own name, `/mainline:ship-ios-app`. Without the plugin, a workspace made with `mainline init`
has a `CLAUDE.md` that points Claude at the guide, which works just as well.

### Permissions

mainline runs many commands, so you'll probably want to allow them without a prompt each time, and keep your
credentials out of reach. In `~/.claude/settings.json` (every project) or `.claude/settings.local.json` (one project):

```json
{
  "permissions": {
    "allow": ["Bash(mainline *)"],
    "deny": ["Read(~/.mainline/**)", "Edit(~/.mainline/**)"]
  }
}
```

The deny rules stop Claude's file tools and the usual shell readers (`cat`, `head`, `sed` and so on) from opening your
credentials. They can't stop a script that opens files itself, so they're a guard rail rather than a wall; for a hard
boundary, use Claude Code's [sandboxing](https://code.claude.com/docs/en/sandboxing). mainline itself still reads the
credentials, because it runs as its own process. If you call it as `bin/mainline`, allow that form too:
`"Bash(bin/mainline *)"`.

### The browser step

Each new app needs one form filled in on App Store Connect ([why](how-it-works.md#3-apples-api-for-everything-else-and-one-web-step)).
With [Claude in Chrome](https://claude.com/chrome) connected, Claude fills it in, in a new tab of your normal Chrome where
you're already signed in to Apple. It never types passwords: if Apple asks you to sign in or for a 2FA code, it stops and
asks you. Without a browser, Claude gives you the values to paste and waits.

## Other agents

Codex, Cursor, Gemini CLI, Aider and others read `AGENTS.md`. Make a workspace and start the agent in it:

```sh
mainline init my-apps && cd my-apps
```

The workspace's `AGENTS.md` tells the agent to run `mainline guide` before it does anything. For an agent that doesn't
read `AGENTS.md`, start with: "Run `mainline guide` and follow it."

## Working on the Mac from somewhere else

Because signing happens in Apple's cloud, nothing needs the Mac's keychain or its screen. You can run your agent over
SSH from another computer, from a phone, or in a cloud session, and `ship` works the same. Two things to know:

- `sudo` steps need a real terminal. Run them yourself (`ssh -t mac 'sudo xcodebuild -runFirstLaunch'`).
- A browser the agent drives may run on a different computer than the Mac, so a downloaded API key lands there.
  Copy it across before `mainline setup --key` ([web steps](web-steps.md#rules-for-an-agent-driving-the-browser)).

## Tips for good results

- **Give it taste to work with.** "Make the branding feel like a 1970s field guide" gets a better app than "make it nice".
  mainline's guide tells the agent to set up a brand and a real icon from the first build.
- **Ask for screenshots.** The agent already looks at them; ask it to show you the light and dark ones before it ships.
- **Keep v1 small.** One or two screens that are polished beat six that are rough. Ship, use it for a day, then ask for more.
- **Report crashes from TestFlight.** When the app crashes, TestFlight offers to share a report. Do it, then tell your
  agent. `mainline crashes` hands it the stack trace and your comment.
