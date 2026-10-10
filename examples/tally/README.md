# Tally

The example app that ships with mainline: named counters you tap to count up. SwiftUI and SwiftData, iPhone, iOS 18 and later.

- Tap a card to count up, **–** to count down (never below zero), and press and hold to reset or delete.
- Launch arguments: `-ui-testing` gives a fresh in-memory store; `-seed-sample-data` fills it with demo counters for screenshots.

```sh
mainline test tally                               # unit and UI tests
mainline run tally -- -seed-sample-data           # a screenshot with demo data
mainline ship tally                               # → TestFlight
```

`mainline` finds this app by name from any folder. Its bundle ID is your prefix plus `.tally`. Before you ship it,
set `ASC_APP_NAME` in `app.env` to a store name of your own, since store names are unique across the App Store.
