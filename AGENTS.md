# Repository Guidelines

## Project Overview

This repository contains an iOS fitness tracking app built with Swift and SwiftUI. The MVP should be a minimal, clean, reliable workout logging app that feels like a better workout notebook or spreadsheet.

Focus first on logging workouts by date, adding exercises within a workout, recording all sets per exercise, tracking weight, reps, and optional notes, and showing simple progress analysis from historical data. Keep the app fast and easy to use in the gym.

## Product Scope

The target user trains regularly and wants to track strength progress without friction. Prioritize quick workout entry, historical performance per exercise, simple progress views, and a data model that can later support CSV or Excel imports.

Avoid social features, AI features, complicated onboarding, authentication, fake backend services, and unnecessary settings unless explicitly requested.

## Project Structure & Module Organization

Use a standard Xcode project structure. Keep source code grouped by responsibility:

- `Models/` for data types such as workouts, exercises, sets, and progress metrics.
- `Views/` for SwiftUI screens and reusable UI components.
- `ViewModels/` for state and presentation logic when needed.
- `Services/` or `Persistence/` for local storage, import, and data access code.
- `Tests/` for unit tests and focused model or calculation coverage.
- `Assets.xcassets/` for colors, icons, and app imagery.

Keep features grouped by domain when useful, for example `WorkoutLogging`, `ExerciseHistory`, or `Progress`.

## Build, Test, and Development Commands

Use Xcode for the primary development workflow. Once an `.xcodeproj` or `.xcworkspace` exists, document exact scheme names here.

Common commands:

- `open FitnessApp.xcodeproj` - opens the app in Xcode when the project exists.
- `xcodebuild -scheme FitnessApp -destination 'platform=iOS Simulator,name=iPhone 16' build` - builds from the command line.
- `xcodebuild test -scheme FitnessApp -destination 'platform=iOS Simulator,name=iPhone 16'` - runs tests.

Simulator refresh workflow:

- If the Simulator is still showing an older app version, quit the running FitnessApp instance in the Simulator first.
- Build the latest project version, then install and launch the freshly built app in the booted Simulator.
- Prefer a targeted app quit/build/run cycle before trying broader cleanup such as deleting DerivedData, resetting the Simulator, or changing project settings.

Keep the project buildable after every change.

## Coding Style & Naming Conventions

Write clear, idiomatic Swift. Prefer small SwiftUI views, simple state management, readable code, and separation between models, views, and view models. Avoid large monolithic views, premature architecture, hardcoded sample data in production logic, and unnecessary dependencies.

Use Apple naming conventions: types in `UpperCamelCase`, properties and functions in `lowerCamelCase`, and descriptive names such as `Workout`, `WorkoutExercise`, `SetEntry`, `ExerciseHistory`, and `ProgressMetric`.

Prefer native Apple frameworks. For persistence, start simple and local-first; use SwiftData or another native solution only when the data model needs it.

## MVP Features

Workout logging should support creating workouts for a date, adding exercises, adding multiple sets, entering weight and reps, adding notes, and editing or deleting entries.

Exercise history should let users select an exercise, view previous performances, see best sets or estimated progress, and compare the current workout with earlier workouts.

Analytics should stay simple: maximum weight over time, volume per exercise, total workout volume, sets per exercise or muscle group, and personal records.

## UX Principles

The app should be minimal, clean, fast, gym-friendly, and usable with one hand. Avoid complex dashboards in the MVP. Prefer simple lists, cards, clear navigation, and fast access to starting or continuing a workout, viewing workout history, and checking progress.

## Testing Guidelines

Add tests where reasonable for model logic, volume calculations, personal record detection, date grouping, and CSV parsing if import is added later. For UI-heavy changes, describe manual test steps for Xcode or Simulator.

Name tests after behavior, for example `WorkoutVolumeTests`, `PersonalRecordDetectionTests`, or `DateGroupingTests`.

## Commit & Pull Request Guidelines

Use meaningful, focused commit messages:

- `Add workout data models`
- `Create landing page layout`
- `Add workout history view`
- `Implement set logging form`
- `Add exercise progress chart`

Pull requests should include a short summary, test results, linked issues when relevant, and screenshots or recordings for visual changes. Do not commit generated build artifacts, local Xcode user settings, secrets, or derived data.

## Agent-Specific Instructions

Before implementing, inspect the existing files and make a short plan. Make the smallest useful change, preserve existing functionality, and explain important architectural decisions briefly. Prefer implementing one feature at a time.

Do not add dependencies without asking. Do not rewrite large parts of the app unless explicitly requested. When uncertain, choose the simpler implementation that supports the MVP.

## Future Features

Do not build these for the first MVP, but avoid blocking them: CSV or Excel import, exercise templates, workout templates, progress charts, AI-based workout insights, rep counting with phone motion sensors, cloud sync, and CSV export.

## Definition of Done

A task is done when the project still builds in Xcode, the new feature is reachable in the app, code is readable and reasonably structured, relevant tests or manual test notes are included, and no secrets or local files are added.
