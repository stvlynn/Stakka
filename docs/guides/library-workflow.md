# Library Workflow Guide

This guide describes the current end-to-end library project workflow.

## Main Screen

The library tab is the main engineering surface for stacking work. It currently combines:

- project browser entry
- project summary
- stacking mode selector
- comet mode selector
- comet review status
- grouped frame sections
- action panel
- final result card

Primary entry point:

- `Domains/Library/Presentation/LibraryStackingView.swift`

State owner:

- `Domains/Library/Presentation/LibraryStackingViewModel.swift`

## Project Flow

### 1. Create or Open a Project

Maintainers can:

- create a new project
- open an existing project
- duplicate an existing project
- delete a project

### 2. Import Frames

Frames can be imported into any of the five groups:

- `Light`
- `Dark`
- `Flat`
- `Dark Flat`
- `Bias`

Current import sources:

- Photos
- Files for raster images and TIFF

Each import invalidates previous:

- analysis
- registration
- stack result

### 3. Analyze

`analyze` computes per-frame metrics:

- star count
- background level
- approximate FWHM
- frame score

If no reference frame is explicitly chosen, the highest-scoring enabled `Light` frame becomes the project reference.

### 4. Register

`register` aligns enabled `Light` frames to the reference frame using:

- homographic Vision registration when possible
- translational fallback otherwise

When comet mode is enabled, registration also triggers automatic comet estimation.

### 5. Review Comet Annotations

When comet mode is enabled:

- low-confidence frames are marked as needing review
- stacking is blocked until review is complete
- users can open the dedicated comet review sheet

### 6. Stack

`stack` performs:

- calibration
- warp application
- light-frame combination
- comet-specific path selection, when enabled

### 7. Export

Current export targets:

- save preview result to Photos
- export final result as TIFF

## Invalidations

Any project mutation that affects inputs or mode selection clears:

- previous stack result
- analysis data
- registration data

This ensures the UI does not present stale outputs after edits.

## Current Limits

- RAW/FITS import is not wired yet
- Intermediate exports are not wired yet
- Batch execution is not wired yet
- Multi-project browsing is local-only and does not include sync/sharing