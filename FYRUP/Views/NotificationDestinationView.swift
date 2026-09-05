import SwiftUI

/// Shared entry point for push taps and the in-app inbox. The notification's
/// receipt authorizes only the link; the actual destination is fetched again.
struct NotificationDestinationView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    let presentation: NotificationPresentation
    @State private var isLoading = true
    @State private var authorized = false
    @State private var invitation: SessionInvitation?
    @State private var hosted: HostedSession?
    @State private var activity: NotificationActivityDetail?
    @State private var loadTicket = UUID()
    @State private var handledSupplementAction = false

    var body: some View {
        NavigationStack {
            Group {
                if !store.notificationRouting.isCurrent(presentation) { unavailable }
                else if isLoading { ProgressView("Mitteilung wird geöffnet …").frame(maxWidth: .infinity, maxHeight: .infinity) }
                else if authorized { destination }
                else { unavailable }
            }
            .background(FYColor.background)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } } }
        }
        .task(id: presentation.id) { await load() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await load() } } }
    }

    private var unavailable: some View {
        ContentUnavailableView {
            Label("Nicht mehr verfügbar", systemImage: "bell.slash")
        } description: {
            Text("Die Aktivität oder Mitteilung ist nicht mehr aktuell, oder der Zugriff wurde geändert.")
        } actions: {
            Button("Erneut prüfen") { Task { await load() } }.buttonStyle(OutlineButtonStyle())
        }
    }

    @ViewBuilder private var destination: some View {
        switch presentation.destination {
        case .inbox: NotificationCenterView()
        case .friends: FriendsView()
        case .blindWorkout(let id): BlindWorkoutDetailView(id: id)
        case .workoutPlan(let id): WorkoutPlanDetailView(planID: id)
        case .supplement(let id): SupplementsView(highlightedDoseID: id)
        case .session:
            if let invitation { InvitationDetailView(invitation: invitation) }
            else if let hosted { HostedSessionView(hosted: hosted) }
            else { unavailable }
        case .activity:
            if let activity { ActivityDetailView(activity: activity.activity, owner: activity.owner) }
            else { unavailable }
        case .weekly(let userID, _, _):
            if let week = selectedWeek {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Woche ab \(week.weekStartDate)").font(.title2.bold())
                        WeeklyProgressContent(week: week).fyCard()
                        if (userID ?? presentation.userID) == presentation.userID {
                            if let commitment = week.commitment {
                                ShotStatusBadge(commitment: commitment)
                                Text(commitment.statusText).foregroundStyle(FYColor.muted)
                            }
                            NavigationLink { WeeklyFlameDetailView() } label: { Text("Meine Wochenübersicht") }.buttonStyle(OutlineButtonStyle())
                        } else { FriendShotContent(week: week) }
                    }.padding(20)
                }.navigationTitle("Wochenziel")
            } else { unavailable }
        }
    }

    private var selectedWeek: WeeklyProgress? {
        guard case .weekly(let userID, let weekID, let commitmentID) = presentation.destination else { return nil }
        let owner = userID ?? presentation.userID
        let state = owner == presentation.userID ? (store.weekly.isStateConfirmed ? store.weekly.state : nil) : store.weekly.friend(userID: owner)
        guard let state, state.userID == owner, state.isValid else { return nil }
        let weeks = [state.currentWeek].compactMap { $0 } + state.history
        guard let week = weekID.flatMap({ id in weeks.first { $0.id == id } }) ?? (weekID == nil ? state.currentWeek : nil),
              commitmentID == nil || week.commitment?.id == commitmentID else { return nil }
        return week
    }

    private func load() async {
        guard store.notificationRouting.isCurrent(presentation), !Task.isCancelled else { return }
        let ticket = UUID(); loadTicket = ticket
        defer { if isCurrent(ticket) { isLoading = false } }
        isLoading = true; authorized = false; invitation = nil; hosted = nil; activity = nil
        do {
            switch presentation.destination {
            case .inbox, .friends:
                await store.refresh()
            case .blindWorkout(let id):
                let value = try await store.repository.blindWorkout(id: id)
                guard value.summary.id == id, value.isValid,
                      (value.viewerRole == .creator ? value.summary.creatorID : value.summary.recipientID) == presentation.userID else { throw AppError.accessDenied }
            case .workoutPlan(let id):
                let value = try await store.repository.workoutPlan(id: id)
                guard value.id == id, value.validationMessage == nil else { throw AppError.accessDenied }
            case .supplement(let id):
                await store.supplements.refresh()
                guard isCurrent(ticket), store.supplements.ownerID == presentation.userID,
                      store.supplements.isCurrentDay, store.supplements.errorMessage == nil,
                      let dose = store.supplements.snapshot?.doses.first(where: { $0.id == id }) else { throw AppError.accessDenied }
                if presentation.marksSupplementTaken && !handledSupplementAction {
                    handledSupplementAction = true
                    if dose.status == .open {
                        await store.supplements.mark(id, as: .taken, requestID: presentation.notificationID)
                    }
                }
            case .session(let id):
                let invitations = try await store.repository.invitations()
                let sessions = try await store.repository.hostedSessions()
                guard isCurrent(ticket) else { return }
                invitation = invitations.first { $0.sessionID == id && $0.session.id == id }
                hosted = sessions.first { $0.id == id && $0.session.hostID == presentation.userID }
                guard invitation != nil || hosted != nil else { throw AppError.accessDenied }
            case .activity(let id):
                let value = try await store.repository.activityForNotification(id: id, userID: presentation.userID)
                guard isCurrent(ticket) else { return }
                guard let value, value.activity.id == id, value.owner.id == value.activity.userID else { throw AppError.accessDenied }
                activity = value
            case .weekly(let userID, _, _):
                let owner = userID ?? presentation.userID
                if owner == presentation.userID {
                    await store.weekly.refresh(force: true)
                    guard !store.weekly.isLoading, store.weekly.isStateConfirmed else { throw AppError.server }
                } else { _ = await store.weekly.loadFriend(userID: owner) }
                guard selectedWeek != nil else { throw AppError.accessDenied }
            }
            guard isCurrent(ticket) else { return }
            authorized = true
        } catch {
            guard isCurrent(ticket) else { return }
            authorized = false; invitation = nil; hosted = nil; activity = nil
        }
    }

    private func isCurrent(_ ticket: UUID) -> Bool {
        loadTicket == ticket && store.notificationRouting.isCurrent(presentation) && !Task.isCancelled
    }
}
