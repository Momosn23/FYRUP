import SwiftUI

struct LiveAndRestSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FYLayout.section) {
                LiveActivitySetupCard()
                NavigationLink { WorkoutRestSettingsView() } label: {
                    HStack { Label("Eigene Satzpause", systemImage: "timer"); Spacer(); Image(systemName: "chevron.right") }
                        .frame(minHeight: 52).fyCard()
                }
            }.padding(FYLayout.page)
        }.background(FYColor.background).navigationTitle("LIVE & Satzpausen").navigationBarTitleDisplayMode(.inline)
    }
}
