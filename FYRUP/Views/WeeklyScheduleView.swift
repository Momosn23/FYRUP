import SwiftUI

struct WeeklyScheduleView: View {
    @Environment(AppStore.self) private var store
    @State private var weekOffset = 0
    @State private var openedDay: Date?
    private var anchor: Date { Calendar.current.date(byAdding: .weekOfYear, value: weekOffset, to: store.presentationDate) ?? store.presentationDate }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
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
                VStack(spacing: 0) {
                    let days = TrainingWeekLogic.days(containing: anchor)
                    ForEach(days, id: \.self) { day in
                        let weekday = TrainingWeekLogic.weekday(day)
                        Button { openedDay = day } label: { dayRow(day) }.buttonStyle(FYPressStyle())
                            .accessibilityIdentifier("week-day-row-\(weekday)")
                        if day != days.last { Divider() }
                    }
                }.fyCard(padding: 12)
                if let error = store.personal.weekError { Text(error).font(.footnote).foregroundStyle(FYColor.muted) }
                Button("Session planen") { store.activityComposerMode = 1; store.showsActivityComposer = true }.buttonStyle(PrimaryButtonStyle())
                NavigationLink { TrainingRoutineEditor(isOnboarding: false) } label: { Label("Persönliche Wochenwünsche", systemImage: "slider.horizontal.3").frame(minHeight: 44) }.font(.subheadline)
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
        let hasMatchingWeek = store.personal.weekInterval.map { $0.start <= day && day < $0.end } ?? false
        let snapshot = hasMatchingWeek ? store.personal.week : nil
        let summary = WeeklyDaySummary(snapshot: snapshot, ownerID: store.profile?.id, day: day)
        return HStack(alignment: .center, spacing: 12) {
            Image(systemName: !summary.planned.isEmpty ? "clock" : !summary.completed.isEmpty ? "checkmark.circle.fill" : "circle")
                .font(.title2).foregroundStyle(!summary.completed.isEmpty || !summary.planned.isEmpty ? FYColor.lime : FYColor.line)
            VStack(alignment: .leading, spacing: 2) {
                Text(day.formatted(.dateTime.weekday(.wide))).font(.subheadline.weight(.semibold))
                Text(summary.title).font(.subheadline).foregroundStyle(FYColor.ink)
                if let detail = summary.detail { Text(detail).font(.footnote).foregroundStyle(FYColor.muted) }
            }.frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right").font(.caption)
        }.foregroundStyle(FYColor.ink).frame(minHeight: 44).padding(.vertical, 8).contentShape(Rectangle())
    }
}
