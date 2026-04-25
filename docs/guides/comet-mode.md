# Comet Mode Guide

This guide explains the current DSS-style comet stacking implementation.

## Supported Modes

`CometStackingMode` currently supports:

- `standard` — stars frozen, comet trails
- `cometOnly` — comet frozen, stars trail
- `cometAndStars` — comet and stars both frozen

These modes are configured on `StackingProject.cometMode`.

## Data Model

The comet workflow is built on three pieces of project data:

- `cometMode`
- `cometAnnotations`
- `enabledFramesNeedingCometReview`

Each `CometAnnotation` stores:

- `estimatedPoint`
- `resolvedPoint`
- `confidence`
- `isUserAdjusted`
- `requiresReview`
- `sourceFrameSize`

## Automatic Estimation

Automatic estimation runs after registration when comet mode is enabled.

The current heuristic is:

1. warp each enabled `Light` frame into the star-aligned grid
2. compute a median background field
3. subtract that field to isolate moving residuals
4. find a bright local residual cluster as the comet candidate
5. smooth or interpolate weak candidates across the frame sequence

This is intentionally conservative. If confidence is too low, the frame is marked for manual review.

## Manual Review

The review flow lives in:

- `CometAnnotationReviewView`
- `CometAnnotationCanvas`

Current behavior:

- user opens the review sheet from the project screen or a light-frame thumbnail
- user moves frame-by-frame
- user taps to place the comet core
- user can restore the automatically estimated point

The review flow writes directly back into the project model through `LibraryStackingViewModel`.

## Stacking Behavior

### Standard

- Uses the normal star-aligned composite
- Comet remains trailed

### Comet Only

- Re-shifts star-aligned frames into a comet reference frame
- Comet is frozen
- Stars trail

### Comet And Stars

- Produces a star-aligned composite
- Produces a comet-aligned composite
- Blends the comet-aligned region back into the star-aligned result

## Current Constraints

- Estimation is heuristic, not a production-grade comet detector
- Only one comet core per frame is supported
- Review is required when confidence is low
- Live stacking does not support comet mode yet