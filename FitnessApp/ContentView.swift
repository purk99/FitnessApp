//
//  ContentView.swift
//  FitnessApp
//
//  Landing page draft for the first MVP.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @AppStorage("customExerciseTemplates") private var customExerciseTemplatesData = "[]"
    @AppStorage("workoutPlanTemplates") private var workoutPlanTemplatesData = ""

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
                    workoutPlans: workoutPlans,
                    finishWorkout: finishWorkout,
                    cancelWorkout: cancelWorkout,
                    saveExerciseTemplate: saveExerciseTemplate,
                    saveWorkoutPlan: saveWorkoutPlan,
                    deleteWorkoutPlan: deleteWorkoutPlan,
                    continueWorkout: continueWorkout,
                    importWorkouts: importWorkouts,
                    deleteAllWorkouts: deleteAllWorkouts
                )
            }
            .tabItem {
                Label("Loggen", systemImage: "clipboard")
            }
            .tag(AppTab.log)

            NavigationStack {
                AnalyticsView(
                    workouts: workouts,
                    continueWorkout: continueWorkout
                )
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

    private var workoutPlans: [WorkoutPlanTemplate] {
        guard workoutPlanTemplatesData.isEmpty == false else {
            return WorkoutPlanTemplate.starterPlans
        }

        guard let data = workoutPlanTemplatesData.data(using: .utf8),
              let plans = try? JSONDecoder().decode([WorkoutPlanTemplate].self, from: data) else {
            return WorkoutPlanTemplate.starterPlans
        }

        return plans
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

    private func cancelWorkout() {
        activeWorkout = nil
        selectedTab = .log
    }

    private func importWorkouts(_ importedWorkouts: [Workout]) {
        for workout in importedWorkouts {
            modelContext.insert(workout)
        }

        do {
            try modelContext.save()
            selectedTab = .log
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }

    private func deleteAllWorkouts() {
        activeWorkout = nil

        for workout in workouts {
            modelContext.delete(workout)
        }

        do {
            try modelContext.save()
            selectedTab = .log
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

    private func saveWorkoutPlan(_ plan: WorkoutPlanTemplate) {
        let trimmedName = plan.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let exerciseNames = plan.exerciseNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }

        guard trimmedName.isEmpty == false else { return }

        let updatedPlan = WorkoutPlanTemplate(
            id: plan.id,
            name: trimmedName,
            exerciseNames: exerciseNames
        )

        var plans = workoutPlans
        if let existingIndex = plans.firstIndex(where: { $0.id == updatedPlan.id }) {
            plans[existingIndex] = updatedPlan
        } else {
            plans.append(updatedPlan)
        }

        persistWorkoutPlans(plans)
    }

    private func deleteWorkoutPlan(_ planID: UUID) {
        persistWorkoutPlans(workoutPlans.filter { $0.id != planID })
    }

    private func persistWorkoutPlans(_ plans: [WorkoutPlanTemplate]) {
        if let data = try? JSONEncoder().encode(plans),
           let encodedPlans = String(data: data, encoding: .utf8) {
            workoutPlanTemplatesData = encodedPlans
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

private struct WorkoutPlanTemplate: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var exerciseNames: [String]

    init(
        id: UUID = UUID(),
        name: String,
        exerciseNames: [String]
    ) {
        self.id = id
        self.name = name
        self.exerciseNames = exerciseNames
    }

    var exerciseCountText: String {
        "\(exerciseNames.count) Übungen"
    }

    func makeWorkout() -> Workout {
        Workout(
            date: Date(),
            title: name,
            notes: "Gestartet aus Workout-Plan",
            exercises: exerciseNames.map { name in
                WorkoutExercise(name: name, sets: [SetEntry()])
            }
        )
    }

    static let starterPlans: [WorkoutPlanTemplate] = [
        WorkoutPlanTemplate(
            id: UUID(uuidString: "8E268797-8F6C-4077-B874-C76C85212A51") ?? UUID(),
            name: "Push",
            exerciseNames: [
                "Bankdrücken",
                "Schrägbankdrücken",
                "Schulterdrücken",
                "Seitheben",
                "Trizepsdrücken am Kabelzug"
            ]
        ),
        WorkoutPlanTemplate(
            id: UUID(uuidString: "683988F4-2D25-4705-BF4C-15487655F6B0") ?? UUID(),
            name: "Pull",
            exerciseNames: [
                "Latzug",
                "Kabelzug Rudern",
                "Klimmzüge",
                "Face Pulls",
                "Bizepscurls"
            ]
        ),
        WorkoutPlanTemplate(
            id: UUID(uuidString: "F21C5B2A-2D4E-4B7D-98B5-93B57D724595") ?? UUID(),
            name: "Beine",
            exerciseNames: [
                "Kniebeuge",
                "Beinpresse",
                "Beinbeuger",
                "Wadenpresse"
            ]
        )
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
    var title = "Workout starten"
    var systemImage = "plus"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .light))

                Text(title)
                    .font(.system(size: 21, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
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
    let workoutPlans: [WorkoutPlanTemplate]
    let finishWorkout: (Workout) -> Void
    let cancelWorkout: () -> Void
    let saveExerciseTemplate: (String) -> Void
    let saveWorkoutPlan: (WorkoutPlanTemplate) -> Void
    let deleteWorkoutPlan: (UUID) -> Void
    let continueWorkout: (Workout) -> Void
    let importWorkouts: ([Workout]) -> Void
    let deleteAllWorkouts: () -> Void
    @State private var historyFilter: WorkoutHistoryFilter = .all
    @State private var selectedPlanID: UUID?
    @State private var editingWorkoutPlan: WorkoutPlanTemplate?
    @State private var isImporterPresented = false
    @State private var importPreviewWorkouts: [Workout] = []
    @State private var importErrorMessage: String?
    @State private var isDeleteConfirmationPresented = false

    var body: some View {
        ZStack {
            AppColor.pageBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    if workout == nil {
                        EmptyWorkoutView(
                            startWorkout: {
                            workout = Workout(date: Date())
                            },
                            workoutPlans: workoutPlans,
                            selectedPlanID: $selectedPlanID,
                            startWorkoutPlan: startWorkoutPlan,
                            editSelectedPlan: editSelectedPlan,
                            createWorkoutPlan: createWorkoutPlan,
                            importCSV: {
                                isImporterPresented = true
                            },
                            deleteAllWorkouts: {
                                isDeleteConfirmationPresented = true
                            },
                            hasWorkouts: workouts.isEmpty == false
                        )
                    } else if let workout {
                        WorkoutEditorView(
                            workout: workout,
                            exerciseTemplates: exerciseTemplates,
                            finishWorkout: finishWorkout,
                            cancelWorkout: cancelWorkout,
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
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false,
            onCompletion: handleImportSelection
        )
        .sheet(isPresented: importPreviewIsPresented) {
            LegacyImportPreviewView(
                workouts: importPreviewWorkouts,
                confirmImport: confirmImportPreview,
                cancelImport: cancelImportPreview
            )
        }
        .sheet(item: $editingWorkoutPlan) { plan in
            WorkoutPlanEditorView(
                plan: plan,
                exerciseTemplates: exerciseTemplates,
                savePlan: saveWorkoutPlan,
                deletePlan: deleteWorkoutPlan,
                startPlan: startWorkoutPlan
            )
        }
        .alert("CSV konnte nicht importiert werden", isPresented: importErrorIsPresented) {
            Button("OK") {
                importErrorMessage = nil
            }
        } message: {
            Text(importErrorMessage ?? "Bitte prüfe die CSV-Datei.")
        }
        .confirmationDialog(
            "Alle Workout-Daten löschen?",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Alle Workouts löschen", role: .destructive) {
                deleteAllWorkouts()
            }

            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Diese Prototyp-Aktion entfernt alle gespeicherten Workouts lokal aus der App.")
        }
    }

    private var importPreviewIsPresented: Binding<Bool> {
        Binding(
            get: { importPreviewWorkouts.isEmpty == false },
            set: { isPresented in
                if isPresented == false {
                    importPreviewWorkouts = []
                }
            }
        )
    }

    private var selectedPlan: WorkoutPlanTemplate? {
        workoutPlans.first { $0.id == selectedPlanID } ?? workoutPlans.first
    }

    private var importErrorIsPresented: Binding<Bool> {
        Binding(
            get: { importErrorMessage != nil },
            set: { isPresented in
                if isPresented == false {
                    importErrorMessage = nil
                }
            }
        )
    }

    private func handleImportSelection(_ result: Result<[URL], Error>) {
        do {
            guard let selectedURL = try result.get().first else {
                return
            }

            let didAccess = selectedURL.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    selectedURL.stopAccessingSecurityScopedResource()
                }
            }

            let csvText = try String(contentsOf: selectedURL, encoding: .utf8)
            let parsedWorkouts = try LegacyWorkoutCSVParser.parse(csvText)

            guard parsedWorkouts.isEmpty == false else {
                importErrorMessage = "Die CSV enthält keine importierbaren Workout-Zeilen."
                return
            }

            importPreviewWorkouts = parsedWorkouts
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }

    private func confirmImportPreview() {
        importWorkouts(importPreviewWorkouts)
        importPreviewWorkouts = []
    }

    private func cancelImportPreview() {
        importPreviewWorkouts = []
    }

    private func startWorkoutPlan(_ plan: WorkoutPlanTemplate) {
        workout = plan.makeWorkout()
        selectedPlanID = plan.id
        editingWorkoutPlan = nil
    }

    private func editSelectedPlan() {
        editingWorkoutPlan = selectedPlan
    }

    private func createWorkoutPlan() {
        editingWorkoutPlan = WorkoutPlanTemplate(
            name: "Neuer Plan",
            exerciseNames: []
        )
    }
}

private struct EmptyWorkoutView: View {
    let startWorkout: () -> Void
    let workoutPlans: [WorkoutPlanTemplate]
    @Binding var selectedPlanID: UUID?
    let startWorkoutPlan: (WorkoutPlanTemplate) -> Void
    let editSelectedPlan: () -> Void
    let createWorkoutPlan: () -> Void
    let importCSV: () -> Void
    let deleteAllWorkouts: () -> Void
    let hasWorkouts: Bool

    private var selectedPlan: WorkoutPlanTemplate? {
        workoutPlans.first { $0.id == selectedPlanID } ?? workoutPlans.first
    }

    var body: some View {
        VStack(spacing: 22) {
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

            WorkoutPlanPickerSection(
                plans: workoutPlans,
                selectedPlanID: $selectedPlanID
            )

            HStack(spacing: 12) {
                Button {
                    if let selectedPlan {
                        startWorkoutPlan(selectedPlan)
                    }
                } label: {
                    Label("Plan starten", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryCompactButtonStyle())
                .disabled(selectedPlan == nil)
                .opacity(selectedPlan == nil ? 0.45 : 1)
                .accessibilityLabel("Workout-Plan starten")

                Button(action: editSelectedPlan) {
                    Label("Bearbeiten", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryCompactButtonStyle())
                .disabled(selectedPlan == nil)
                .opacity(selectedPlan == nil ? 0.45 : 1)
                .accessibilityLabel("Ausgewählten Workout-Plan bearbeiten")
            }
            .padding(.horizontal, 26)

            Button(action: createWorkoutPlan) {
                Label("Neuen Workout-Plan anlegen", systemImage: "square.and.pencil")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColor.trainingGreen)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(AppColor.inputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 26)
            .accessibilityLabel("Neuen Workout-Plan anlegen")

            StartWorkoutButton(title: "Leeres Workout starten", systemImage: "plus", action: startWorkout)
                .padding(.horizontal, 26)

            VStack(spacing: 12) {
                Button(action: importCSV) {
                    Label("Legacy CSV importieren", systemImage: "tray.and.arrow.down")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColor.trainingGreen)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(AppColor.inputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 26)
                .accessibilityLabel("Legacy CSV importieren")

                Button(role: .destructive, action: deleteAllWorkouts) {
                    Label("Prototyp: Alle Workout-Daten löschen", systemImage: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(hasWorkouts ? Color.red.opacity(0.85) : .secondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(AppColor.inputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(hasWorkouts == false)
                .opacity(hasWorkouts ? 1 : 0.45)
                .padding(.horizontal, 26)
                .accessibilityLabel("Alle Workout-Daten löschen")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

private struct WorkoutPlanPickerSection: View {
    let plans: [WorkoutPlanTemplate]
    @Binding var selectedPlanID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Workout-Pläne")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.primaryText)

                    Text("Wähle eine Vorlage für dein nächstes Training.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondaryText)
                }

                Spacer()
            }
            .padding(.horizontal, 6)

            if plans.isEmpty {
                EmptyWorkoutPlanCard()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(plans) { plan in
                        Button {
                            selectedPlanID = plan.id
                        } label: {
                            WorkoutPlanTile(
                                plan: plan,
                                isSelected: selectedPlanID == plan.id || (selectedPlanID == nil && plan.id == plans.first?.id)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(plan.name) auswählen")
                    }
                }
            }
        }
        .onAppear {
            if selectedPlanID == nil {
                selectedPlanID = plans.first?.id
            }
        }
        .onChange(of: plans) { _, newPlans in
            guard let selectedPlanID else {
                self.selectedPlanID = newPlans.first?.id
                return
            }

            if newPlans.contains(where: { $0.id == selectedPlanID }) == false {
                self.selectedPlanID = newPlans.first?.id
            }
        }
    }
}

private struct WorkoutPlanTile: View {
    let plan: WorkoutPlanTemplate
    let isSelected: Bool

    private var exercisePreview: String {
        guard plan.exerciseNames.isEmpty == false else {
            return "Noch keine Übungen"
        }

        return plan.exerciseNames.prefix(6).joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                IconBadge(systemName: "list.clipboard.fill")
                    .scaleEffect(0.82, anchor: .topLeading)
                    .frame(width: 46, height: 46, alignment: .topLeading)

                VStack(alignment: .leading, spacing: 6) {
                    Text(plan.name)
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.84)

                    Text(plan.exerciseCountText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColor.trainingGreen)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isSelected ? AppColor.trainingGreen : .secondaryText)
            }

            Text(exercisePreview)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondaryText)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.cardBackground)
                .shadow(color: .black.opacity(isSelected ? 0.10 : 0.05), radius: isSelected ? 18 : 12, x: 0, y: 8)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? AppColor.trainingGreen : Color.clear, lineWidth: 2)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct EmptyWorkoutPlanCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "list.clipboard")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(AppColor.trainingGreen)

            Text("Noch keine Workout-Pläne")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.primaryText)

            Text("Lege einen Plan an, um Übungen vorbereitet ins nächste Workout zu übernehmen.")
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
}

private struct PrimaryCompactButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(height: 50)
            .background(AppColor.trainingGreen)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

private struct SecondaryCompactButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(AppColor.trainingGreen)
            .frame(height: 50)
            .background(AppColor.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

private struct WorkoutPlanEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var plan: WorkoutPlanTemplate
    @State private var newExerciseName = ""
    @State private var isDeleteConfirmationPresented = false
    let exerciseTemplates: [ExerciseTemplatePreset]
    let savePlan: (WorkoutPlanTemplate) -> Void
    let deletePlan: (UUID) -> Void
    let startPlan: (WorkoutPlanTemplate) -> Void

    init(
        plan: WorkoutPlanTemplate,
        exerciseTemplates: [ExerciseTemplatePreset],
        savePlan: @escaping (WorkoutPlanTemplate) -> Void,
        deletePlan: @escaping (UUID) -> Void,
        startPlan: @escaping (WorkoutPlanTemplate) -> Void
    ) {
        _plan = State(initialValue: plan)
        self.exerciseTemplates = exerciseTemplates
        self.savePlan = savePlan
        self.deletePlan = deletePlan
        self.startPlan = startPlan
    }

    private var canSave: Bool {
        plan.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private var groupedTemplates: [(category: String, templates: [ExerciseTemplatePreset])] {
        Dictionary(grouping: exerciseTemplates, by: \.category)
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
        NavigationStack {
            ZStack {
                AppColor.pageBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        DashboardCard {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack(alignment: .top, spacing: 16) {
                                    IconBadge(systemName: "list.clipboard.fill")

                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("Workout-Plan")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(.secondaryText)

                                        TextField("Planname", text: $plan.name)
                                            .font(.system(size: 26, weight: .bold))
                                            .foregroundStyle(.primaryText)
                                    }
                                }

                                HStack(spacing: 12) {
                                    StatPill(title: "Übungen", value: "\(plan.exerciseNames.count)")
                                    StatPill(title: "Status", value: plan.exerciseNames.isEmpty ? "Leer" : "Bereit")
                                }
                            }
                        }

                        DashboardCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Übungen")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(.primaryText)

                                if plan.exerciseNames.isEmpty {
                                    Text("Füge Übungen hinzu, um den Plan starten zu können.")
                                        .font(.system(size: 15))
                                        .foregroundStyle(.secondaryText)
                                } else {
                                    VStack(spacing: 10) {
                                        ForEach(Array(plan.exerciseNames.enumerated()), id: \.offset) { index, exerciseName in
                                            WorkoutPlanExerciseRow(
                                                index: index,
                                                exerciseName: exerciseName,
                                                canMoveUp: index > 0,
                                                canMoveDown: index < plan.exerciseNames.count - 1,
                                                moveUp: { moveExercise(from: index, by: -1) },
                                                moveDown: { moveExercise(from: index, by: 1) },
                                                delete: { deleteExercise(at: index) }
                                            )
                                        }
                                    }
                                }
                            }
                        }

                        DashboardCard {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Übung hinzufügen")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(.primaryText)

                                        Text("Aus Vorlage oder frei eintragen.")
                                            .font(.system(size: 14))
                                            .foregroundStyle(.secondaryText)
                                    }

                                    Spacer()

                                    Menu {
                                        ForEach(groupedTemplates, id: \.category) { group in
                                            Section(group.category) {
                                                ForEach(group.templates) { template in
                                                    Button(template.name) {
                                                        addExercise(template.name)
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
                                        ForEach(exerciseTemplates.prefix(8)) { template in
                                            Button {
                                                addExercise(template.name)
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
                                        }
                                    }
                                }

                                HStack(spacing: 12) {
                                    TextField("z. B. Bankdrücken", text: $newExerciseName)
                                        .textInputAutocapitalization(.words)
                                        .submitLabel(.done)
                                        .onSubmit(addTypedExercise)
                                        .padding(14)
                                        .background(AppColor.inputBackground)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                                    Button(action: addTypedExercise) {
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

                        Button(role: .destructive) {
                            isDeleteConfirmationPresented = true
                        } label: {
                            Label("Plan löschen", systemImage: "trash")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.red.opacity(0.85))
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .background(AppColor.inputBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 120)
                }
            }
            .navigationTitle("Plan bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        saveAndDismiss()
                    }
                    .disabled(canSave == false)
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 12) {
                    Button(action: saveAndStart) {
                        Label("Plan starten", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryCompactButtonStyle())
                    .disabled(canSave == false || plan.exerciseNames.isEmpty)
                    .opacity(canSave && plan.exerciseNames.isEmpty == false ? 1 : 0.45)

                    Button(action: saveAndDismiss) {
                        Text("Sichern")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryCompactButtonStyle())
                    .disabled(canSave == false)
                    .opacity(canSave ? 1 : 0.45)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
            .confirmationDialog(
                "Workout-Plan löschen?",
                isPresented: $isDeleteConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button("Plan löschen", role: .destructive) {
                    deletePlan(plan.id)
                    dismiss()
                }

                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Der Plan wird entfernt. Bereits gespeicherte Workouts bleiben unverändert.")
            }
        }
    }

    private func addTypedExercise() {
        addExercise(newExerciseName)
        newExerciseName = ""
    }

    private func addExercise(_ name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else { return }
        plan.exerciseNames.append(trimmedName)
    }

    private func moveExercise(from index: Int, by offset: Int) {
        let destination = index + offset
        guard plan.exerciseNames.indices.contains(index),
              plan.exerciseNames.indices.contains(destination) else {
            return
        }

        let exercise = plan.exerciseNames.remove(at: index)
        plan.exerciseNames.insert(exercise, at: destination)
    }

    private func deleteExercise(at index: Int) {
        guard plan.exerciseNames.indices.contains(index) else { return }
        plan.exerciseNames.remove(at: index)
    }

    private func saveAndDismiss() {
        guard canSave else { return }
        savePlan(plan)
        dismiss()
    }

    private func saveAndStart() {
        guard canSave, plan.exerciseNames.isEmpty == false else { return }
        savePlan(plan)
        startPlan(plan)
        dismiss()
    }

    private func categorySortValue(_ category: String) -> String {
        let order = ["Brust", "Beine", "Rücken", "Schultern", "Arme", "Eigene"]
        guard let index = order.firstIndex(of: category) else {
            return "9-\(category)"
        }

        return "\(index)-\(category)"
    }
}

private struct WorkoutPlanExerciseRow: View {
    let index: Int
    let exerciseName: String
    let canMoveUp: Bool
    let canMoveDown: Bool
    let moveUp: () -> Void
    let moveDown: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppColor.trainingGreen)
                .frame(width: 28)

            Text(exerciseName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primaryText)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 2) {
                Button(action: moveUp) {
                    Image(systemName: "chevron.up")
                        .frame(width: 28, height: 34)
                }
                .disabled(canMoveUp == false)
                .opacity(canMoveUp ? 1 : 0.25)

                Button(action: moveDown) {
                    Image(systemName: "chevron.down")
                        .frame(width: 28, height: 34)
                }
                .disabled(canMoveDown == false)
                .opacity(canMoveDown ? 1 : 0.25)
            }
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.secondaryText)

            Button(action: delete) {
                Image(systemName: "minus.circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.secondaryText)
                    .frame(width: 30, height: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(exerciseName) entfernen")
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 48)
        .background(AppColor.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct LegacyImportPreviewView: View {
    let workouts: [Workout]
    let confirmImport: () -> Void
    let cancelImport: () -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 155), spacing: 14)
    ]

    private var totalSets: Int {
        workouts.reduce(0) { $0 + $1.totalSets }
    }

    private var totalVolume: Double {
        workouts.reduce(0) { $0 + $1.totalVolume }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.pageBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        DashboardCard {
                            VStack(alignment: .leading, spacing: 18) {
                                AnalyticsSectionHeader(
                                    icon: "tray.and.arrow.down.fill",
                                    title: "Import-Vorschau",
                                    subtitle: "Prüfe die Daten vor dem Übernehmen"
                                )

                                HStack(spacing: 12) {
                                    StatPill(title: "Workouts", value: "\(workouts.count)")
                                    StatPill(title: "Sets", value: "\(totalSets)")
                                    StatPill(title: "Volumen", value: "\(Int(totalVolume.rounded())) kg")
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Importierte Workouts")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.primaryText)

                            LazyVGrid(columns: columns, spacing: 14) {
                                ForEach(workouts) { workout in
                                    WorkoutHistoryTile(workout: workout)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 110)
                }
            }
            .navigationTitle("CSV Import")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 12) {
                    Button(action: cancelImport) {
                        Text("Abbrechen")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .foregroundStyle(AppColor.trainingGreen)
                            .background(AppColor.inputBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button(action: confirmImport) {
                        Text("Import übernehmen")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .foregroundStyle(.white)
                            .background(AppColor.trainingGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
        }
    }
}

private enum LegacyWorkoutCSVParser {
    enum ImportError: LocalizedError {
        case missingRequiredColumns(recognizedColumns: [String])
        case invalidDate(row: Int, value: String)
        case noImportableRows(dataRowCount: Int, recognizedColumns: [String])

        var errorDescription: String? {
            switch self {
            case let .missingRequiredColumns(recognizedColumns):
                let columnsText = recognizedColumns.isEmpty ? "keine Spalten" : recognizedColumns.joined(separator: ", ")
                return "Die CSV braucht die Spalten date, exercise_name, top_weight_kg und top_reps. Erkannt: \(columnsText)."
            case let .invalidDate(row, value):
                return "Zeile \(row): Das Datum '\(value)' ist nicht im Format yyyy-mm-dd."
            case let .noImportableRows(dataRowCount, recognizedColumns):
                let columnsText = recognizedColumns.isEmpty ? "keine Spalten" : recognizedColumns.joined(separator: ", ")
                return "Die CSV enthält keine importierbaren Workout-Zeilen. Gelesene Datenzeilen: \(dataRowCount). Erkannt: \(columnsText)."
            }
        }
    }

    static func parse(_ csvText: String) throws -> [Workout] {
        let normalizedText = normalizeSanitizedCSVText(csvText)
        let rows = parseRows(normalizedText)
            .filter { row in
                row.contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
            }

        guard let header = rows.first else {
            return []
        }

        var columns: [String: Int] = [:]
        for (index, name) in header.enumerated() {
            let normalizedName = normalizeHeader(name)
            guard normalizedName.isEmpty == false else {
                continue
            }

            if columns[normalizedName] == nil {
                columns[normalizedName] = index
            }
        }

        guard let dateIndex = columns["date"],
              let exerciseIndex = columns["exercise_name"],
              let weightIndex = columns["top_weight_kg"],
              let repsIndex = columns["top_reps"] else {
            throw ImportError.missingRequiredColumns(
                recognizedColumns: header.map(normalizeHeader).filter { $0.isEmpty == false }
            )
        }

        let workouts = try makeWorkouts(
            from: rows,
            dateIndex: dateIndex,
            exerciseIndex: exerciseIndex,
            weightIndex: weightIndex,
            repsIndex: repsIndex,
            notesIndex: columns["notes"],
            dateFormats: ["yyyy-MM-dd"]
        )

        guard workouts.isEmpty == false else {
            throw ImportError.noImportableRows(
                dataRowCount: max(rows.count - 1, 0),
                recognizedColumns: header.map(normalizeHeader).filter { $0.isEmpty == false }
            )
        }

        return workouts
    }

    private static func normalizeSanitizedCSVText(_ text: String) -> String {
        text.replacingOccurrences(
            of: #"([^\n\r\u{2028}\u{2029}])(\d{4}-\d{2}-\d{2},)"#,
            with: "$1\n$2",
            options: .regularExpression
        )
    }

    private static func makeWorkouts(
        from rows: [[String]],
        dateIndex: Int,
        exerciseIndex: Int,
        weightIndex: Int,
        repsIndex: Int,
        notesIndex: Int?,
        dateFormats: [String]
    ) throws -> [Workout] {
        let dateFormatters = dateFormats.map { format in
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            return formatter
        }

        var workoutOrder: [Date] = []
        var workoutExercisesByDate: [Date: [WorkoutExercise]] = [:]

        for (offset, row) in rows.dropFirst().enumerated() {
            let sourceRow = offset + 2
            let dateText = value(at: dateIndex, in: row)
            let exerciseName = value(at: exerciseIndex, in: row)

            guard exerciseName.isEmpty == false else {
                continue
            }

            guard let date = parseDate(dateText, using: dateFormatters) else {
                throw ImportError.invalidDate(row: sourceRow, value: dateText)
            }

            if workoutExercisesByDate[date] == nil {
                workoutOrder.append(date)
                workoutExercisesByDate[date] = []
            }

            let set = SetEntry(
                weight: doubleValue(from: value(at: weightIndex, in: row)),
                reps: integerValue(from: value(at: repsIndex, in: row)),
                notes: notesIndex.map { value(at: $0, in: row) } ?? ""
            )

            workoutExercisesByDate[date]?.append(
                WorkoutExercise(
                    name: exerciseName,
                    sets: [set]
                )
            )
        }

        return workoutOrder
            .compactMap { date in
                guard let exercises = workoutExercisesByDate[date], exercises.isEmpty == false else {
                    return nil
                }

                return Workout(
                    date: date,
                    title: "Legacy Workout",
                    notes: "Importiert aus Legacy CSV",
                    exercises: exercises
                )
            }
            .sorted { $0.date > $1.date }
    }

    private static func parseDate(_ text: String, using formatters: [DateFormatter]) -> Date? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedText.isEmpty == false else {
            return nil
        }

        return formatters.lazy.compactMap { $0.date(from: trimmedText) }.first
    }

    private static func parseRows(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var isInsideQuotes = false
        var iterator = text.makeIterator()
        var shouldSkipNextLineFeed = false

        while let character = iterator.next() {
            if shouldSkipNextLineFeed {
                shouldSkipNextLineFeed = false
                if character == "\n" {
                    continue
                }
            }

            switch character {
            case "\"":
                if isInsideQuotes {
                    if let nextCharacter = iterator.next() {
                        if nextCharacter == "\"" {
                            currentField.append("\"")
                        } else {
                            isInsideQuotes = false
                            handleNonQuoteCharacter(
                                nextCharacter,
                                currentField: &currentField,
                                currentRow: &currentRow,
                                rows: &rows
                            )
                        }
                    } else {
                        isInsideQuotes = false
                    }
                } else {
                    isInsideQuotes = true
                }
            case ",":
                if isInsideQuotes {
                    currentField.append(character)
                } else {
                    currentRow.append(currentField)
                    currentField = ""
                }
            case "\n":
                finishRow(
                    isInsideQuotes: isInsideQuotes,
                    lineBreak: character,
                    currentField: &currentField,
                    currentRow: &currentRow,
                    rows: &rows
                )
            case "\r":
                finishRow(
                    isInsideQuotes: isInsideQuotes,
                    lineBreak: character,
                    currentField: &currentField,
                    currentRow: &currentRow,
                    rows: &rows
                )
                if isInsideQuotes == false {
                    shouldSkipNextLineFeed = true
                }
            default:
                currentField.append(character)
            }
        }

        if currentField.isEmpty == false || currentRow.isEmpty == false {
            currentRow.append(currentField)
            rows.append(currentRow)
        }

        return rows
    }

    private static func finishRow(
        isInsideQuotes: Bool,
        lineBreak: Character,
        currentField: inout String,
        currentRow: inout [String],
        rows: inout [[String]]
    ) {
        if isInsideQuotes {
            currentField.append(lineBreak)
        } else {
            currentRow.append(currentField)
            rows.append(currentRow)
            currentRow = []
            currentField = ""
        }
    }

    private static func handleNonQuoteCharacter(
        _ character: Character,
        currentField: inout String,
        currentRow: inout [String],
        rows: inout [[String]]
    ) {
        switch character {
        case ",":
            currentRow.append(currentField)
            currentField = ""
        case "\n":
            currentRow.append(currentField)
            rows.append(currentRow)
            currentRow = []
            currentField = ""
        case "\r":
            currentRow.append(currentField)
            rows.append(currentRow)
            currentRow = []
            currentField = ""
        default:
            currentField.append(character)
        }
    }

    private static func normalizeHeader(_ header: String) -> String {
        header
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\u{feff}"))
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    private static func value(at index: Int, in row: [String]) -> String {
        guard row.indices.contains(index) else {
            return ""
        }

        return row[index].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func doubleValue(from text: String) -> Double? {
        let normalizedText = text.replacingOccurrences(of: ",", with: ".")
        return Double(normalizedText)
    }

    private static func integerValue(from text: String) -> Int? {
        if let intValue = Int(text) {
            return intValue
        }

        if let doubleValue = Double(text.replacingOccurrences(of: ",", with: ".")) {
            return Int(doubleValue.rounded())
        }

        return nil
    }
}

private struct WorkoutEditorView: View {
    @Bindable var workout: Workout
    let exerciseTemplates: [ExerciseTemplatePreset]
    let finishWorkout: (Workout) -> Void
    let cancelWorkout: () -> Void
    let saveExerciseTemplate: (String) -> Void
    @State private var newExerciseName = ""
    @State private var isCancelConfirmationPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Button {
                isCancelConfirmationPresented = true
            } label: {
                Label("Zurück", systemImage: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColor.trainingGreen)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(AppColor.inputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Workout verlassen")

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
        .confirmationDialog(
            "Aktuelles Workout abbrechen?",
            isPresented: $isCancelConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Workout abbrechen", role: .destructive) {
                cancelWorkout()
            }

            Button("Weiter loggen", role: .cancel) {}
        } message: {
            Text("Du kehrst zur Übersicht zurück. Ein neu gestartetes, nicht gespeichertes Workout wird verworfen.")
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

private struct AnalyticsView: View {
    let workouts: [Workout]
    let continueWorkout: (Workout) -> Void
    @State private var selectedExerciseID: String?
    @State private var selectedPeriod: AnalyticsPeriod = .all
    @State private var selectedTimelineMetric: ExerciseTimelineMetric = .maxWeight

    private var summary: WorkoutAnalyticsSummary {
        WorkoutAnalyticsSummary(workouts: filteredWorkouts)
    }

    private var filteredWorkouts: [Workout] {
        selectedPeriod.filter(workouts)
    }

    private var periodComparison: WorkoutPeriodComparison? {
        selectedPeriod.comparison(for: workouts)
    }

    var body: some View {
        ZStack {
            AppColor.pageBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    AnalyticsHeader()
                    AnalyticsPeriodPicker(selection: $selectedPeriod)

                    if summary.workoutCount == 0 {
                        EmptyAnalyticsPeriodCard(period: selectedPeriod)
                    } else {
                        AnalyticsOverviewCard(
                            summary: summary,
                            comparison: periodComparison
                        )
                        ExerciseHistoryAnalyticsCard(
                            exercises: summary.exerciseStats,
                            selectedExerciseID: $selectedExerciseID,
                            selectedMetric: $selectedTimelineMetric
                        )
                    }

                    TrainingCalendarCard(
                        workouts: workouts,
                        continueWorkout: continueWorkout
                    )

                    if summary.workoutCount > 0 {
                        PersonalRecordsCard(records: summary.personalRecords)
                        WorkoutConsistencyCard(consistency: summary.consistency)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 120)
            }
        }
        .navigationTitle("Analyse")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private enum AnalyticsPeriod: String, CaseIterable, Identifiable {
    case fourWeeks = "4 Wo."
    case threeMonths = "3 Mon."
    case year = "1 Jahr"
    case all = "Gesamt"

    var id: String { rawValue }

    func filter(_ workouts: [Workout], referenceDate: Date = Date()) -> [Workout] {
        guard let startDate = startDate(referenceDate: referenceDate) else {
            return workouts
        }

        return workouts.filter { $0.date >= startDate && $0.date <= referenceDate }
    }

    func comparison(
        for workouts: [Workout],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> WorkoutPeriodComparison? {
        guard let currentStart = startDate(referenceDate: referenceDate),
              let previousStart = previousStartDate(currentStart: currentStart, calendar: calendar) else {
            return nil
        }

        let currentCount = workouts.filter { $0.date >= currentStart && $0.date <= referenceDate }.count
        let previousCount = workouts.filter { $0.date >= previousStart && $0.date < currentStart }.count
        return WorkoutPeriodComparison(currentCount: currentCount, previousCount: previousCount)
    }

    private func startDate(referenceDate: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .fourWeeks:
            return calendar.date(byAdding: .day, value: -27, to: calendar.startOfDay(for: referenceDate))
        case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: referenceDate)
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: referenceDate)
        case .all:
            return nil
        }
    }

    private func previousStartDate(currentStart: Date, calendar: Calendar) -> Date? {
        switch self {
        case .fourWeeks:
            return calendar.date(byAdding: .day, value: -28, to: currentStart)
        case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: currentStart)
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: currentStart)
        case .all:
            return nil
        }
    }
}

private struct AnalyticsPeriodPicker: View {
    @Binding var selection: AnalyticsPeriod

    var body: some View {
        Picker("Analysezeitraum", selection: $selection) {
            ForEach(AnalyticsPeriod.allCases) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Analysezeitraum")
    }
}

private struct WorkoutPeriodComparison {
    let currentCount: Int
    let previousCount: Int

    var differenceText: String {
        let difference = currentCount - previousCount
        if difference > 0 {
            return "+\(difference) Workouts"
        }

        if difference < 0 {
            return "\(difference) Workouts"
        }

        return "Unverändert"
    }

    var isPositive: Bool {
        currentCount >= previousCount
    }
}

private struct AnalyticsHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Analyse")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.primaryText)

            Text("Fortschritt, Trainingsrhythmus und Bestwerte")
                .font(.system(size: 17))
                .foregroundStyle(.secondaryText)
        }
    }
}

private struct EmptyAnalyticsPeriodCard: View {
    let period: AnalyticsPeriod

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 14) {
                IconBadge(systemName: "calendar.badge.exclamationmark")

                Text("Keine Workouts im Zeitraum")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primaryText)

                Text("Für \(period.rawValue) liegen keine Trainingsdaten vor. Wähle einen längeren Zeitraum.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondaryText)
            }
        }
    }
}

private struct EmptyAnalyticsCard: View {
    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 14) {
                IconBadge(systemName: "chart.bar.xaxis")

                Text("Noch keine Analyse möglich")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.primaryText)

                Text("Speichere ein Workout, damit Volumen, Bestwerte und Übungsverläufe erscheinen.")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondaryText)
            }
        }
    }
}

private struct AnalyticsOverviewCard: View {
    let summary: WorkoutAnalyticsSummary
    let comparison: WorkoutPeriodComparison?

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 16) {
                    IconBadge(systemName: "sum")

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Gesamtleistung")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.primaryText)

                        Text(summary.dateRangeText)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondaryText)
                    }
                }

                HStack(spacing: 12) {
                    StatPill(title: "Workouts", value: "\(summary.workoutCount)")
                    StatPill(title: "Ø / Woche", value: summary.averageWorkoutsPerWeekText)
                    StatPill(title: "Sets", value: "\(summary.totalSets)")
                }

                if let comparison {
                    HStack(spacing: 8) {
                        Image(systemName: comparison.isPositive ? "arrow.up.right" : "arrow.down.right")
                        Text("Zum vorherigen Zeitraum: \(comparison.differenceText)")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(comparison.isPositive ? AppColor.trainingGreen : .secondaryText)
                }
            }
        }
    }
}

private struct WorkoutVolumeTrendCard: View {
    let workouts: [Workout]

    private var maxVolume: Double {
        max(workouts.map(\.totalVolume).max() ?? 0, 1)
    }

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 18) {
                AnalyticsSectionHeader(
                    icon: "chart.bar.fill",
                    title: "Workout-Volumen",
                    subtitle: "Letzte Einheiten"
                )

                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(workouts) { workout in
                        VStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(AppColor.trainingGreen)
                                .frame(height: barHeight(for: workout.totalVolume))

                            Text(workout.date.formatted(.dateTime.day().month(.abbreviated)))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 150, alignment: .bottom)
            }
        }
    }

    private func barHeight(for volume: Double) -> CGFloat {
        CGFloat(max(12, min(110, (volume / maxVolume) * 110)))
    }
}

private struct PersonalRecordsCard: View {
    let records: [PersonalRecordMetric]

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 16) {
                AnalyticsSectionHeader(
                    icon: "trophy.fill",
                    title: "Persönliche Rekorde",
                    subtitle: "Zuletzt erreichte Bestwerte"
                )

                if records.isEmpty {
                    AnalyticsEmptyRow(text: "Noch keine Gewichte geloggt.")
                } else {
                    VStack(spacing: 0) {
                        ForEach(records.prefix(5)) { record in
                            AnalyticsValueRow(
                                title: record.exerciseName,
                                detail: record.date.formatted(date: .abbreviated, time: .omitted),
                                value: record.weightText
                            )

                            if record.id != records.prefix(5).last?.id {
                                Divider()
                                    .padding(.leading, 4)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct ExerciseVolumeCard: View {
    let exercises: [ExerciseAnalyticsMetric]

    private var maxVolume: Double {
        max(exercises.map(\.totalVolume).max() ?? 0, 1)
    }

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 16) {
                AnalyticsSectionHeader(
                    icon: "dumbbell.fill",
                    title: "Volumen pro Übung",
                    subtitle: "Top Übungen"
                )

                if exercises.isEmpty {
                    AnalyticsEmptyRow(text: "Noch keine Übungsdaten vorhanden.")
                } else {
                    VStack(spacing: 14) {
                        ForEach(exercises.prefix(5)) { exercise in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(exercise.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.primaryText)
                                        .lineLimit(1)

                                    Spacer()

                                    Text(exercise.totalVolumeText)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(AppColor.trainingGreen)
                                }

                                GeometryReader { proxy in
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(AppColor.inputBackground)
                                        .overlay(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                .fill(AppColor.trainingGreen)
                                                .frame(width: proxy.size.width * widthRatio(for: exercise.totalVolume))
                                        }
                                }
                                .frame(height: 8)
                            }
                        }
                    }
                }
            }
        }
    }

    private func widthRatio(for volume: Double) -> CGFloat {
        CGFloat(max(0.08, min(1, volume / maxVolume)))
    }
}

private struct ExerciseHistoryAnalyticsCard: View {
    let exercises: [ExerciseAnalyticsMetric]
    @Binding var selectedExerciseID: String?
    @Binding var selectedMetric: ExerciseTimelineMetric

    private var selectedExercise: ExerciseAnalyticsMetric? {
        if let selectedExerciseID,
           let exercise = exercises.first(where: { $0.id == selectedExerciseID }) {
            return exercise
        }

        return exercises.first
    }

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    AnalyticsSectionHeader(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Übungsverlauf",
                        subtitle: selectedMetric.subtitle
                    )

                    Spacer()

                    if exercises.isEmpty == false {
                        Menu {
                            ForEach(exercises) { exercise in
                                Button(exercise.name) {
                                    selectedExerciseID = exercise.id
                                }
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(AppColor.trainingGreen)
                                .frame(width: 42, height: 42)
                                .background(AppColor.inputBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .accessibilityLabel("Übung auswählen")
                    }
                }

                if let selectedExercise {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(selectedExercise.name)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.primaryText)

                        Picker("Verlaufsmetrik", selection: $selectedMetric) {
                            ForEach(ExerciseTimelineMetric.allCases) { metric in
                                Text(metric.rawValue).tag(metric)
                            }
                        }
                        .pickerStyle(.segmented)

                        HStack(spacing: 12) {
                            StatPill(title: "Max kg", value: selectedExercise.maxWeightText)
                            StatPill(title: "1RM", value: selectedExercise.maxEstimatedOneRepMaxText)
                            StatPill(title: "Tage", value: "\(selectedExercise.trainingDayCount)")
                        }

                        ExerciseWeightTimeline(
                            entries: selectedExercise.timelineEntries,
                            metric: selectedMetric
                        )
                    }
                } else {
                    AnalyticsEmptyRow(text: "Noch keine Übungshistorie vorhanden.")
                }
            }
        }
        .onAppear {
            if selectedExerciseID == nil {
                selectedExerciseID = exercises.first?.id
            }
        }
    }
}

private enum ExerciseTimelineMetric: String, CaseIterable, Identifiable {
    case maxWeight = "Max. Gewicht"
    case estimatedOneRepMax = "Geschätztes 1RM"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .maxWeight:
            return "Höchstes Gewicht je Trainingstag"
        case .estimatedOneRepMax:
            return "Geschätzte Maximalkraft über Zeit"
        }
    }

    var emptyText: String {
        switch self {
        case .maxWeight:
            return "Für diese Übung fehlen noch Gewichtswerte."
        case .estimatedOneRepMax:
            return "Für ein 1RM werden Gewicht und 1 bis 12 Wiederholungen benötigt."
        }
    }
}

private struct ExerciseWeightTimeline: View {
    let entries: [ExerciseTimelineEntry]
    let metric: ExerciseTimelineMetric

    private var sortedEntries: [ExerciseTimelineEntry] {
        entries.sorted { $0.date < $1.date }
    }

    private var maxWeight: Double {
        max(sortedEntries.map { $0.value(for: metric) }.max() ?? 0, 1)
    }

    private var minWeight: Double {
        sortedEntries.map { $0.value(for: metric) }.filter { $0 > 0 }.min() ?? 0
    }

    private var displayEntries: [ExerciseTimelineEntry] {
        sortedEntries.filter { $0.value(for: metric) > 0 }
    }

    var body: some View {
        if displayEntries.isEmpty {
            AnalyticsEmptyRow(text: metric.emptyText)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .trailing) {
                        Text("\(maxWeight.formatted(.number.precision(.fractionLength(0...1)))) kg")
                        Spacer()
                        Text("\(((minWeight + maxWeight) / 2).formatted(.number.precision(.fractionLength(0...1)))) kg")
                        Spacer()
                        Text("\(minWeight.formatted(.number.precision(.fractionLength(0...1)))) kg")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondaryText)
                    .frame(width: 42, height: 150)

                    WeightLineChart(entries: displayEntries, metric: metric)
                        .frame(height: 150)
                }

                HStack {
                    Text(displayEntries.first?.date.formatted(date: .abbreviated, time: .omitted) ?? "")
                    Spacer()
                    Text(displayEntries.last?.date.formatted(date: .abbreviated, time: .omitted) ?? "")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondaryText)

                if let latestEntry = displayEntries.last {
                    HStack {
                        Text("Aktuell: \(latestEntry.valueText(for: metric)) kg")

                        Spacer()

                        Text("\(displayEntries.count) Trainingstage")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColor.trainingGreen)
                }
            }
        }
    }
}

private struct WeightLineChart: View {
    let entries: [ExerciseTimelineEntry]
    let metric: ExerciseTimelineMetric

    private var minWeight: Double {
        entries.map { $0.value(for: metric) }.min() ?? 0
    }

    private var maxWeight: Double {
        entries.map { $0.value(for: metric) }.max() ?? 1
    }

    private var dateRange: TimeInterval {
        guard let firstDate = entries.first?.date,
              let lastDate = entries.last?.date else {
            return 1
        }

        return max(lastDate.timeIntervalSince(firstDate), 1)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ChartGrid()

                if entries.count == 1 {
                    singlePoint(in: proxy.size)
                } else {
                    linePath(in: proxy.size)
                        .stroke(
                            AppColor.trainingGreen,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                        )

                    ForEach(pointEntries) { point in
                        Circle()
                            .fill(AppColor.trainingGreen)
                            .frame(width: 7, height: 7)
                            .position(position(for: point, in: proxy.size))
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .background(AppColor.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var plotInsets: EdgeInsets {
        EdgeInsets(top: 10, leading: 8, bottom: 10, trailing: 8)
    }

    private func plotSize(from size: CGSize) -> CGSize {
        CGSize(
            width: max(1, size.width - plotInsets.leading - plotInsets.trailing),
            height: max(1, size.height - plotInsets.top - plotInsets.bottom)
        )
    }

    private var pointEntries: [ExerciseTimelineEntry] {
        guard entries.count > 12 else {
            return entries
        }

        var sampled = [ExerciseTimelineEntry]()
        for (index, entry) in entries.enumerated() {
            if index == 0 || index == entries.count - 1 || index % max(1, entries.count / 10) == 0 {
                sampled.append(entry)
            }
        }

        return sampled
    }

    private func linePath(in size: CGSize) -> Path {
        var path = Path()

        for (index, entry) in entries.enumerated() {
            let point = position(for: entry, in: size)

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        return path
    }

    @ViewBuilder
    private func singlePoint(in size: CGSize) -> some View {
        if let entry = entries.first {
            Circle()
                .fill(AppColor.trainingGreen)
                .frame(width: 10, height: 10)
                .position(position(for: entry, in: size))
        }
    }

    private func position(for entry: ExerciseTimelineEntry, in size: CGSize) -> CGPoint {
        let plotSize = plotSize(from: size)
        let x = plotInsets.leading + xPosition(for: entry, width: plotSize.width)
        let y = plotInsets.top + yPosition(for: entry.value(for: metric), height: plotSize.height)
        return CGPoint(x: x, y: y)
    }

    private func xPosition(for entry: ExerciseTimelineEntry, width: CGFloat) -> CGFloat {
        guard let firstDate = entries.first?.date else {
            return width / 2
        }

        let progress = entry.date.timeIntervalSince(firstDate) / dateRange
        return CGFloat(progress) * width
    }

    private func yPosition(for weight: Double, height: CGFloat) -> CGFloat {
        let range = max(maxWeight - minWeight, 1)
        let progress = (weight - minWeight) / range
        return height - CGFloat(progress) * height
    }
}

private struct ChartGrid: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { index in
                Rectangle()
                    .fill(index == 0 ? Color.clear : Color.black.opacity(0.06))
                    .frame(height: index == 0 ? 0 : 1)

                if index < 3 {
                    Spacer()
                }
            }
        }
        .padding(.vertical, 8)
    }
}

private struct AnalyticsSectionHeader: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppColor.deepGreen)
                .frame(width: 38, height: 38)
                .background(Circle().fill(AppColor.badgeBackground))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primaryText)

                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondaryText)
            }
        }
    }
}

private struct AnalyticsValueRow: View {
    let title: String
    let detail: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primaryText)
                    .lineLimit(1)

                Text(detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondaryText)
            }

            Spacer()

            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppColor.trainingGreen)
                .lineLimit(1)
        }
        .frame(height: 54)
    }
}

private struct AnalyticsEmptyRow: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.secondaryText)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct WorkoutAnalyticsSummary {
    let workoutCount: Int
    let totalSets: Int
    let totalVolume: Double
    let dateRangeText: String
    let recentWorkouts: [Workout]
    let exerciseStats: [ExerciseAnalyticsMetric]
    let personalRecords: [PersonalRecordMetric]
    let consistency: WorkoutConsistencyMetric

    init(workouts: [Workout]) {
        let sortedWorkouts = workouts.sorted { $0.date < $1.date }
        workoutCount = workouts.count
        totalSets = workouts.reduce(0) { $0 + $1.totalSets }
        totalVolume = workouts.reduce(0) { $0 + $1.totalVolume }
        recentWorkouts = Array(sortedWorkouts.suffix(6))
        dateRangeText = WorkoutAnalyticsSummary.makeDateRangeText(from: sortedWorkouts)
        consistency = WorkoutConsistencyMetric(workouts: sortedWorkouts)

        var builders: [String: ExerciseAnalyticsBuilder] = [:]

        for workout in sortedWorkouts {
            for exercise in workout.exercises {
                let trimmedName = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmedName.isEmpty == false else { continue }

                let key = trimmedName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                let builder = builders[key] ?? ExerciseAnalyticsBuilder(name: trimmedName)
                builder.add(exercise: exercise, workoutDate: workout.date)
                builders[key] = builder
            }
        }

        exerciseStats = builders.values
            .map { $0.metric }
            .sorted {
                if $0.totalVolume == $1.totalVolume {
                    return $0.name.localizedStandardCompare($1.name) == .orderedAscending
                }

                return $0.totalVolume > $1.totalVolume
            }

        personalRecords = exerciseStats
            .compactMap(\.personalRecord)
            .sorted {
                if $0.date == $1.date {
                    return $0.exerciseName.localizedStandardCompare($1.exerciseName) == .orderedAscending
                }

                return $0.date > $1.date
            }
    }

    var totalVolumeText: String {
        "\(Int(totalVolume.rounded())) kg"
    }

    var topVolumeExercises: [ExerciseAnalyticsMetric] {
        exerciseStats
    }

    var averageWorkoutsPerWeekText: String {
        consistency.averageWorkoutsPerWeek.formatted(.number.precision(.fractionLength(1)))
    }

    private static func makeDateRangeText(from workouts: [Workout]) -> String {
        guard let firstDate = workouts.first?.date,
              let lastDate = workouts.last?.date else {
            return "Keine gespeicherten Workouts"
        }

        if Calendar.current.isDate(firstDate, inSameDayAs: lastDate) {
            return firstDate.formatted(date: .abbreviated, time: .omitted)
        }

        return "\(firstDate.formatted(date: .abbreviated, time: .omitted)) - \(lastDate.formatted(date: .abbreviated, time: .omitted))"
    }
}

private struct WorkoutConsistencyMetric {
    let averageWorkoutsPerWeek: Double
    let longestWeeklyStreak: Int
    let longestPauseDays: Int
    let trainingDayCount: Int

    init(workouts: [Workout], calendar: Calendar = .current) {
        let trainingDays = Array(
            Set(workouts.map { calendar.startOfDay(for: $0.date) })
        ).sorted()

        trainingDayCount = trainingDays.count

        if let firstDay = trainingDays.first,
           let lastDay = trainingDays.last {
            let daySpan = max((calendar.dateComponents([.day], from: firstDay, to: lastDay).day ?? 0) + 1, 1)
            averageWorkoutsPerWeek = Double(trainingDays.count) / max(Double(daySpan) / 7, 1)
        } else {
            averageWorkoutsPerWeek = 0
        }

        longestPauseDays = zip(trainingDays, trainingDays.dropFirst())
            .map { previous, next in
                max((calendar.dateComponents([.day], from: previous, to: next).day ?? 1) - 1, 0)
            }
            .max() ?? 0

        let activeWeeks = Array(
            Set(trainingDays.compactMap { calendar.dateInterval(of: .weekOfYear, for: $0)?.start })
        ).sorted()

        var longestStreak = activeWeeks.isEmpty ? 0 : 1
        var currentStreak = longestStreak

        for (previous, next) in zip(activeWeeks, activeWeeks.dropFirst()) {
            let weekDistance = calendar.dateComponents([.weekOfYear], from: previous, to: next).weekOfYear ?? 0
            if weekDistance == 1 {
                currentStreak += 1
                longestStreak = max(longestStreak, currentStreak)
            } else {
                currentStreak = 1
            }
        }

        longestWeeklyStreak = longestStreak
    }
}

private struct WorkoutConsistencyCard: View {
    let consistency: WorkoutConsistencyMetric

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 16) {
                AnalyticsSectionHeader(
                    icon: "repeat",
                    title: "Konsistenz",
                    subtitle: "Dein Trainingsrhythmus"
                )

                HStack(spacing: 12) {
                    StatPill(
                        title: "Ø / Woche",
                        value: consistency.averageWorkoutsPerWeek.formatted(.number.precision(.fractionLength(1)))
                    )
                    StatPill(title: "Beste Serie", value: "\(consistency.longestWeeklyStreak) Wo.")
                    StatPill(title: "Längste Pause", value: "\(consistency.longestPauseDays) T.")
                }
            }
        }
    }
}

private struct TrainingCalendarCard: View {
    let workouts: [Workout]
    let continueWorkout: (Workout) -> Void
    @State private var monthOffset = 0

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private let weekdaySymbols = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }

    private var referenceDate: Date {
        workouts.map(\.date).max() ?? Date()
    }

    private var displayedMonth: Date {
        let components = calendar.dateComponents([.year, .month], from: referenceDate)
        let monthStart = calendar.date(from: components) ?? referenceDate
        return calendar.date(byAdding: .month, value: monthOffset, to: monthStart) ?? monthStart
    }

    private var workoutsByDay: [Date: Workout] {
        var result: [Date: Workout] = [:]
        for workout in workouts.sorted(by: { $0.date < $1.date }) {
            result[calendar.startOfDay(for: workout.date)] = workout
        }
        return result
    }

    private var monthCells: [TrainingCalendarDay] {
        guard let dayRange = calendar.range(of: .day, in: .month, for: displayedMonth) else {
            return []
        }

        let weekday = calendar.component(.weekday, from: displayedMonth)
        let leadingEmptyDays = (weekday - calendar.firstWeekday + 7) % 7
        var cells = (0..<leadingEmptyDays).map { TrainingCalendarDay(id: $0, date: nil) }

        for day in dayRange {
            let date = calendar.date(byAdding: .day, value: day - 1, to: displayedMonth)
            cells.append(TrainingCalendarDay(id: cells.count, date: date))
        }

        return cells
    }

    private var trainingDaysInMonth: Int {
        workoutsByDay.keys.filter { calendar.isDate($0, equalTo: displayedMonth, toGranularity: .month) }.count
    }

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    AnalyticsSectionHeader(
                        icon: "calendar",
                        title: "Trainingskalender",
                        subtitle: "\(trainingDaysInMonth) Trainingstage im Monat"
                    )

                    Spacer()

                    HStack(spacing: 4) {
                        calendarButton(systemName: "chevron.left", offset: -1)
                        calendarButton(systemName: "chevron.right", offset: 1)
                    }
                }

                Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primaryText)

                LazyVGrid(columns: columns, spacing: 9) {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondaryText)
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(monthCells) { cell in
                        calendarCell(cell)
                    }
                }

                HStack(spacing: 16) {
                    CalendarLegendDot(color: AppColor.trainingGreen, text: "Training")
                    CalendarLegendDot(color: AppColor.inputBackground, text: "Pausentag")
                }
            }
        }
    }

    private func calendarButton(systemName: String, offset: Int) -> some View {
        Button {
            monthOffset += offset
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppColor.trainingGreen)
                .frame(width: 34, height: 34)
                .background(AppColor.inputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(offset < 0 ? "Vorheriger Monat" : "Nächster Monat")
    }

    @ViewBuilder
    private func calendarCell(_ cell: TrainingCalendarDay) -> some View {
        if let date = cell.date {
            let workout = workoutsByDay[calendar.startOfDay(for: date)]

            if let workout {
                NavigationLink {
                    WorkoutDetailView(
                        workout: workout,
                        continueWorkout: continueWorkout
                    )
                } label: {
                    CalendarDayView(date: date, isTrainingDay: true)
                }
                .buttonStyle(.plain)
            } else {
                CalendarDayView(date: date, isTrainingDay: false)
            }
        } else {
            Color.clear
                .frame(width: 36, height: 36)
        }
    }
}

private struct TrainingCalendarDay: Identifiable {
    let id: Int
    let date: Date?
}

private struct CalendarDayView: View {
    let date: Date
    let isTrainingDay: Bool

    var body: some View {
        Text("\(Calendar.current.component(.day, from: date))")
            .font(.system(size: 13, weight: isTrainingDay ? .bold : .medium))
            .foregroundStyle(isTrainingDay ? Color.white : .secondaryText)
            .frame(width: 36, height: 36)
            .background(isTrainingDay ? AppColor.trainingGreen : AppColor.inputBackground)
            .clipShape(Circle())
            .overlay {
                if Calendar.current.isDateInToday(date) {
                    Circle()
                        .stroke(AppColor.deepGreen, lineWidth: 2)
                }
            }
            .accessibilityLabel(
                "\(date.formatted(date: .long, time: .omitted)), \(isTrainingDay ? "Training" : "Pausentag")"
            )
    }
}

private struct CalendarLegendDot: View {
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondaryText)
        }
    }
}

private final class ExerciseAnalyticsBuilder {
    let name: String
    private var maxWeight: Double = 0
    private var maxWeightDate = Date()
    private var totalVolume: Double = 0
    private var totalSets: Int = 0
    private var bestReps: Int = 0
    private var maxWeightByDay: [Date: Double] = [:]
    private var maxEstimatedOneRepMaxByDay: [Date: Double] = [:]

    init(name: String) {
        self.name = name
    }

    func add(exercise: WorkoutExercise, workoutDate: Date) {
        let setsWithWeight = exercise.sets.compactMap(\.weight)
        let exerciseMaxWeight = setsWithWeight.max() ?? 0
        let exerciseVolume = exercise.sets.reduce(0) { $0 + $1.volume }
        let workoutDay = Calendar.current.startOfDay(for: workoutDate)

        totalVolume += exerciseVolume
        totalSets += exercise.sets.count
        bestReps = max(bestReps, exercise.sets.compactMap(\.reps).max() ?? 0)

        if exerciseMaxWeight > 0 {
            maxWeightByDay[workoutDay] = max(maxWeightByDay[workoutDay] ?? 0, exerciseMaxWeight)
        }

        let estimatedOneRepMax = exercise.sets
            .compactMap(estimatedOneRepMax(for:))
            .max() ?? 0

        if estimatedOneRepMax > 0 {
            maxEstimatedOneRepMaxByDay[workoutDay] = max(
                maxEstimatedOneRepMaxByDay[workoutDay] ?? 0,
                estimatedOneRepMax
            )
        }

        if exerciseMaxWeight > maxWeight {
            maxWeight = exerciseMaxWeight
            maxWeightDate = workoutDate
        }
    }

    var metric: ExerciseAnalyticsMetric {
        ExerciseAnalyticsMetric(
            name: name,
            maxWeight: maxWeight,
            maxWeightDate: maxWeightDate,
            maxEstimatedOneRepMax: maxEstimatedOneRepMaxByDay.values.max() ?? 0,
            bestReps: bestReps,
            totalVolume: totalVolume,
            totalSets: totalSets,
            timelineEntries: maxWeightByDay
                .map { date, maxWeight in
                    ExerciseTimelineEntry(
                        date: date,
                        maxWeight: maxWeight,
                        estimatedOneRepMax: maxEstimatedOneRepMaxByDay[date] ?? 0
                    )
                }
                .sorted { $0.date < $1.date }
        )
    }

    private func estimatedOneRepMax(for set: SetEntry) -> Double? {
        guard let weight = set.weight,
              let reps = set.reps,
              weight > 0,
              (1...12).contains(reps) else {
            return nil
        }

        return weight * (1 + Double(reps) / 30)
    }
}

private struct ExerciseAnalyticsMetric: Identifiable {
    var id: String { name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) }
    let name: String
    let maxWeight: Double
    let maxWeightDate: Date
    let maxEstimatedOneRepMax: Double
    let bestReps: Int
    let totalVolume: Double
    let totalSets: Int
    let timelineEntries: [ExerciseTimelineEntry]

    var maxWeightText: String {
        guard maxWeight > 0 else { return "-" }
        return "\(maxWeight.formatted(.number.precision(.fractionLength(0...2)))) kg"
    }

    var totalVolumeText: String {
        "\(Int(totalVolume.rounded())) kg"
    }

    var maxEstimatedOneRepMaxText: String {
        guard maxEstimatedOneRepMax > 0 else { return "-" }
        return "\(maxEstimatedOneRepMax.formatted(.number.precision(.fractionLength(0...1)))) kg"
    }

    var trainingDayCount: Int {
        timelineEntries.count
    }

    var personalRecord: PersonalRecordMetric? {
        guard maxWeight > 0 else { return nil }

        return PersonalRecordMetric(
            exerciseName: name,
            weight: maxWeight,
            date: maxWeightDate
        )
    }
}

private struct ExerciseTimelineEntry: Identifiable {
    let id = UUID()
    let date: Date
    let maxWeight: Double
    let estimatedOneRepMax: Double

    var maxWeightText: String {
        maxWeight.formatted(.number.precision(.fractionLength(0...1)))
    }

    func value(for metric: ExerciseTimelineMetric) -> Double {
        switch metric {
        case .maxWeight:
            return maxWeight
        case .estimatedOneRepMax:
            return estimatedOneRepMax
        }
    }

    func valueText(for metric: ExerciseTimelineMetric) -> String {
        value(for: metric).formatted(.number.precision(.fractionLength(0...1)))
    }
}

private struct PersonalRecordMetric: Identifiable {
    var id: String { exerciseName }
    let exerciseName: String
    let weight: Double
    let date: Date

    var weightText: String {
        "\(weight.formatted(.number.precision(.fractionLength(0...2)))) kg"
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
