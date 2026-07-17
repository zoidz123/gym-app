# Ultra-flat Gym App Redesign

## Visual Target

The approved target is Direction 2, Ultra-flat, from the Perch chart selected on July 17, 2026.
The canonical visual reference is `/Users/zoidz123/.perch/charts/58d6b04bac3026c2/gym-style-option-2.png` at the 390 by 844 iPhone viewport.
The system is black-first with the existing coral and pink identity, continuous content, hairline separators, stable data columns, and minimal native chrome.

## Preserved Product Behaviors

The redesign preserves the existing Home, Plan, History, template, active workout, and set-entry information architecture.
It preserves reusable workout planning, template grouping, frequency changes, duplicate weekly occurrences, occurrence-based completion, independent completion markers, Monday rollover, persistence, migrations, and workout logging.
It preserves the existing navigation routes, sheets, actions, editing controls, seeded workout data, and data ownership.
No product feature or new content type is added.

## Screen Translation

Home becomes a continuous weekly progress list followed by a flat current-workout section, one prominent coral start action, and separated change-workout rows.
Plan keeps its expandable template groups and frequency controls while replacing nested exercise cards with numbered rows and subtle superset grouping.
History uses stable date, exercise, and set columns with continuous rows and separators, while History detail uses flat exercise tables instead of stacked cards.
Template creation and editing retain native grouped forms and sheets with flatter row backgrounds, semantic toolbar actions, and visible grouping without card nesting.
Active workout uses a flat header, separated exercise sections, stable load and reps columns, and restrained controls that keep the current logging workflow unchanged.
Inline set entry uses monospaced numeric columns, a coral focus treatment, subtle non-color completed-row cues, and existing 44-point editing targets.

## Design Tokens

The app background uses the semantic system background so the dark presentation is black and the supported light presentation remains adaptive.
Primary and secondary text use semantic label colors, separators use the semantic separator color, and secondary row states use system fill colors.
The existing coral remains the app accent and is reserved for the current action, focused field, selected tab, and completed state.
Containers use square or minimally rounded geometry only where a native control or grouped sheet requires a boundary.
Typography uses SwiftUI Dynamic Type styles, bold semantic headings, and monospaced digits for frequency, date, total, marker, load, and reps columns.
Motion is limited to short insertion, expansion, and completion fades that become effectively immediate when Reduce Motion is enabled.

## Accessibility Contract

All interactive controls retain or exceed 44 by 44 point targets.
VoiceOver follows visual reading order and exposes workout occurrence, completion, frequency, load, reps, unit, and destructive-action context.
Dynamic Type can reflow headers and rows without clipping primary actions, including accessibility extra-large sizes.
Completion is communicated with symbol, label, weight, or row treatment in addition to coral.
Semantic colors maintain strong contrast in supported light and dark appearances.
Reduce Motion removes movement-based transitions while retaining clear state changes.

## Verification States

Verification covers Home, Plan, History, template creation and editing, active workout, and inline set entry on an iPhone 17 Pro at the 390 by 844 target.
Interaction verification covers frequency changes, duplicate weekly occurrences, independent completion, relaunch persistence, and Monday rollover.
Accessibility verification covers light and dark appearances, accessibility extra-large text, VoiceOver labels and order, 44-point targets, non-color completion cues, and Reduce Motion.
Visual QA compares the selected reference and matching implementation capture in one comparison input and blocks handoff for any remaining P0, P1, or P2 mismatch.
Automated verification includes the full simulator test suite and a clean generic iOS Simulator build.

## Non-goals

This work does not alter workout data models, planning semantics, persistence formats, migrations, logging behavior, repository visibility, release configuration, or deployment.
This work does not add gradients, bodybuilding imagery, decorative charts, glassmorphism, generic fitness rings, excessive borders, or ornamental animation.
This work does not incorporate unrelated hardening changes from unmerged pull request 4.
