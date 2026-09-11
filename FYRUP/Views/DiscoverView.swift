import SwiftUI

struct DiscoverView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var query = ""
    @State private var section = DiscoverySection.all
    @State private var selectedSport: SportKind?
    @FocusState private var searching: Bool
    private var owner: UUID? { store.profile?.id == store.workouts.userID ? store.profile?.id : nil }
    private var exercises: [GymExercise] { DiscoveryContent.exercises(store.workouts.exercises, owner: owner, query: query) }
    private var plans: [WorkoutPlan] { DiscoveryContent.plans(store.workouts.plans, owner: owner, query: query) }
    private var sports: [SportKind] { DiscoveryContent.sports(query: query) }
    private var columns: [GridItem] { Array(repeating: GridItem(.flexible(minimum: 0), spacing: 12, alignment: .top), count: typeSize.isAccessibilitySize ? 1 : 2) }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: FYLayout.section) {
                    FYRUPWordmark(size: 22)
                    Text("Entdecken").font(.largeTitle.weight(.black)).accessibilityIdentifier("discover-title")
                    searchField
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 8), count: typeSize.isAccessibilitySize ? 1 : 4), spacing: 8) {
                            ForEach(DiscoverySection.allCases) { item in
                                Button { searching = false; section = item } label: {
                                    Text(item.title).font(.subheadline.weight(.semibold))
                                        .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                                        .minimumScaleFactor(typeSize.isAccessibilitySize ? 1 : 0.8)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .padding(.horizontal, 6).padding(.vertical, 6).frame(maxWidth: .infinity, minHeight: 44)
                                        .foregroundStyle(section == item ? .white : FYColor.ink)
                                        .background(section == item ? FYColor.lime : FYColor.elevated, in: Capsule())
                                }.buttonStyle(FYPressStyle()).accessibilityIdentifier("discover-filter-\(item.id)")
                                    .accessibilityAddTraits(section == item ? .isSelected : [])
                            }
                    }
                    if section == .all && query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Dein nächster Schritt").font(.title3.bold())
                            LazyVGrid(columns: columns, spacing: 12) {
                                NavigationLink { WorkoutPlansView() } label: {
                                    DiscoveryImageCard(title: "Deine Workout-Pläne", subtitle: "Öffnen oder selbst zusammenstellen", asset: "SportGymHero")
                                }.buttonStyle(FYPressStyle()).accessibilityIdentifier("discover-open-plans")
                                Button { store.selectedTab = 1 } label: {
                                    DiscoveryImageCard(title: "Deine Woche", subtitle: "Aktivitäten und Sessions im Blick", asset: "SportRunningHero")
                                }.buttonStyle(FYPressStyle()).accessibilityIdentifier("discover-open-week")
                            }
                        }
                    }
                    if section == .all || section == .workouts { planSection }
                    if section == .all || section == .exercises { exerciseSection }
                    if section == .all || section == .sports { sportSection }
                    if let error = store.workouts.errorMessage {
                        WorkoutErrorBanner(message: error) { Task { await reload() } }
                    }
                }
                .frame(width: max(0, geometry.size.width - FYLayout.page * 2), alignment: .leading)
                .padding(.horizontal, FYLayout.page).padding(.vertical, 16)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: section)
            }.scrollDismissesKeyboard(.interactively).refreshable { await reload() }
        }.background(FYColor.background).toolbar(.hidden, for: .navigationBar)
            .task(id: store.session?.userID) { await reload() }
            .fullScreenCover(item: $selectedSport) { sport in ActivityComposerView(initialSport: sport) }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(FYColor.muted)
            TextField("Übungen, Pläne, Sportarten", text: $query).autocorrectionDisabled().focused($searching)
                .submitLabel(.search).onSubmit { searching = false }.accessibilityIdentifier("discover-search")
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44) }
                    .accessibilityLabel("Suche löschen")
            }
        }.padding(.leading, 14).padding(.trailing, query.isEmpty ? 14 : 0).frame(minHeight: 52)
            .background(FYColor.elevated, in: RoundedRectangle(cornerRadius: 14))
    }

    private var sportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Was hast du vor?").font(.title3.bold())
            if sports.isEmpty { empty("Keine passende Sportart") }
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(section == .sports || !query.isEmpty ? sports : Array(sports.prefix(4))) { sport in
                    Button { searching = false; selectedSport = sport } label: {
                        ZStack(alignment: .bottomLeading) {
                            SportPhoto(sport: sport)
                            LinearGradient(colors: [.clear, .black.opacity(0.80)], startPoint: .top, endPoint: .bottom)
                            HStack {
                                Label(sport.title, systemImage: sport.symbol).font(.headline.bold())
                                Spacer(); Image(systemName: "arrow.up.right").font(.caption.bold())
                            }.foregroundStyle(.white).padding(12)
                        }
                        .frame(maxWidth: .infinity, minHeight: 138)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }.buttonStyle(FYPressStyle()).accessibilityLabel(sport.title)
                }
            }
            if section != .sports && query.isEmpty {
                Button("Alle Sportarten ansehen") { section = .sports }.frame(minHeight: 44)
                    .accessibilityIdentifier("discover-all-sports")
            }
        }
    }

    private var planSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Deine Workout-Pläne").font(.title3.bold())
            if store.workouts.isLoadingPlans && plans.isEmpty { ProgressView("Pläne laden …") }
            else if plans.isEmpty { empty(query.isEmpty ? "Noch kein eigener Workout-Plan" : "Kein passender Workout-Plan") }
            ForEach(section == .workouts || !query.isEmpty ? plans : Array(plans.prefix(3))) { plan in
                NavigationLink { WorkoutPlanDetailView(planID: plan.id) } label: { WorkoutPlanCard(plan: plan) }
                    .buttonStyle(FYPressStyle())
            }
            NavigationLink { WorkoutPlansView() } label: { Label("Pläne verwalten", systemImage: "list.clipboard").frame(minHeight: 44) }
                .accessibilityIdentifier("discover-manage-plans")
        }
    }

    private var exerciseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Übungsbibliothek").font(.title3.bold())
                Spacer(minLength: 4)
                Text("\(exercises.count)").font(.subheadline.monospacedDigit()).foregroundStyle(FYColor.muted)
            }
            if store.workouts.isLoadingLibrary && exercises.isEmpty { ProgressView("Übungen laden …") }
            else if exercises.isEmpty { empty("Keine passende Übung") }
            ForEach(section == .exercises || !query.isEmpty ? exercises : Array(exercises.prefix(5))) { exercise in
                NavigationLink { DiscoverExerciseDetailView(id: exercise.id) } label: {
                    HStack(spacing: 12) {
                        Image(exercise.editorialImage).resizable().scaledToFill().frame(width: 66, height: 54).clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous)).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.name).font(.subheadline.bold())
                            Text(exercise.subtitle).font(.caption).foregroundStyle(FYColor.muted)
                        }
                        Spacer(minLength: 0); Image(systemName: "chevron.right").font(.caption)
                    }.foregroundStyle(FYColor.ink).frame(minHeight: 58).padding(.vertical, 7)
                }.buttonStyle(FYPressStyle()).accessibilityIdentifier("discover-exercise-\(exercise.id.uuidString.lowercased())")
            }
            if section != .exercises && query.isEmpty {
                Button("Alle Übungen ansehen") { section = .exercises }.frame(minHeight: 44).accessibilityIdentifier("discover-all-exercises")
            }
        }
    }

    private func empty(_ title: String) -> some View {
        Text(title).font(.subheadline).foregroundStyle(FYColor.muted).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
    }

    private func reload() async {
        guard let owner = store.session?.userID, store.workouts.userID == owner else { return }
        await store.workouts.loadLibrary()
        guard !Task.isCancelled, store.session?.userID == owner else { return }
        await store.workouts.loadPlans()
    }
}

private struct DiscoveryImageCard: View {
    let title: String
    let subtitle: String
    let asset: String
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: 108).overlay { Image(asset).resizable().scaledToFill() }.clipped().accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline).fixedSize(horizontal: false, vertical: true)
                Text(subtitle).font(.caption).foregroundStyle(FYColor.muted).fixedSize(horizontal: false, vertical: true)
            }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
        }.foregroundStyle(FYColor.ink).background(.white).clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(FYColor.line, lineWidth: 0.5))
    }
}

private struct DiscoverExerciseDetailView: View {
    @Environment(AppStore.self) private var store
    let id: UUID
    private var exercise: GymExercise? {
        guard store.profile?.id == store.workouts.userID else { return nil }
        return DiscoveryContent.exercises(store.workouts.exercises, owner: store.profile?.id, query: "").first { $0.id == id }
    }
    var body: some View {
        ScrollView {
            if let exercise {
                VStack(alignment: .leading, spacing: FYLayout.section) {
                    Text(exercise.name).font(.title.bold()).accessibilityIdentifier("discover-exercise-title")
                    ExercisePhoto(exercise: exercise).frame(maxWidth: .infinity).frame(height: 230)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    VStack(alignment: .leading, spacing: 14) {
                        Label(exercise.primaryMuscle.title, systemImage: "figure.stand")
                        Label(exercise.equipment.title, systemImage: "dumbbell")
                        Label(exercise.isTimed ? "Vorgaben in Sekunden" : "Vorgaben in Wiederholungen", systemImage: "list.number")
                        if !exercise.secondaryMuscles.isEmpty {
                            Text("Weitere Muskeln: \(exercise.secondaryMuscles.map(\.title).joined(separator: ", "))").font(.subheadline)
                        }
                        if let note = exercise.note { Text(note).font(.subheadline).foregroundStyle(FYColor.muted) }
                    }.padding(.vertical, 12).overlay(alignment: .bottom) { Divider().overlay(FYColor.line) }
                    Button { Task { await store.workouts.toggleFavorite(id: id) } } label: {
                        Label(store.workouts.favorites.contains(id) ? "Favorit entfernen" : "Als Favorit speichern", systemImage: store.workouts.favorites.contains(id) ? "star.fill" : "star")
                    }.buttonStyle(OutlineButtonStyle()).disabled(store.workouts.isBusy).accessibilityIdentifier("discover-exercise-favorite")
                    NavigationLink { WorkoutPlansView() } label: { Text("Zu deinen Workout-Plänen") }.buttonStyle(PrimaryButtonStyle())
                    if let error = store.workouts.errorMessage { Text(error).font(.footnote).foregroundStyle(FYColor.muted) }
                }.padding(FYLayout.page)
            } else {
                ContentUnavailableView("Übung nicht verfügbar", systemImage: "dumbbell", description: Text("Öffne die Bibliothek erneut."))
            }
        }.background(FYColor.background).navigationTitle("Übung").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
    }
}
