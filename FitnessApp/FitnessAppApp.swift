//
//  FitnessAppApp.swift
//  FitnessApp
//
//  Created for the first MVP landing page.
//

import SwiftUI
import SwiftData

@main
struct FitnessAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Workout.self, WorkoutExercise.self, SetEntry.self])
    }
}
