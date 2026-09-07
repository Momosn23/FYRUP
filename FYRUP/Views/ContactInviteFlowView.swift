import ContactsUI
import MessageUI
import SwiftUI

struct InviteContact: Identifiable {
    let id = UUID()
    let name: String
    let phoneNumber: String

    init?(contact: CNContact, phoneNumber: String?) {
        guard let number = phoneNumber?.trimmingCharacters(in: .whitespacesAndNewlines), !number.isEmpty else { return nil }
        let formattedName = CNContactFormatter.string(from: contact, style: .fullName)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.name = if let formattedName, !formattedName.isEmpty { formattedName } else { "Ausgewählter Kontakt" }
        self.phoneNumber = number
    }
}

struct ContactInviteFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showsPicker = false
    @State private var selectedContact: InviteContact?
    @State private var showsMessage = false

    private let invitation = "Komm zu FYRUP – gemeinsam aktiv, mit echten Sessions und deiner Crew. FYRUP befindet sich aktuell im privaten iPhone-Test; den Testzugang sende ich dir separat."

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Image(systemName: "person.2.crop.square.stack.fill")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(FYColor.lime)
                        .symbolEffect(.pulse, options: .repeating.speed(0.35))
                    Text("Aus Kontakten einladen").font(.largeTitle.weight(.black))
                    Text("Du wählst genau eine Person im iPhone-Dialog aus. FYRUP liest nur den ausgewählten Namen und die ausgewählte Telefonnummer, um eine Nachricht vorzubereiten.")
                        .foregroundStyle(FYColor.muted)
                    Label("Kein Adressbuch-Upload", systemImage: "lock.shield.fill")
                    Label("Keine Nachricht ohne dein Tippen auf Senden", systemImage: "hand.tap.fill")
                    Label("Keine automatische Freundschaftsanfrage", systemImage: "person.crop.circle.badge.checkmark")

                    Button { showsPicker = true } label: {
                        Label(selectedContact == nil ? "KONTAKT AUSWÄHLEN" : "ANDEREN KONTAKT WÄHLEN", systemImage: "person.crop.circle.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("choose-invite-contact")

                    if let selectedContact {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Ausgewählt").font(.caption.weight(.black)).foregroundStyle(FYColor.muted)
                            Text(selectedContact.name).font(.headline)
                            Text("Die Telefonnummer bleibt auf deinem iPhone.").font(.caption).foregroundStyle(FYColor.muted)
                            if MFMessageComposeViewController.canSendText() {
                                Button { showsMessage = true } label: {
                                    Label("NACHRICHT VORBEREITEN", systemImage: "message.fill").frame(maxWidth: .infinity)
                                }
                                .buttonStyle(PrimaryButtonStyle())
                                .accessibilityIdentifier("prepare-contact-invite")
                            } else {
                                ShareLink(item: invitation) {
                                    Label("EINLADUNG TEILEN", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                                }
                                .buttonStyle(PrimaryButtonStyle())
                            }
                        }
                        .fyCard()
                    }

                    Text("Bereits registrierte Personen über ihre Telefonnummer zu erkennen folgt erst mit freiwilliger Nummernverifizierung und gesonderter Auffindbarkeitsfreigabe. Bis dahin wird nichts abgeglichen.")
                        .font(.caption2)
                        .foregroundStyle(FYColor.muted)
                        .accessibilityIdentifier("contact-matching-limit")
                }
                .padding(20)
            }
            .background(FYColor.background)
            .navigationTitle("Kontakt einladen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } } }
            .sheet(isPresented: $showsPicker) {
                ContactPicker { contact in selectedContact = contact }
            }
            .sheet(isPresented: $showsMessage) {
                if let selectedContact {
                    MessageComposer(recipient: selectedContact.phoneNumber, body: invitation)
                }
            }
        }
    }
}

private struct ContactPicker: UIViewControllerRepresentable {
    let onSelection: (InviteContact) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onSelection: onSelection) }

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
        picker.predicateForSelectionOfContact = NSPredicate(value: false)
        picker.predicateForSelectionOfProperty = NSPredicate(format: "key == 'phoneNumbers'")
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onSelection: (InviteContact) -> Void

        init(onSelection: @escaping (InviteContact) -> Void) { self.onSelection = onSelection }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            guard let selected = InviteContact(contact: contact, phoneNumber: contact.phoneNumbers.first?.value.stringValue) else { return }
            onSelection(selected)
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contactProperty: CNContactProperty) {
            guard contactProperty.key == CNContactPhoneNumbersKey,
                  let phone = contactProperty.value as? CNPhoneNumber,
                  let selected = InviteContact(contact: contactProperty.contact, phoneNumber: phone.stringValue) else { return }
            onSelection(selected)
        }
    }
}

private struct MessageComposer: UIViewControllerRepresentable {
    let recipient: String
    let body: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let composer = MFMessageComposeViewController()
        composer.messageComposeDelegate = context.coordinator
        composer.recipients = [recipient]
        composer.body = body
        return composer
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            controller.dismiss(animated: true)
        }
    }
}
