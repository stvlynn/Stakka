# Stakka Documentation

This documentation is written for maintainers working on the current codebase.

## Structure

### Overview

- [overview/ARCHITECTURE.md](./overview/ARCHITECTURE.md) — system layout, domain boundaries, and key runtime flows

### Modules

- [modules/library-stacking.md](./modules/library-stacking.md) — project-based stacking workflow
- [modules/image-stacking.md](./modules/image-stacking.md) — analysis, registration, calibration, stacking, comet modes
- [modules/camera.md](./modules/camera.md) — capture UI and capture-to-project handoff
- [modules/light-pollution.md](./modules/light-pollution.md) — map module, mock data, real-data gaps
- [modules/design-system.md](./modules/design-system.md) — tokens, motion, visual rules

### Guides

- [guides/project-catalog.md](./guides/project-catalog.md) — local project storage, recent project, duplication, deletion
- [guides/library-workflow.md](./guides/library-workflow.md) — how library projects move from import to export
- [guides/comet-mode.md](./guides/comet-mode.md) — comet modes, annotation flow, implementation details
- [guides/capture-handoff.md](./guides/capture-handoff.md) — how camera capture writes into stacking projects

### Development

- [development/WORKFLOW.md](./development/WORKFLOW.md) — setup, Makefile commands, simulator debugging, build/test workflow

### Planning

- [roadmap.md](./roadmap.md) — current baseline, near-term priorities, long-term product direction

## Suggested Reading Order

For a new maintainer:

1. [overview/ARCHITECTURE.md](./overview/ARCHITECTURE.md)
2. [development/WORKFLOW.md](./development/WORKFLOW.md)
3. [modules/library-stacking.md](./modules/library-stacking.md)
4. [modules/image-stacking.md](./modules/image-stacking.md)
5. [guides/project-catalog.md](./guides/project-catalog.md)
6. [guides/comet-mode.md](./guides/comet-mode.md)

For camera work:

1. [modules/camera.md](./modules/camera.md)
2. [guides/capture-handoff.md](./guides/capture-handoff.md)

For product-side map work:

1. [modules/light-pollution.md](./modules/light-pollution.md)
2. [roadmap.md](./roadmap.md)

## Documentation Rules

- Document what exists in the current codebase
- Separate implemented behavior from roadmap items
- Prefer concrete workflow descriptions over aspirational summaries
- Update the relevant module doc when changing behavior
- Update the roadmap when changing sequence or priorities
