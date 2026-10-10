# BH AI Workout

A personal iPhone app for logging strength workouts. The requirements are in [`SPEC.md`](SPEC.md), and there is a clickable mockup at https://claude.ai/artifact/Pb7fctHzTaLDpowQu3E9V8.

## Run it on your iPhone (first time)

You need a Mac with **Xcode 16** (free from the Mac App Store) and **Homebrew** (https://brew.sh).

1. In Terminal, install XcodeGen, the tool that creates the Xcode project file:
   ```
   brew install xcodegen
   ```
2. Get the code and create the project:
   ```
   git clone https://github.com/bartorw-ctrl/bh-ai-workout.git
   cd bh-ai-workout
   xcodegen generate
   open BHAIWorkout.xcodeproj
   ```
3. In Xcode, click **BHAIWorkout** at the top of the left sidebar, open the **Signing & Capabilities** tab, and under **Team** choose your Apple ID. If it isn't listed, choose **Add an Account…** and sign in.
4. Connect your iPhone with a cable, pick it in the device menu at the top of the Xcode window, and press **▶ Run**.
5. The first time, the iPhone will ask you to turn on **Developer Mode** (Settings › Privacy & Security › Developer Mode) and to trust the developer (Settings › General › VPN & Device Management).

With a free Apple ID the app stops opening after 7 days. To fix that, run it from Xcode again.

To try it without a phone, pick an iPhone simulator in the device menu instead. Apple Health saving doesn't work in the simulator.

## For Claude (or a developer)

- `Core/` is a Swift package with the app's logic: set taps, timers, weights, units, export/import, and progress math. Run its tests with `cd Core && swift test`.
- `App/` contains the SwiftUI app: SwiftData models, screens, HealthKit, and notifications.
- `project.yml` defines the Xcode project. Run `xcodegen generate` after adding or removing files.
