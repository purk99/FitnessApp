//
//  ContentView.swift
//  FitnessApp
//
//  Landing page draft for the first MVP.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]

    @State private var selectedTab: AppTab = .home
    @State private var activeWorkout: Workout?
    @State private var saveErrorMessage: String?

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView(lastWorkout: workouts.first) {
                    activeWorkout = Workout(date: Date())
                    selectedTab = .log
                }
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(AppTab.home)

            NavigationStack {
                WorkoutLoggingView(workout: $activeWorkout, finishWorkout: finishWorkout)
            }
            .tabItem {
                Label("Loggen", systemImage: "clipboard")
            }
            .tag(AppTab.log)

            NavigationStack {
                AnalyticsPlaceholderView()
            }
            .tabItem {
                Label("Analyse", systemImage: "chart.bar")
            }
            .tag(AppTab.analytics)
        }
        .tint(AppColor.trainingGreen)
        .alert("Workout konnte nicht gespeichert werden", isPresented: saveErrorIsPresented) {
            Button("OK") {
                saveErrorMessage = nil
            }
        } message: {
            Text(saveErrorMessage ?? "Bitte versuche es erneut.")
        }
    }

    private var saveErrorIsPresented: Binding<Bool> {
        Binding(
            get: { saveErrorMessage != nil },
            set: { isPresented in
                if isPresented == false {
                    saveErrorMessage = nil
                }
            }
        )
    }

    private func finishWorkout(_ workout: Workout) {
        modelContext.insert(workout)

        do {
            try modelContext.save()
            activeWorkout = nil
            selectedTab = .home
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }
}

private enum AppTab {
    case home
    case log
    case analytics
}

private struct HomeView: View {
    let lastWorkout: Workout?
    let startWorkout: () -> Void

    var body: some View {
        ZStack {
            AppColor.pageBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    HeaderView()
                    StartWorkoutButton(action: startWorkout)
                    LastWorkoutCard(workout: lastWorkout)
                    ProgressCard()
                }
                .padding(.horizontal, 24)
                .padding(.top, 58)
                .padding(.bottom, 120)
            }
        }
        .hideNavigationBarForLanding()
    }
}

private struct HeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hey Dawid")
                .font(.system(size: 36, weight: .bold, design: .default))
                .foregroundStyle(.primaryText)

            Text("Was trainierst du heute?")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.secondaryText)
        }
        .padding(.top, 6)
    }
}

private struct StartWorkoutButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "plus")
                    .font(.system(size: 28, weight: .light))

                Text("Workout starten")
                    .font(.system(size: 21, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .foregroundStyle(.white)
            .background(AppColor.trainingGreen)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Workout starten")
    }
}

private struct LastWorkoutCard: View {
    let workout: Workout?

    var body: some View {
        DashboardCard {
            HStack(alignment: .top, spacing: 20) {
                IconBadge(systemName: "dumbbell.fill")

                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Letztes Workout")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(.secondaryText)

                        Text(workoutTitle)
                            .font(.system(size: 25, weight: .bold))
                            .foregroundStyle(.primaryText)
                    }

                    VStack(alignment: .leading, spacing: 15) {
                        MetadataRow(systemName: "calendar", text: dateText)
                        MetadataRow(systemName: "figure.strengthtraining.traditional", text: summaryText)
                    }

                    LinkRow(title: "Fortsetzen")
                        .padding(.top, 12)
                }
            }
        }
    }

    private var workoutTitle: String {
        guard let workout else {
            return "Noch kein Eintrag"
        }

        let trimmedTitle = workout.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? "Workout" : trimmedTitle
    }

    private var dateText: String {
        guard let workout else {
            return "Starte dein erstes Workout"
        }

        return workout.date.formatted(date: .abbreviated, time: .omitted)
    }

    private var summaryText: String {
        guard let workout else {
            return "Übungen und Sets erscheinen hier"
        }

        return "\(workout.exercises.count) Übungen · \(workout.totalSets) Sets"
    }
}

private struct ProgressCard: View {
    private let rows = [
        ProgressRow(icon: "dumbbell.fill", exercise: "Bankdrücken", value: "+2,5 kg"),
        ProgressRow(icon: "figure.strengthtraining.traditional", exercise: "Kniebeuge", value: "stabil"),
        ProgressRow(icon: "figure.pull", exercise: "Klimmzüge", value: "+2 Wdh.")
    ]

    var body: some View {
        DashboardCard {
            HStack(alignment: .top, spacing: 20) {
                IconBadge(systemName: "chart.line.uptrend.xyaxis")

                VStack(alignment: .leading, spacing: 18) {
                    Text("Fortschritt")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(.secondaryText)

                    VStack(spacing: 0) {
                        ForEach(rows) { row in
                            ProgressMetricRow(row: row)

                            if row.id != rows.last?.id {
                                Divider()
                                    .padding(.leading, 50)
                            }
                        }
                    }

                    LinkRow(title: "Analyse öffnen")
                        .padding(.top, 8)
                }
            }
        }
    }
}

private struct DashboardCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.cardBackground)
                    .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 10)
            )
    }
}

private struct IconBadge: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 22, weight: .medium))
            .foregroundStyle(AppColor.deepGreen)
            .frame(width: 54, height: 54)
            .background(Circle().fill(AppColor.badgeBackground))
    }
}

private struct MetadataRow: View {
    let systemName: String
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.secondaryText)
                .frame(width: 22)

            Text(text)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.secondaryText)
        }
    }
}

private struct LinkRow: View {
    let title: String

    var body: some View {
        Button {
        } label: {
            HStack(spacing: 14) {
                Text(title)
                    .font(.system(size: 18, weight: .medium))

                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundStyle(AppColor.trainingGreen)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

private struct ProgressMetricRow: View {
    let row: ProgressRow

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: row.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppColor.deepGreen)
                .frame(width: 30)

            (
                Text(row.exercise + ": ")
                    .foregroundStyle(.primaryText)
                + Text(row.value)
                    .foregroundStyle(AppColor.trainingGreen)
            )
            .font(.system(size: 16, weight: .regular))
            .lineLimit(1)
            .minimumScaleFactor(0.86)

            Spacer(minLength: 0)
        }
        .frame(height: 48)
    }
}

private struct ProgressRow: Identifiable {
    let id = UUID()
    let icon: String
    let exercise: String
    let value: String
}

private struct WorkoutLoggingView: View {
    @Binding var workout: Workout?
    let finishWorkout: (Workout) -> Void

    var body: some View {
        ZStack {
            AppColor.pageBackground
                .ignoresSafeArea()

            if workout == nil {
                EmptyWorkoutView {
                    workout = Workout(date: Date())
                }
            } else if let workout {
                WorkoutEditorView(workout: workout, finishWorkout: finishWorkout)
            }
        }
        .navigationTitle("Workout")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct EmptyWorkoutView: View {
    let startWorkout: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            IconBadge(systemName: "plus")

            VStack(spacing: 10) {
                Text("Noch kein Workout aktiv")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.primaryText)

                Text("Starte eine schnelle Einheit und erfasse Übungen, Sets, Gewicht und Wiederholungen.")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondaryText)
                    .multilineTextAlignment(.center)
            }

            StartWorkoutButton(action: startWorkout)
        }
        .padding(.horizontal, 24)
    }
}

private struct WorkoutEditorView: View {
    @Bindable var workout: Workout
    let finishWorkout: (Workout) -> Void
    @State private var newExerciseName = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                WorkoutSummaryCard(workout: workout)
                AddExerciseCard(newExerciseName: $newExerciseName, addExercise: addExercise)

                ForEach(workout.exercises) { exercise in
                    ExerciseLoggingCard(
                        exercise: exercise,
                        deleteExercise: { deleteExercise(exercise.id) }
                    )
                }

                if workout.exercises.isEmpty {
                    EmptyExerciseHint()
                }

                FinishWorkoutButton {
                    finishWorkout(workout)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 120)
        }
    }

    private func addExercise() {
        let trimmedName = newExerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else { return }

        workout.exercises.append(WorkoutExercise(name: trimmedName))
        newExerciseName = ""
    }

    private func deleteExercise(_ exerciseID: UUID) {
        workout.exercises.removeAll { $0.id == exerciseID }
    }
}

private struct FinishWorkoutButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 21, weight: .semibold))

                Text("Workout speichern & beenden")
                    .font(.system(size: 18, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .foregroundStyle(.white)
            .background(AppColor.trainingGreen)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Workout speichern und beenden")
    }
}

private struct WorkoutSummaryCard: View {
    @Bindable var workout: Workout

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 16) {
                    IconBadge(systemName: "figure.strengthtraining.traditional")

                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Workout-Name", text: $workout.title)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.primaryText)

                        DatePicker("Datum", selection: $workout.date, displayedComponents: .date)
                            .labelsHidden()
                            .tint(AppColor.trainingGreen)
                    }
                }

                HStack(spacing: 12) {
                    StatPill(title: "Übungen", value: "\(workout.exercises.count)")
                    StatPill(title: "Sets", value: "\(workout.totalSets)")
                    StatPill(title: "Volumen", value: volumeText)
                }

                TextField("Notiz zum Workout", text: $workout.notes, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.plain)
                    .padding(14)
                    .background(AppColor.inputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var volumeText: String {
        guard workout.totalVolume > 0 else { return "0 kg" }
        return "\(Int(workout.totalVolume.rounded())) kg"
    }
}

private struct StatPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.74)

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 58)
        .background(AppColor.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct AddExerciseCard: View {
    @Binding var newExerciseName: String
    let addExercise: () -> Void

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Übung hinzufügen")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primaryText)

                HStack(spacing: 12) {
                    TextField("z. B. Bankdrücken", text: $newExerciseName)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .onSubmit(addExercise)
                        .padding(14)
                        .background(AppColor.inputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Button(action: addExercise) {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(AppColor.trainingGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Übung hinzufügen")
                }
            }
        }
    }
}

private struct ExerciseLoggingCard: View {
    @Bindable var exercise: WorkoutExercise
    let deleteExercise: () -> Void

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Übung", text: $exercise.name)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.primaryText)

                        Text("\(exercise.sets.count) Sets")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondaryText)
                    }

                    Spacer()

                    Button(action: deleteExercise) {
                        Image(systemName: "trash")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.secondaryText)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Übung löschen")
                }

                VStack(spacing: 10) {
                    ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                        SetEntryRow(
                            setNumber: index + 1,
                            set: set,
                            deleteSet: { deleteSet(set.id) },
                            canDelete: exercise.sets.count > 1
                        )
                    }
                }

                Button(action: addSet) {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                        Text("Set hinzufügen")
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppColor.trainingGreen)
                }
                .buttonStyle(.plain)

                TextField("Notiz zur Übung", text: $exercise.notes, axis: .vertical)
                    .lineLimit(1...3)
                    .textFieldStyle(.plain)
                    .padding(14)
                    .background(AppColor.inputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private func addSet() {
        exercise.sets.append(SetEntry())
    }

    private func deleteSet(_ setID: UUID) {
        guard exercise.sets.count > 1 else { return }
        exercise.sets.removeAll { $0.id == setID }
    }
}

private struct SetEntryRow: View {
    let setNumber: Int
    @Bindable var set: SetEntry
    let deleteSet: () -> Void
    let canDelete: Bool

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
            GridRow {
                Text("\(setNumber)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppColor.trainingGreen)
                    .frame(width: 28)

                WorkoutNumberField(title: "kg", text: weightText)
                WorkoutNumberField(title: "Wdh.", text: repsText)

                Button(action: deleteSet) {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(canDelete ? .secondaryText : Color.clear)
                        .frame(width: 28, height: 42)
                }
                .buttonStyle(.plain)
                .disabled(canDelete == false)
                .accessibilityLabel("Set löschen")
            }

            GridRow {
                Color.clear
                    .frame(width: 28, height: 1)

                TextField("Notiz", text: $set.notes)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .background(AppColor.inputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .gridCellColumns(2)

                Color.clear
                    .frame(width: 28, height: 1)
            }
        }
    }

    private var weightText: Binding<String> {
        Binding(
            get: {
                guard let weight = set.weight else {
                    return ""
                }

                return weight.formatted(.number.precision(.fractionLength(0...2)))
            },
            set: { newValue in
                set.weight = WorkoutInputParser.double(from: newValue)
            }
        )
    }

    private var repsText: Binding<String> {
        Binding(
            get: {
                guard let reps = set.reps else {
                    return ""
                }

                return "\(reps)"
            },
            set: { newValue in
                set.reps = WorkoutInputParser.integer(from: newValue)
            }
        )
    }
}

private enum WorkoutInputParser {
    static func double(from text: String) -> Double? {
        let normalizedText = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        guard normalizedText.isEmpty == false else {
            return nil
        }

        return Double(normalizedText)
    }

    static func integer(from text: String) -> Int? {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizedText.isEmpty == false else {
            return nil
        }

        return Int(normalizedText)
    }
}

private struct WorkoutNumberField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        TextField(title, text: $text)
            .keyboardType(.decimalPad)
            .font(.system(size: 17, weight: .medium))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 10)
            .frame(height: 42)
            .background(AppColor.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct EmptyExerciseHint: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "clipboard")
                .font(.system(size: 32, weight: .regular))
                .foregroundStyle(AppColor.trainingGreen)

            Text("Füge die erste Übung hinzu, um Sets zu loggen.")
                .font(.system(size: 16))
                .foregroundStyle(.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
    }
}

private struct AnalyticsPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundStyle(AppColor.trainingGreen)

            Text("Analyse")
                .font(.title.bold())

            Text("Hier landen einfache Trends wie Maximalgewicht, Volumen und persönliche Rekorde.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .navigationTitle("Analyse")
    }
}

private enum AppColor {
    static let pageBackground = Color(red: 0.985, green: 0.982, blue: 0.972)
    static let cardBackground = Color.white
    static let badgeBackground = Color(red: 0.945, green: 0.953, blue: 0.945)
    static let inputBackground = Color(red: 0.958, green: 0.957, blue: 0.945)
    static let trainingGreen = Color(red: 0.376, green: 0.522, blue: 0.403)
    static let deepGreen = Color(red: 0.129, green: 0.231, blue: 0.164)
}

private extension ShapeStyle where Self == Color {
    static var primaryText: Color { Color(red: 0.055, green: 0.055, blue: 0.06) }
    static var secondaryText: Color { Color(red: 0.35, green: 0.35, blue: 0.38) }
    static var cardBackground: Color { AppColor.cardBackground }
}

private extension View {
    @ViewBuilder
    func hideNavigationBarForLanding() -> some View {
        #if os(iOS)
        self
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .modelContainer(for: [Workout.self, WorkoutExercise.self, SetEntry.self], inMemory: true)
    }
}
