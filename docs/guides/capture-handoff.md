# Capture Handoff Guide

This guide explains how the camera workflow hands off captured frames into the stacking project system.

## Current Goal

The camera module now performs capture-time live stacking, then writes the resulting `StackingProject` into the project system so the library tab can continue review, stacking, and export.

## Main Path

Relevant types:

- `CameraViewModel`
- `StartCaptureSequenceUseCase`
- `LiveStackingProcessor`
- `ImageLiveStackingSession`
- `ReplaceRecentStackProjectWithCapturedFramesUseCase`
- `LibraryStackingViewModel`

## Sequence

1. Camera capture starts from `CameraViewModel.startStackingCapture()`
2. `CameraViewModel` resets `LiveStackingProcessor` with the selected star-mode strategy
3. `CameraViewModel` starts an `AsyncStream` consumer for live-frame processing
4. `StartCaptureSequenceUseCase` passes `CaptureSettings` into `CameraDeviceRepository.capturePhoto(settings:)`
5. `AVCaptureSessionRepository` applies supported device settings, captures a still, and returns a `CaptureFrame`
6. Each captured frame is yielded into the live-frame stream without awaiting stacking work
7. The live session analyzes, optionally registers, and stacks the frame into a `LiveStackingSnapshot`
8. The snapshot updates live preview, accepted/rejected counts, and total exposure on the main actor
9. After the capture loop finishes, the stream is closed and drained
10. On completion, `ReplaceRecentStackProjectWithCapturedFramesUseCase` saves the live-built project as the recent project
11. The replacement project contains:
   - `Light` frames only
   - `capture` frame sources
   - a mode-specific stacking mode
   - no comet mode yet
12. `LocalStackProjectRepository` posts a change notification
13. `LibraryStackingViewModel` observes that notification and refreshes project data

## Mode Mapping

| Camera mode | Live strategy | Saved stacking mode |
|---|---|---|
| Milky Way | registered deep sky stack | `kappaSigma` |
| Star Trails | fixed-tripod bright-trace stack | `maximum` |
| Moon | registered lunar stack | `medianKappaSigma` |
| Meteor | fixed-tripod bright-trace stack | `maximum` |

## UI Feedback

`CameraView` shows an in-preview live stack card while capture is running. It uses the latest snapshot preview plus accepted-frame count, rejected-frame count, and total exposure.

Total exposure is based on the accepted `CaptureFrame.exposureDuration` values returned by the camera repository. This keeps short lunar shutter presets such as `1/125` from being displayed or saved as whole-second exposures.

After capture completes, it still shows a small confirmation card indicating that the live project was written into the project catalog. The roadmap still includes:

- direct navigation into the project review flow
- tighter handoff between capture completion and stacking actions

## Current Constraints

- Capture handoff overwrites the recent project rather than appending to a chosen project
- Capture-origin frames are cached as regular project frame rasters
- Camera hardware control covers custom exposure duration and zoom where the active `AVCaptureDevice` supports them
- Aperture and DSLR-style shooting mode remain preset/readout state
