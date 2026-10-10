# __DISPLAY_NAME__

Built with [mainline](https://github.com/ztaylor/mainline). App metadata is in `app.env`, the project spec in `project.yml`.

```sh
mainline test __SLUG__                          # unit and UI tests on the simulator
mainline run __SLUG__ -- -seed-sample-data      # launch in the simulator and take a screenshot
mainline ship __SLUG__                          # test, archive, upload, TestFlight
```
