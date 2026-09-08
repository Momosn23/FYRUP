import SwiftUI

struct WeeklyScheduleView: View {
    @Environment(AppStore.self) private var store
    @State private var weekOffset = 0
    @State private var openedDay: Date?
    private var anchor: Date { Calendar.current.date(byAdding: .weekOfYear, value: weekOffset, to: store.presentationDate) ?? store.presentationDate }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Wochenplan").font(.title.bold())
                Picker("Woche", selection: $weekOffset) { Text("Diese Woche").tag(0); Text("Nächste Woche").tag(1) }.pickerStyle(.segmented)
                HStack(spacing: 4) {
                    ForEach(TrainingWeekLogic.days(containing: anchor), id: \.self) { day in
                        Button { openedDay = day } label: {
                            VStack(spacing: 7) {
                                Text(day.formatted(.dateTime.weekday(.abbreviated))).font(.caption)
                                Text(day.formatted(.dateTime.day())).font(.subheadline.bold())
                            }.frame(maxWidth: .infinity, minHeight: 58)
                                .foregroundStyle(Calendar.current.isDate(day, inSameDayAs: store.presentationDate) ? .white : FYColor.ink)
                                .background(Calendar.current.isDate(day, inSameDayAs: store.presentationDate) ? FYColor.lime : .clear, in: RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(.plain).accessibilityLabel(day.formatted(.dateTime.weekday(.wide).day().month()))
                    }
                }
                if store.personal.isLoadingWeek { ProgressView("Woche laden …").frame(maxWidth: .infinity) }
                ForEach(TrainingWeekLogic.days(containing: anchor), id: \.self) { day in
                    Button { openedDay = day } label: { dayRow(day) }.buttonStyle(.plain)
                }
                if let error = store.personal.weekError { Text(error).font(.footnote).foregroundStyle(FYColor.muted) }
                Button("Session planen") { store.activityComposerMode = 1; store.showsActivityComposer = true }.buttonStyle(PrimaryButtonStyle())
                NavigationLink { TrainingRoutineEditor(isOnboarding: false) } label: { Label("Persönliche Wochenwünsche", systemImage: "slider.horizontal.3") }.font(.subheadline)
            }.padding(FYLayout.page)
        }.background(FYColor.background).navigationBarHidden(true)
            .task(id: "\(weekOffset)-\(store.selectedTab)-\(store.friendAccessRevision)") {
                guard store.selectedTab == 1 else { return }
                if store.selectedWeekDate != nil && weekOffset != 0 { weekOffset = 0; return }
                await store.personal.loadWeek(now: anchor)
                if let day = store.selectedWeekDate { openedDay = day; store.selectedWeekDate = nil }
            }
            .sheet(isPresented: Binding(get: { openedDay != nil }, set: { if !$0 { openedDay = nil } })) {
                if let day = openedDay { NavigationStack { TrainingDayView(day: day) } }
            }
            .refreshable { await store.refresh(); await store.personal.loadWeek(now: anchor) }
    }
    private func dayRow(_ day: Date) -> some View {
        let completed = store.profile.map { TrainingWeekLogic.completed(store.personal.week?.activities ?? [], owner: $0.id, day: day) } ?? []
        let sessions = store.personal.week?.sessions.filter { Calendar.current.isDate($0.startsAt, inSameDayAs: day) } ?? []
        return HStack(alignment: .top, spacing: 14) {
            Image(systemName: !completed.isEmpty ? "checkmark.circle.fill" : "circle")
                .font(.title2).foregroundStyle(!completed.isEmpty ? FYColor.lime : FYColor.line)
            VStack(alignment: .leading, spacing: 8) {
                Text(day.formatted(.dateTime.weekday(.wide))).font(.headline)
                ForEach(completed) { activity in Text("\(activity.sport.title) · DONE").font(.subheadline).foregroundStyle(FYColor.muted) }
                ForEach(sessions) { session in
                    Text("\(session.sport.title) · \(session.startsAt.formatted(date: .omitted, time: .shortened))").font(.subheadline).foregroundStyle(FYColor.muted)
                }
                if completed.isEmpty && sessions.isEmpty { Text("Keine Session geplant").font(.subheadline).foregroundStyle(FYColor.muted) }
            }.frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right").font(.caption).padding(.top, 6)
        }.foregroundStyle(FYColor.ink).padding(.vertical, 12)
    }
}
