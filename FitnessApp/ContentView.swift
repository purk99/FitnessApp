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
    @AppStorage("customExerciseTemplates") private var customExerciseTemplatesData = "[]"

    @State private var selectedTab: AppTab = .home
    @State private var activeWorkout: Workout?
    @State private var saveErrorMessage: String?

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView(
                    lastWorkout: workouts.first,
                    startWorkout: startWorkout,
                    continueWorkout: continueWorkout
                )
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(AppTab.home)

            NavigationStack {
                WorkoutLoggingView(
                    workout: $activeWorkout,
                    workouts: workouts,
                    exerciseTemplates: exerciseTemplates,
                    finishWorkout: finishWorkout,
                    saveExerciseTemplate: saveExerciseTemplate,
                    continueWorkout: continueWorkout
                )
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

    private var exerciseTemplates: [ExerciseTemplatePreset] {
        ExerciseTemplatePreset.standardTemplates + customExerciseTemplates
    }

    private var customExerciseTemplates: [ExerciseTemplatePreset] {
        guard let data = customExerciseTemplatesData.data(using: .utf8),
              let templates = try? JSONDecoder().decode([ExerciseTemplatePreset].self, from: data) else {
            return []
        }

        return templates.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func startWorkout() {
        activeWorkout = Workout(date: Date())
        selectedTab = .log
    }

    private func continueWorkout(_ workout: Workout) {
        activeWorkout = workout
        selectedTab = .log
    }

    private func finishWorkout(_ workout: Workout) {
        if workouts.contains(where: { $0.id == workout.id }) == false {
            modelContext.insert(workout)
        }

        do {
            try modelContext.save()
            activeWorkout = nil
            selectedTab = .home
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }

    private func saveExerciseTemplate(_ name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else { return }

        let alreadyExists = exerciseTemplates.contains {
            $0.name.compare(trimmedName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        guard alreadyExists == false else { return }

        var templates = customExerciseTemplates
        templates.append(
            ExerciseTemplatePreset(
                name: trimmedName,
                category: "Eigene",
                isCustom: true
            )
        )

        if let data = try? JSONEncoder().encode(templates),
           let encodedTemplates = String(data: data, encoding: .utf8) {
            customExerciseTemplatesData = encodedTemplates
        }
    }
}

private struct ExerciseTemplatePreset: Identifiable, Codable, Hashable {
    var id: String { "\(category)-\(name)" }
    let name: String
    let category: String
    let isCustom: Bool

    init(name: String, category: String, isCustom: Bool = false) {
        self.name = name
        self.category = category
        self.isCustom = isCustom
    }

    static let standardTemplates: [ExerciseTemplatePreset] = [
        ExerciseTemplatePreset(name: "Bankdrücken", category: "Brust"),
        ExerciseTemplatePreset(name: "Schrägbankdrücken", category: "Brust"),
        ExerciseTemplatePreset(name: "Kniebeuge", category: "Beine"),
        ExerciseTemplatePreset(name: "Beinpresse", category: "Beine"),
        ExerciseTemplatePreset(name: "Kreuzheben", category: "Rücken"),
        ExerciseTemplatePreset(name: "Latzug", category: "Rücken"),
        ExerciseTemplatePreset(name: "Kabelzug Rudern", category: "Rücken"),
        ExerciseTemplatePreset(name: "Klimmzüge", category: "Rücken"),
        ExerciseTemplatePreset(name: "Schulterdrücken", category: "Schultern"),
        ExerciseTemplatePreset(name: "Seitheben", category: "Schultern"),
        ExerciseTemplatePreset(name: "Trizepsdrücken am Kabelzug", category: "Arme"),
        ExerciseTemplatePreset(name: "Bizepscurls", category: "Arme")
    ]
}

private enum AppTab {
    case home
    case log
    case analytics
}

private struct HomeView: View {
    let lastWorkout: Workout?
    let startWorkout: () -> Void
    let continueWorkout: (Workout) -> Void

    var body: some View {
        ZStack {
            AppColor.pageBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    HeaderView()
                    StartWorkoutButton(action: startWorkout)
                    LastWorkoutCard(
                        workout: lastWorkout,
                        continueWorkout: continueWorkout
                    )
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
    let continueWorkout: (Workout) -> Void

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

                    LinkRow(title: "Fortsetzen") {
                        if let workout {
                            continueWorkout(workout)
                        }
                    }
                    .disabled(workout == nil)
                    .opacity(workout == nil ? 0.45 : 1)
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
    let action: () -> Void

    init(title: String, action: @escaping () -> Void = {}) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
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
    let workouts: [Workout]
    let exerciseTemplates: [ExerciseTemplatePreset]
    let finishWorkout: (Workout) -> Void
    let saveExerciseTemplate: (String) -> Void
    let continueWorkout: (Workout) -> Void
    @State private var historyFilter: WorkoutHistoryFilter = .all

    var body: some View {
        ZStack {
            AppColor.pageBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    if workout == nil {
                        EmptyWorkoutView {
                            workout = Workout(date: Date())
                        }
                    } else if let workout {
                        WorkoutEditorView(
                            workout: workout,
                            exerciseTemplates: exerciseTemplates,
                            finishWorkout: finishWorkout,
                            saveExerciseTemplate: saveExerciseTemplate
                        )
                    }

                    WorkoutHistorySection(
                        workouts: workouts,
                        selectedFilter: $historyFilter,
                        continueWorkout: continueWorkout
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 120)
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
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

private struct WorkoutEditorView: View {
    @Bindable var workout: Workout
    let exerciseTemplates: [ExerciseTemplatePreset]
    let finishWorkout: (Workout) -> Void
    let saveExerciseTemplate: (String) -> Void
    @State private var newExerciseName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            WorkoutSummaryCard(workout: workout)

            ForEach(workout.exercises) { exercise in
                ExerciseLoggingCard(
                    exercise: exercise,
                    deleteExercise: { deleteExercise(exercise.id) }
                )
            }

            if workout.exercises.isEmpty {
                EmptyExerciseHint()
            }

            AddExerciseCard(
                newExerciseName: $newExerciseName,
                templates: exerciseTemplates,
                addExercise: addExercise,
                addTemplateExercise: addTemplateExercise,
                saveTemplate: saveTemplate,
                canSaveTemplate: canSaveTemplate
            )

            FinishWorkoutButton {
                finishWorkout(workout)
            }
        }
    }

    private func addExercise() {
        let trimmedName = newExerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else { return }

        workout.exercises.append(WorkoutExercise(name: trimmedName))
        newExerciseName = ""
    }

    private func addTemplateExercise(_ template: ExerciseTemplatePreset) {
        workout.exercises.append(WorkoutExercise(name: template.name))
    }

    private var canSaveTemplate: Bool {
        let trimmedName = newExerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else { return false }

        return exerciseTemplates.contains {
            $0.name.compare(trimmedName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        } == false
    }

    private func saveTemplate() {
        let trimmedName = newExerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSaveTemplate else { return }
        saveExerciseTemplate(trimmedName)
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
    let templates: [ExerciseTemplatePreset]
    let addExercise: () -> Void
    let addTemplateExercise: (ExerciseTemplatePreset) -> Void
    let saveTemplate: () -> Void
    let canSaveTemplate: Bool

    private var groupedTemplates: [(category: String, templates: [ExerciseTemplatePreset])] {
        Dictionary(grouping: templates, by: \.category)
            .map { category, templates in
                (
                    category,
                    templates.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                )
            }
            .sorted { lhs, rhs in
                categorySortValue(lhs.category) < categorySortValue(rhs.category)
            }
    }

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Übung hinzufügen")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.primaryText)

                        Text("Vorlage wählen oder eigene Übung eintragen.")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondaryText)
                    }

                    Spacer()

                    Menu {
                        ForEach(groupedTemplates, id: \.category) { group in
                            Section(group.category) {
                                ForEach(group.templates) { template in
                                    Button(template.name) {
                                        addTemplateExercise(template)
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppColor.trainingGreen)
                            .frame(width: 42, height: 42)
                            .background(AppColor.inputBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .accessibilityLabel("Übungsvorlagen öffnen")
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(templates.prefix(8)) { template in
                            Button {
                                addTemplateExercise(template)
                            } label: {
                                Text(template.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(AppColor.trainingGreen)
                                    .lineLimit(1)
                                    .padding(.horizontal, 14)
                                    .frame(height: 38)
                                    .background(AppColor.inputBackground)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(template.name) hinzufügen")
                        }
                    }
                }

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

                Button(action: saveTemplate) {
                    Label("Als Vorlage speichern", systemImage: "bookmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColor.trainingGreen)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(AppColor.inputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(canSaveTemplate == false)
                .opacity(canSaveTemplate ? 1 : 0.45)
                .accessibilityLabel("Übung als Vorlage speichern")
            }
        }
    }

    private func categorySortValue(_ category: String) -> String {
        let order = ["Brust", "Beine", "Rücken", "Schultern", "Arme", "Eigene"]
        guard let index = order.firstIndex(of: category) else {
            return "9-\(category)"
        }

        return "\(index)-\(category)"
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

                HStack(spacing: 12) {
                    Button(action: addSet) {
                        Label("Set", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ExerciseActionButtonStyle())
                    .accessibilityLabel("Leeres Set hinzufügen")

                    Button(action: copyPreviousSet) {
                        Label("Vorheriges", systemImage: "arrow.down.doc.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ExerciseActionButtonStyle())
                    .disabled(canCopyPreviousSet == false)
                    .opacity(canCopyPreviousSet ? 1 : 0.45)
                    .accessibilityLabel("Vorherige Set-Werte übernehmen")
                }

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

    private var canCopyPreviousSet: Bool {
        guard let previousSet = exercise.sets.last else {
            return false
        }

        return previousSet.weight != nil || previousSet.reps != nil
    }

    private func copyPreviousSet() {
        guard let previousSet = exercise.sets.last else {
            return
        }

        exercise.sets.append(
            SetEntry(
                weight: previousSet.weight,
                reps: previousSet.reps
            )
        )
    }

    private func deleteSet(_ setID: UUID) {
        guard exercise.sets.count > 1 else { return }
        exercise.sets.removeAll { $0.id == setID }
    }
}

private struct ExerciseActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(AppColor.trainingGreen)
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(AppColor.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(configuration.isPressed ? 0.72 : 1)
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

private enum WorkoutHistoryFilter: String, CaseIterable, Identifiable {
    case all = "Alle"
    case year = "Jahr"
    case month = "Monat"
    case week = "Woche"

    var id: String { rawValue }
}

private struct WorkoutHistorySection: View {
    let workouts: [Workout]
    @Binding var selectedFilter: WorkoutHistoryFilter
    let continueWorkout: (Workout) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 155), spacing: 14)
    ]

    private var filteredWorkouts: [Workout] {
        workouts.filter { workout in
            selectedFilter.contains(workout.date)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Letzte Workouts")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.primaryText)

                    Text("\(filteredWorkouts.count) Einträge")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondaryText)
                }

                Spacer()
            }

            Picker("Zeitraum", selection: $selectedFilter) {
                ForEach(WorkoutHistoryFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            if filteredWorkouts.isEmpty {
                EmptyWorkoutHistoryCard(filter: selectedFilter)
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(filteredWorkouts) { workout in
                        NavigationLink {
                            WorkoutDetailView(
                                workout: workout,
                                continueWorkout: continueWorkout
                            )
                        } label: {
                            WorkoutHistoryTile(workout: workout)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct WorkoutDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let workout: Workout
    let continueWorkout: (Workout) -> Void

    var body: some View {
        ZStack {
            AppColor.pageBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    WorkoutReadOnlySummaryCard(workout: workout)

                    if workout.exercises.isEmpty {
                        EmptyReadOnlyExercisesCard()
                    } else {
                        ForEach(workout.exercises) { exercise in
                            ReadOnlyExerciseCard(exercise: exercise)
                        }
                    }

                    Button {
                        continueWorkout(workout)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 21, weight: .semibold))

                            Text("Fortsetzen / bearbeiten")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .foregroundStyle(.white)
                        .background(AppColor.trainingGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Workout fortsetzen oder bearbeiten")
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 120)
            }
        }
        .navigationTitle(workoutTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var workoutTitle: String {
        let trimmedTitle = workout.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? "Workout" : trimmedTitle
    }
}

private struct WorkoutReadOnlySummaryCard: View {
    let workout: Workout

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 16) {
                    IconBadge(systemName: "figure.strengthtraining.traditional")

                    VStack(alignment: .leading, spacing: 8) {
                        Text(workoutTitle)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.primaryText)

                        Text(workout.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.secondaryText)
                    }
                }

                HStack(spacing: 12) {
                    StatPill(title: "Übungen", value: "\(workout.exercises.count)")
                    StatPill(title: "Sets", value: "\(workout.totalSets)")
                    StatPill(title: "Volumen", value: volumeText)
                }

                if workout.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                    Text(workout.notes)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondaryText)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColor.inputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    private var workoutTitle: String {
        let trimmedTitle = workout.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? "Workout" : trimmedTitle
    }

    private var volumeText: String {
        guard workout.totalVolume > 0 else { return "0 kg" }
        return "\(Int(workout.totalVolume.rounded())) kg"
    }
}

private struct ReadOnlyExerciseCard: View {
    let exercise: WorkoutExercise

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(exerciseTitle)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.primaryText)

                    Text("\(exercise.sets.count) Sets")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondaryText)
                }

                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Text("Set")
                            .frame(width: 34, alignment: .leading)
                        Text("kg")
                            .frame(maxWidth: .infinity)
                        Text("Wdh.")
                            .frame(maxWidth: .infinity)
                        Text("Volumen")
                            .frame(maxWidth: .infinity)
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondaryText)

                    ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                        ReadOnlySetRow(setNumber: index + 1, set: set)
                    }
                }

                if exercise.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                    Text(exercise.notes)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondaryText)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColor.inputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    private var exerciseTitle: String {
        let trimmedName = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "Übung" : trimmedName
    }
}

private struct ReadOnlySetRow: View {
    let setNumber: Int
    let set: SetEntry

    var body: some View {
        HStack(spacing: 10) {
            Text("\(setNumber)")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppColor.trainingGreen)
                .frame(width: 34, alignment: .leading)

            ReadOnlySetValue(text: weightText)
            ReadOnlySetValue(text: repsText)
            ReadOnlySetValue(text: volumeText)
        }
        .accessibilityElement(children: .combine)
    }

    private var weightText: String {
        guard let weight = set.weight else {
            return "-"
        }

        return weight.formatted(.number.precision(.fractionLength(0...2)))
    }

    private var repsText: String {
        guard let reps = set.reps else {
            return "-"
        }

        return "\(reps)"
    }

    private var volumeText: String {
        guard set.volume > 0 else {
            return "-"
        }

        return "\(Int(set.volume.rounded()))"
    }
}

private struct ReadOnlySetValue: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.primaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(AppColor.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct EmptyReadOnlyExercisesCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.clipboard")
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(AppColor.trainingGreen)

            Text("Keine Übungen gespeichert")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.cardBackground)
        )
    }
}

private struct WorkoutHistoryTile: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                IconBadge(systemName: "dumbbell.fill")
                    .scaleEffect(0.78, anchor: .topLeading)
                    .frame(width: 42, height: 42, alignment: .topLeading)

                Spacer()

                Text(workout.date.formatted(.dateTime.day().month(.abbreviated)))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondaryText)
                    .lineLimit(1)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(workoutTitle)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)

                Text(exercisePreview)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondaryText)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                HistoryStatPill(value: "\(workout.exercises.count)", label: "Übungen")
                HistoryStatPill(value: "\(workout.totalSets)", label: "Sets")
            }

            HStack(spacing: 6) {
                Image(systemName: "sum")
                    .font(.system(size: 12, weight: .semibold))

                Text(volumeText)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(AppColor.trainingGreen)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.cardBackground)
                .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 8)
        )
        .accessibilityElement(children: .combine)
    }

    private var workoutTitle: String {
        let trimmedTitle = workout.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? "Workout" : trimmedTitle
    }

    private var exercisePreview: String {
        let names = workout.exercises
            .map(\.name)
            .filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
            .prefix(2)

        guard names.isEmpty == false else {
            return "Noch keine Übungen"
        }

        return names.joined(separator: ", ")
    }

    private var volumeText: String {
        guard workout.totalVolume > 0 else {
            return "0 kg Volumen"
        }

        return "\(Int(workout.totalVolume.rounded())) kg Volumen"
    }
}

private struct HistoryStatPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.primaryText)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(AppColor.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct EmptyWorkoutHistoryCard: View {
    let filter: WorkoutHistoryFilter

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(AppColor.trainingGreen)

            Text("Noch keine gespeicherten Workouts")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.primaryText)

            Text(emptyText)
                .font(.system(size: 15))
                .foregroundStyle(.secondaryText)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.cardBackground)
        )
    }

    private var emptyText: String {
        switch filter {
        case .all:
            return "Sobald du ein Workout speicherst, erscheint es hier."
        case .year:
            return "Für dieses Jahr gibt es noch keine gespeicherten Workouts."
        case .month:
            return "Für diesen Monat gibt es noch keine gespeicherten Workouts."
        case .week:
            return "Für diese Woche gibt es noch keine gespeicherten Workouts."
        }
    }
}

private extension WorkoutHistoryFilter {
    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let now = Date()

        switch self {
        case .all:
            return true
        case .year:
            return calendar.isDate(date, equalTo: now, toGranularity: .year)
        case .month:
            return calendar.isDate(date, equalTo: now, toGranularity: .month)
        case .week:
            return calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear)
        }
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
