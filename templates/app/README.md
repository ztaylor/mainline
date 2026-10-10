# __DISPLAY_NAME__

Built with [mainline](https://github.com/ztaylor/mainline). App metadata is in `app.env`, the project spec in `project.yml`.

Run these commands from this app's folder:

```sh
mainline test                          # unit and UI tests on the simulator
mainline run -- -seed-sample-data      # launch in the simulator and take a screenshot
mainline ship                          # test, archive, upload, TestFlight
```

The starter checks that the first screen launches. Add model tests and a UI test of your main feature before shipping.
