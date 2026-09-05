import PhotosUI
import SwiftUI
import UIKit

struct AvatarPicker: View {
    let profile: Profile?
    @Binding var jpegData: Data?
    @State private var selection: PhotosPickerItem?
    @State private var showsPhotoPicker = false

    var body: some View {
        // Build the avatar in SwiftUI's UI isolation. Older PhotosUI SDKs make
        // PhotosPicker's label closure nonisolated; the native sheet modifier
        // keeps the same system picker without moving UI state across actors.
        Button { showsPhotoPicker = true } label: {
            ZStack(alignment: .bottomTrailing) {
                avatar
                    .frame(width: 92, height: 92)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(FYColor.lime.opacity(0.45), lineWidth: 2))
                    .shadow(color: FYColor.ink.opacity(0.10), radius: 8, y: 4)
                Image(systemName: "camera.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(FYColor.ink, in: Circle())
                    .overlay(Circle().stroke(.white, lineWidth: 2))
            }
        }
        .buttonStyle(.plain)
        .photosPicker(isPresented: $showsPhotoPicker, selection: $selection, matching: .images)
        .accessibilityLabel("Profilbild auswählen")
        .onChange(of: selection) { _, item in
            Task {
                guard let item,
                      let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                jpegData = image.avatarJPEG()
            }
        }
    }

    @ViewBuilder private var avatar: some View {
        if let jpegData, let image = UIImage(data: jpegData) {
            Image(uiImage: image).resizable().scaledToFill()
        } else if let profile {
            AvatarView(profile: profile).scaleEffect(1.9)
        } else {
            Circle().fill(LinearGradient(colors: [FYColor.limeSoft, FYColor.elevated], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(Image(systemName: "person.fill").font(.system(size: 38)).foregroundStyle(FYColor.muted))
        }
    }
}

private extension UIImage {
    func avatarJPEG() -> Data? {
        let maximumSide: CGFloat = 1024
        let scale = min(1, maximumSide / max(size.width, size.height))
        let target = CGSize(width: max(1, size.width * scale), height: max(1, size.height * scale))
        let renderer = UIGraphicsImageRenderer(size: target)
        let resized = renderer.image { _ in draw(in: CGRect(origin: .zero, size: target)) }
        return resized.jpegData(compressionQuality: 0.82)
    }
}
