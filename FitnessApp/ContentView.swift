//
//  ContentView.swift
//  FitnessApp
//
//  Landing page draft for the first MVP.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(AppTab.home)

            NavigationStack {
                WorkoutLoggingPlaceholderView()
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
    }
}

private enum AppTab {
    case home
    case log
    case analytics
}

private struct HomeView: View {
    var body: some View {
        ZStack {
            AppColor.pageBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    HeaderView()
                    StartWorkoutButton()
                    LastWorkoutCard()
                    ProgressCard()
                }
                .padding(.horizontal, 24)
                .padding(.top, 58)
                .padding(.bottom, 28)
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
    var body: some View {
        Button {
        } label: {
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
    var body: some View {
        DashboardCard {
            HStack(alignment: .top, spacing: 20) {
                IconBadge(systemName: "dumbbell.fill")

                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Letztes Workout")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(.secondaryText)

                        Text("Oberkörper")
                            .font(.system(size: 25, weight: .bold))
                            .foregroundStyle(.primaryText)
                    }

                    VStack(alignment: .leading, spacing: 15) {
                        MetadataRow(systemName: "calendar", text: "06.06.2026")
                        MetadataRow(systemName: "figure.strengthtraining.traditional", text: "4 Übungen · 16 Sets")
                    }

                    LinkRow(title: "Fortsetzen")
                        .padding(.top, 12)
                }
            }
        }
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
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(AppColor.deepGreen)
                .frame(width: 32)

            Text(row.exercise + ":")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.primaryText)

            Text(row.value)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(AppColor.trainingGreen)

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

private struct WorkoutLoggingPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "plus.circle")
                .font(.system(size: 48))
                .foregroundStyle(AppColor.trainingGreen)

            Text("Workout loggen")
                .font(.title.bold())

            Text("Hier entsteht als Nächstes die schnelle Eingabe für Übungen, Sets, Gewicht und Wiederholungen.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .navigationTitle("Loggen")
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
    }
}
