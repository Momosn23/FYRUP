import Contacts
import XCTest
@testable import FYRUP

final class ContactInviteTests: XCTestCase {
    func testSelectedPhoneNumberIsKeptWithoutReadingAnotherNumber() throws {
        let contact = CNMutableContact()
        contact.givenName = "Max"
        contact.familyName = "Muster"
        contact.phoneNumbers = [
            CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: "+49 170 1111111")),
            CNLabeledValue(label: CNLabelHome, value: CNPhoneNumber(stringValue: "+49 221 2222222"))
        ]

        let selected = try XCTUnwrap(InviteContact(contact: contact, phoneNumber: contact.phoneNumbers[1].value.stringValue))

        XCTAssertEqual(selected.name, "Max Muster")
        XCTAssertEqual(selected.phoneNumber, "+49 221 2222222")
    }

    func testEmptyPhoneNumberIsRejectedAndUnnamedContactGetsNeutralName() throws {
        let contact = CNMutableContact()
        XCTAssertNil(InviteContact(contact: contact, phoneNumber: "  \n"))

        let selected = try XCTUnwrap(InviteContact(contact: contact, phoneNumber: "123"))
        XCTAssertEqual(selected.name, "Ausgewählter Kontakt")
        XCTAssertEqual(selected.phoneNumber, "123")
    }
}
