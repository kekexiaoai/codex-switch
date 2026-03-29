## Context

The product target remains a native macOS menu bar client. The only change is the hosting mechanism for the menu bar UI. `MenuBarExtra` would simplify the host on newer systems, but it is not a safe baseline for the current development environment, which is macOS 12.

## Goals / Non-Goals

- Goals:
  - Support local development and runtime on macOS 12
  - Preserve a clean path to use `MenuBarExtra` on macOS 13+
  - Keep the menu panel UI independent from host mechanics
- Non-Goals:
  - Implement two different menu panel UIs
  - Raise the deployment target above macOS 12

## Decisions

- Decision: The required baseline host will be `NSStatusItem + NSPopover`
  - Why: It works on macOS 12 and gives precise control over menu bar behavior
- Decision: `MenuBarExtra` is optional and runtime-gated on macOS 13+
  - Why: It can reduce host glue code on newer systems without excluding older machines
- Decision: The shell host will wrap a shared SwiftUI root view
  - Why: It avoids divergent behavior and duplicate state wiring

## Risks / Trade-offs

- AppKit host code is more verbose than a pure SwiftUI `MenuBarExtra` scene
  - Mitigation: keep host code thin and move state into shared view models
- Two host paths can drift
  - Mitigation: both paths render the same SwiftUI panel and use the same environment setup

## Migration Plan

1. Update planning and spec documents
2. Build the macOS 12 host first
3. Add a runtime-gated macOS 13+ host wrapper only after the shared panel is stable

## Open Questions

- Whether the first coded milestone should ship both hosts immediately or defer the `MenuBarExtra` path until after the macOS 12 shell is stable
