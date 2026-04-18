# Stakka Documentation

Welcome to the Stakka documentation. This guide helps developers understand the architecture, contribute effectively, and maintain code quality.

## Documentation Structure

### [Overview](./overview/)
High-level architecture and design principles.

- **[ARCHITECTURE.md](./overview/ARCHITECTURE.md)** — System architecture, design philosophy, and project structure

### [Modules](./modules/)
Detailed documentation for each feature module.

- **[camera.md](./modules/camera.md)** — Camera capture system with advanced controls
- **[library-stacking.md](./modules/library-stacking.md)** — Photo library stacking workflow
- **[light-pollution.md](./modules/light-pollution.md)** — Light pollution map integration
- **[image-stacking.md](./modules/image-stacking.md)** — Image stacking algorithms
- **[design-system.md](./modules/design-system.md)** — Design tokens and UI patterns

### [Development](./development/)
Development workflow and contribution guidelines.

- **[WORKFLOW.md](./development/WORKFLOW.md)** — Local setup, build process, and testing

## Quick Links

- **New contributors**: Start with [ARCHITECTURE.md](./overview/ARCHITECTURE.md) → [WORKFLOW.md](./development/WORKFLOW.md)
- **Adding features**: Read relevant module doc → Update architecture if needed
- **UI changes**: Review [design-system.md](./modules/design-system.md) first
- **AI agents**: See [AGENTS.md](../AGENTS.md) for coding guidelines

## Documentation Principles

1. **Honest about current state** — Document what exists, not aspirations
2. **Code examples over prose** — Show patterns, don't just describe them
3. **Update with code changes** — Stale docs are worse than no docs
4. **Assume intelligent readers** — Explain "why", not "what"

## Contributing to Docs

When making code changes:

- Update relevant module doc if behavior changes
- Add new module doc for new features
- Keep ARCHITECTURE.md in sync with structural changes
- Update AGENTS.md if introducing new patterns

Documentation follows the same quality standards as code — clear, concise, and maintainable.
