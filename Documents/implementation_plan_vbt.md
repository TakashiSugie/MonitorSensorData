# VBT Monitoring Implementation Plan

The user wants to implement Velocity Based Training (VBT) monitoring features, which involves tracking the velocity of every rep in a set, displaying historical data, and warning the user during a set if velocity drops significantly.

## Proposed Changes

### [Data Model] WorkoutSession

#### [MODIFY] [WorkoutSession.swift](file:///Users/sugietakashi/Desktop/gemini/antigravity/playground/silver-sagan/BenchSenseR1/RepCount/RepCount Watch App/Models/WorkoutSession.swift)
- Add `var velocities: [Double] = []` to store the speed of each rep.
- Add computed properties:
  - `averageVelocity`: Returns the mean of `velocities` (or 0.0).
  - `maxVelocity`: Returns the maximum value in `velocities`.

### [Core Logic] WorkoutManager

#### [MODIFY] [WorkoutManager.swift](file:///Users/sugietakashi/Desktop/gemini/antigravity/playground/silver-sagan/BenchSenseR1/RepCount/RepCount Watch App/Managers/WorkoutManager.swift)
- Add `@Published var sessionVelocities: [Double] = []`.
- Add a computed property `velocityDropPercentage: Double` to calculate the drop from the maximum velocity seen so far in the current set.
- In `startWorkout()`, clear `sessionVelocities = []`.
- In `onRepDetected`, append `self.lastRepVelocity` to `sessionVelocities`.
- In `saveAndReturn()`, initialize `WorkoutSession` passing `velocities: sessionVelocities`.

### [UI] WorkoutView (Active Session)

#### [MODIFY] [WorkoutView.swift](file:///Users/sugietakashi/Desktop/gemini/antigravity/playground/silver-sagan/BenchSenseR1/RepCount/RepCount Watch App/Views/WorkoutView.swift)
- Update the VBT display to format: `VBT: 0.45 m/s (-15%)`.
- If the `velocityDropPercentage` is >= 30%, change the text color to red and display a warning text like "30% Drop! Stop Set".

### [UI] ResultView (Session Summary)

#### [MODIFY] [ResultView.swift](file:///Users/sugietakashi/Desktop/gemini/antigravity/playground/silver-sagan/BenchSenseR1/RepCount/RepCount Watch App/Views/ResultView.swift)
- Add a section below the 1RM/duration summary to display:
  - Average VBT.
  - A rep-by-rep list or grid showing the velocity of each rep to show how the VBT transitioned.

### [UI] HistoryView (Past Sessions)

#### [MODIFY] [HistoryView.swift](file:///Users/sugietakashi/Desktop/gemini/antigravity/playground/silver-sagan/BenchSenseR1/RepCount/RepCount Watch App/Views/HistoryView.swift)
- In the session row, render an "Avg VBT: 0.00 m/s" badge right next to the 1RM badge.

## Verification Plan

### Manual Verification
1. Open the app on simulator or physical Apple Watch.
2. Start a workout.
3. Simulate/Perform reps with varying speeds.
4. Verify the active screen shows the VBT drop percentage and displays a warning when it exceeds 30%.
5. Stop the workout and verify the ResultView shows the correct array of velocities and the average.
6. Save the session and verify the HistoryView displays the average VBT.
