//
//  Workout.swift
//  FitnessApp
//
//  SwiftData models for local workout persistence.
//

import Foundation
import SwiftData

@Model
final class Workout {
    var id: UUID
    var date: Date
    var title: String
    var notes: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade)
    var exercises: [WorkoutExercise]

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        title: String = "",
        notes: String = "",
        createdAt: Date = Date(),
        exercises: [WorkoutExercise] = []
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.notes = notes
        self.createdAt = createdAt
        self.exercises = exercises
    }

    var totalSets: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }

    var totalVolume: Double {
        exercises.reduce(0) { partialResult, exercise in
            partialResult + exercise.sets.reduce(0) { $0 + $1.volume }
        }
    }
}

@Model
final class WorkoutExercise {
    var id: UUID
    var name: String
    var notes: String

    @Relationship(deleteRule: .cascade)
    var sets: [SetEntry]

    init(
        id: UUID = UUID(),
        name: String,
        notes: String = "",
        sets: [SetEntry] = [SetEntry()]
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.sets = sets
    }
}

@Model
final class SetEntry {
    var id: UUID
    var weight: Double?
    var reps: Int?
    var notes: String

    init(
        id: UUID = UUID(),
        weight: Double? = nil,
        reps: Int? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.notes = notes
    }

    var volume: Double {
        guard let weight, let reps else {
            return 0
        }

        return weight * Double(reps)
    }
}
