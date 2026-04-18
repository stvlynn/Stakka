# Roadmap

This roadmap is for maintainers and reflects the intended sequence of work from the current codebase state.

## Current Baseline

The current codebase already includes:

- project-based library stacking
- local project catalog with recent-project restore
- Photos + raster/TIFF file import
- TIFF export
- comet review and DSS-style comet modes
- camera capture handoff into stacking projects

## Near-Term Priorities

### 1. Professional Input Formats

- FITS import
- RAW decode
- richer frame metadata capture

### 2. Intermediate Export

- calibrated frame export
- registered frame export
- master calibration export

### 3. Post-Calibration Chain

- background calibration
- channel alignment
- cosmetic correction

## Mid-Term Priorities

### 4. Batch Execution

- queued project execution
- project-level export batches
- failure and retry handling

### 5. Camera Mainline

- direct capture-to-review navigation
- more complete hardware parameter control
- ISO support

### 6. Live Stacking

- incremental stack session model
- accepted/rejected frame handling
- preview update loop

## Product-Side Priorities

### 7. Light Pollution Data

- replace mock repository
- add caching
- add location detail and reverse geocoding

### 8. Dark-Sky Product Features

- favorite locations
- sharing
- weather overlays
- nearby-site suggestions

## Long-Term Work

- stronger comet estimation
- project sync/sharing
- performance passes for large datasets
- production benchmark suite

## Notes

- This file is sequence guidance, not a release contract
- Update it when priorities or ordering change
- Keep implemented features out of the future buckets once they land
