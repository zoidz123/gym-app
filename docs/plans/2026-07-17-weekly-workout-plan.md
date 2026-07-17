# Weekly Workout Plan Contract

## Goal

Make the Plan tab the source of truth for the current week's intentionally scheduled workouts.
Keep reusable workout definitions while ensuring that every planned row is an independent occurrence with its own completion state.

## Current Gap

The Plan tab only edits six bundled workout templates.
It cannot create, delete, duplicate, or reorder planned workout occurrences.
Home independently hardcodes six unique workout names instead of reading the user's plan.
Home infers completion by matching the first history session with the same workout title inside the current Monday-to-Monday interval.
Repeated workouts such as two Zone 2 Cardio sessions therefore collapse into one status.

## Data Contract

`WorkoutTemplate` remains the reusable workout definition.
It retains stable exercise IDs, exercise order, targets, and shared superset group IDs.

`WeeklyWorkoutPlan` stores one Monday-based week and its ordered `PlannedWorkoutOccurrence` values.
Each occurrence has a unique ID, a template ID, and an order.
Two occurrences may reference the same template while remaining independent plan rows.

`WorkoutSession.plannedOccurrenceID` is optional.
A session started or logged from a planned Home occurrence carries that occurrence ID.
An ad-hoc workout or legacy history entry may continue to have no occurrence ID.
Home completion must match occurrence IDs and must never deduplicate by workout name, exercise identity, or template ID.

## Product Behavior

The Plan tab represents the current week's ordered workout occurrences.
It provides a clear Add Workout action that can create a new reusable workout or add an existing workout again.
Creating or editing a workout supports naming it and adding, removing, reordering, and configuring catalog-backed exercises.
Superset creation assigns one shared group ID to both exercises and preserves existing exercise identity semantics.

Each occurrence supports editing its reusable workout, adding another occurrence, reordering, and removal.
Removing an occurrence requires clear destructive confirmation and does not delete the reusable workout or history.

Home reads the current weekly plan directly.
It shows the exact planned occurrence count and a separate completion affordance for every occurrence.
Starting or logging an occurrence associates the resulting session with that occurrence only.
The existing Change Workout and history flows remain valid ad-hoc paths with no occurrence association.

## Week Boundary and Rollover

Weeks start Monday using the user's current calendar and time zone.
On first access to a Monday week that has no stored plan, the app copies the latest prior plan with fresh occurrence IDs.
Fresh IDs reset checkmarks without changing reusable workout definitions.
If a week already exists, the app never regenerates, replaces, or overwrites it.
Past weekly plans and workout history remain stored.

## Migration

Existing JSON decodes missing weekly plans and missing session occurrence links safely.
The existing templates become the initial ordered weekly plan without changing template, exercise, or superset identities.
During one-time migration, existing sessions inside a stored plan week may be associated by normalized workout name.
Migration consumes each candidate session once so duplicate occurrences cannot share one completion.
Normal runtime access never title-matches new ad-hoc sessions into the plan.

## Verification

Focused tests cover create, edit, delete, reorder, persistence reload, legacy migration, duplicate occurrences, independent completion, Monday rollover, Home counts and statuses, and ad-hoc history isolation.
The simulator E2E creates Leg Day with catalog exercises, adds a second Zone 2 Cardio occurrence, completes only one Zone 2 occurrence, verifies the Home count and exactly one checkmark, relaunches, and verifies persistence.
The final verification includes unit tests, a simulator build, light and dark mode review, small-screen and dynamic-type checks, and review screenshots.

## Primary Risk

Multiple occurrences that reference one reusable template intentionally share exercise composition.
A user creates a new workout definition when occurrences need different exercise compositions.
