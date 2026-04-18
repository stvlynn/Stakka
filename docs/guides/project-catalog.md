# Project Catalog Guide

This guide explains how stacking projects are stored and managed in the current codebase.

## Purpose

The project catalog replaces the older “single recent project only” storage model. It allows the library workflow to:

- create new projects
- open existing projects
- duplicate projects
- delete projects
- remember one project as the current recent project

## Core Types

- `StackingProject`
- `StackProjectSummary`
- `StackProjectRepository`
- `LocalStackProjectRepository`

The key repository contract lives in:

- `Domains/Stacking/Domain/StackProjectRepository.swift`

The current implementation lives in:

- `Domains/Stacking/Infrastructure/Storage/LocalStackProjectRepository.swift`

## Storage Layout

The local repository stores projects under app storage in a catalog-style layout:

```text
Stakka/
  recent-project-id.txt
  Projects/
    <project-id>/
      project.json
      Frames/
        <frame-id>.png
```

Notes:

- `project.json` stores project metadata, frame metadata, comet annotations, and registration data
- `Frames/` stores cached raster images used by the current project model
- the recent project is tracked separately by ID, not by a dedicated directory name

## Lifecycle

### Save

Saving a project:

1. ensures the project directory exists
2. writes or updates frame cache images
3. writes `project.json`
4. updates the recent-project pointer
5. posts a repository notification so interested view models can refresh

### Load

Loading a project:

1. reads `project.json`
2. resolves stored frame sources
3. reads cached frame rasters back into `StackFrame`
4. rehydrates comet annotations and registration state

### Duplicate

Duplicating a project:

1. loads the source project
2. generates a new project ID
3. generates new frame IDs
4. remaps reference-frame IDs and comet-annotation keys
5. writes the duplicate as a new project

### Delete

Deleting a project removes its directory. If the deleted project was recent, the repository selects another summary as the fallback recent project when available.

## Recent Project Refresh

`LocalStackProjectRepository` posts a notification when the catalog changes. `LibraryStackingViewModel` subscribes to that notification and refreshes:

- project summaries
- the current recent project, when appropriate

This is what lets camera capture handoff update the library tab without rebuilding app-wide state.

## Current Constraints

- There is no rename operation yet
- There is no explicit project archive/favorite state yet
- There is no batch queue state stored per project yet
- Frame caches are rasterized PNG/JPEG snapshots, not source RAW/FITS payloads
