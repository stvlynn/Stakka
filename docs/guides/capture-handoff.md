# Capture Handoff Guide

This guide explains how the camera workflow hands off captured frames into the stacking project system.

## Current Goal

The camera module does not yet perform a full in-place post-capture review flow. Instead, it writes the completed capture sequence into the stacking project system so the library tab can continue the workflow.

## Main Path

Relevant types:

- `CameraViewModel`
- `StartCaptureSequenceUseCase`
- `ReplaceRecentStackProjectWithCapturedFramesUseCase`
- `LibraryStackingViewModel`

## Sequence

1. Camera capture starts from `CameraViewModel.startStackingCapture()`
2. `StartCaptureSequenceUseCase` captures `CaptureFrame` values
3. On completion, `ReplaceRecentStackProjectWithCapturedFramesUseCase` replaces the recent project
4. The replacement project contains:
   - `Light` frames only
   - `capture` frame sources
   - default stacking mode
   - no comet mode yet
5. `LocalStackProjectRepository` posts a change notification
6. `LibraryStackingViewModel` observes that notification and refreshes project data

## UI Feedback

`CameraView` currently shows a small confirmation card after capture completes, indicating that the sequence was written into a project.

This is not yet the final intended UX. The roadmap still includes:

- direct navigation into the project review flow
- tighter handoff between capture completion and stacking actions

## Current Constraints

- Capture handoff overwrites the recent project rather than appending to a chosen project
- No live stacking session model is involved
- Capture-origin frames are cached as regular project frame rasters
- Camera hardware controls are still partially stubbed
