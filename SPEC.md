# BH AI Workout — Spec v1.2

Personal iOS strength-training log. Single user, iPhone only, not published to the App Store.

Clickable mockup (visual reference for every screen): https://claude.ai/artifact/Pb7fctHzTaLDpowQu3E9V8

---

## 0. Platform & tech

| # | Requirement |
|---|---|
| 0.1 | iOS 17+, iPhone only, portrait. |
| 0.2 | SwiftUI, SwiftData (local store), Swift Charts, HealthKit, UserNotifications. No third-party dependencies. |
| 0.3 | Data model designed so CloudKit sync can be enabled in v2 without migration pain (all properties optional or defaulted, no unique constraints, relationships optional). |
| 0.4 | Runs on the owner's iPhone with a free (personal team) Apple ID signing. |

## 1. Navigation

| # | Requirement |
|---|---|
| 1.1 | Four tabs: **Workouts**, **Calendar**, **Progress**, **Settings**. |
| 1.2 | First launch seeds one sample workout, "Full Body A" (§2.7), and the 25 built-in exercises (§3). |

## 2. Add/Edit Workout

| # | Requirement |
|---|---|
| 2.1 | Workout **name** is required. |
| 2.2 | **Add Exercise** opens the exercise picker (§3). |
| 2.3 | Each exercise row shows name, sets × reps (or sets × duration), weight, and warm-up count. |
| 2.4 | Exercises can be edited, removed and reordered (drag). |
| 2.5 | **Save** stores the workout; **Cancel** discards changes. |
| 2.6 | A workout can be deleted (with confirmation). Its past sessions stay in the calendar. |
| 2.7 | Sample "Full Body A": Barbell Back Squat 3×10 @ 45 lb · Barbell Bench Press 3×10 @ 45 lb · Barbell Bent-Over Row 3×10 @ 45 lb · Bodyweight Plank 3×60s. Editable/deletable like any workout. |

## 3. Exercise Picker

| # | Requirement |
|---|---|
| 3.1 | Lists 25 built-in exercises plus custom ones, sorted A–Z. |
| 3.2 | Names are prefixed with equipment: "Barbell …", "Dumbbell …", "Bodyweight …". |
| 3.3 | Search field filters as you type (case-insensitive substring). |
| 3.4 | **Rep exercises:** working sets (default **3**), reps (default **10**), weight. |
| 3.5 | **Timed exercises:** working sets (default **3**), duration (default **60s**), weight. |
| 3.6 | **Bodyweight exercises:** added weight defaults to **0**. Displayed as "BW" or "BW + 25 lb". |
| 3.7 | Optional warm-up sets and warm-up reps (rep exercises only). Warm-ups use the exercise's weight. |

**Built-in exercises (25):**
- **Barbell (10):** Back Squat, Front Squat, Bench Press, Incline Bench Press, Overhead Press, Deadlift, Romanian Deadlift, Bent-Over Row, Curl, Hip Thrust
- **Dumbbell (10):** Bench Press, Incline Bench Press, Shoulder Press, Row, Curl, Hammer Curl, Lateral Raise, Lunge, Goblet Squat, Romanian Deadlift
- **Bodyweight (5):** Push-up, Pull-up, Chin-up, Dip, Plank *(timed)*

## 4. Custom Exercises

| # | Requirement |
|---|---|
| 4.1 | Fields: **name**, **equipment** (Barbell / Dumbbell / Bodyweight / Other), **type** (Reps / Timed). |
| 4.2 | Equipment prefix is added to the name automatically ("Other" adds no prefix). |
| 4.3 | Custom exercises can be edited or deleted. Built-ins cannot. |

## 5. Workout Screen (in session)

| # | Requirement |
|---|---|
| 5.1 | User picks which saved workout to start. |
| 5.2 | One card per exercise: name, sets × reps (or duration), weight. |
| 5.3 | **Rep sets:** one circle per set. Tap empty → done with target reps. Each further tap → one rep fewer. Tap at 0 → back to empty. |
| 5.4 | **Timed sets:** tap starts a countdown; set is done when it reaches 0. Tap while running → stop early and log elapsed seconds. Tap a done timed set → reset. |
| 5.5 | Warm-up sets appear before working sets, visually distinct (dashed outline, lighter fill when done). |
| 5.6 | **+/−** change weight by **5 lb** (2.5 kg). Weight can't go below 0. |
| 5.7 | On **Finish**, the last weight used for each exercise becomes the saved weight in the workout. Weight never changes automatically. |
| 5.8 | Rest timer starts when a **working** set is completed (not warm-ups). Default 90s (from Settings). **+30s** and **Skip**. |
| 5.9 | When rest ends: sound + vibration, also when locked/backgrounded (local notification scheduled at rest start; cancelled on skip/change). |
| 5.10 | **Finish** saves the session to history and writes it to Apple Health. |
| 5.11 | **Discard** asks for confirmation, then ends the session without saving anything. |
| 5.12 | If the app is killed mid-session, relaunch restores the same session (sets, weights, timers computed from stored timestamps). |

Set-circle colors: empty = white with grey outline; done at target = accent fill; done below target = dark fill; running timed set = accent outline with countdown.

## 6. Calendar

| # | Requirement |
|---|---|
| 6.1 | Month view; days with a completed session are marked; today is outlined. Month back/forward navigation. |
| 6.2 | Tapping a marked day shows the session: workout name, start time, duration, and each exercise's sets (reps/time) and weight. Multiple sessions on one day are all listed. |
| 6.3 | A past session can be edited (reps/time per set, weight). Edits change history only, never saved workout weights. |
| 6.4 | A past session can be deleted (confirmation). This also deletes it from Apple Health. |

## 7. Progress

| # | Requirement |
|---|---|
| 7.1 | **Per-exercise line chart**, one point per session: top working weight for rep exercises, best duration for timed exercises. Exercise chosen from a picker. |
| 7.2 | **Workouts per week** bar chart. |
| 7.3 | Range filter for both: **1M / 3M / 1Y / All**, default **3M**. |

## 8. Apple Health

| # | Requirement |
|---|---|
| 8.1 | Ask for write permission the first time a workout is finished. |
| 8.2 | Save each finished session as `HKWorkout` with activity type `.traditionalStrengthTraining`, start, end, duration. |
| 8.3 | Deleting a session in the app deletes the matching HealthKit workout (store its UUID). |
| 8.4 | If permission is declined, everything else works and nothing is written. |
| 8.5 | Imported sessions are **not** written to Apple Health. |

## 9. Settings & Data

| # | Requirement |
|---|---|
| 9.1 | Units: **lb** (default) or kg. Values stored in one canonical unit; display converts. |
| 9.2 | Default rest timer length, 15–600s in 15s steps (default 90s). |
| 9.3 | Data stored on device (v1). |
| 9.4 | **Export:** choose **CSV** (one row per set) or **JSON** (complete data). File goes to the iOS share sheet. Filename `bh-ai-workout-YYYY-MM-DD.csv/.json`. |
| 9.5 | **Import:** pick a JSON file (exported by this app) via the iOS file picker. Show a preview first: workouts, sessions, custom exercises, date range. |
| 9.6 | Import modes: **Merge** (default — add new items, skip sessions that already exist, matched by ID) or **Replace all data** (warning, destructive red button). |
| 9.7 | Invalid or unrecognised file → error message, no changes. |
| 9.8 | Apple Health toggle (on/off for writing new sessions). |
| 9.9 | iCloud sync row shown as "Coming in v2" (disabled). |

## 10. Out of scope for v1

iCloud sync (v2) · Android/web · automatic weight progression · plate calculator · Apple Watch app.

---

## Design notes (from the mockup)

- Ground `#F3F2EE`, cards `#FFFFFF` with `#DDDBD4` border, 16pt corner radius.
- Ink `#16171A`, secondary text `#5C5F66`, accent `#C2410C`, accent soft `#FBE3D6`, destructive `#B42318`.
- Large uppercase condensed titles; system font for body. Touch targets ≥ 44pt.
- Support Dark Mode with equivalent tokens.
