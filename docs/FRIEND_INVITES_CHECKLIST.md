# Freunde einladen und über Kontakte finden

Nutzerergänzung vom 05.09.2026; teilweise im lokalen Quellstand, noch nicht nativ oder mit einem zweiten Konto abgenommen.

**Lokaler Link-/Teilen-Stand:** Auf „Freunde“ gibt es eine native iOS-Teilen-Auswahl für eine allgemeine FYRUP-Einladung und getrennt für den persönlichen Profilpfad. Empfänger und Ziel-App werden nie vorausgewählt. Weil derzeit kein bestätigter öffentlicher App-Store- oder TestFlight-Link vorliegt, sagt die Oberfläche ausdrücklich „privater iPhone-Test“ und erfindet keinen Installationsweg. Der strikte Pfad `fyrup://profile/<username>` enthält keine Personendaten außer dem ohnehin öffentlichen Username, keine Zugangsdaten/Parameter und funktioniert nur bei installierter App. Nach Login wird der Username serverseitig gesucht; nur ein tatsächlich auffindbares Profil öffnet eine datensparsame Ansicht mit optionaler Freundschaftsanfrage. Zwei Parser-Tests sind vorbereitet. Telefonnummern, Verifizierung und Kontaktabgleich bleiben bewusst offen, weil noch kein freigegebener SMS-Anbieter, keine Nummernschema-Migration und kein öffentlicher Installationslink bestehen.

- [x] INVITE-01 Auf Freunde finden: native Teilen-Auswahl für eine Einladung außerhalb der App. *(Quellstand; Geräteabnahme offen.)*
- [ ] INVITE-02 Persönlichen Profillink teilen; installierte App öffnet das richtige Profil, ansonsten verlässlicher Installationsweg.
- [x] INVITE-03 TestFlight und öffentliche Store-Version unterscheiden; keinen noch nicht nutzbaren Store-/Beta-Link als funktionierend ausgeben. *(Quellstand mit ehrlichem Hinweis auf privaten Test.)*
- [ ] INVITE-04 Telefonnummer freiwillig hinzufügen und verifizieren, ohne bestehendes Apple-/E-Mail-Konto durch ein zweites Konto zu ersetzen.
- [ ] INVITE-05 Über die eigene Nummer auffindbar nur nach gesonderter Einwilligung, jederzeit widerrufbar; Nummer nie im öffentlichen Profil.
- [ ] INVITE-06 Kontakte nur nach nativer Zustimmung, inklusive beschränktem Kontaktezugriff; keine ungefragte Adressbuchübertragung.
- [ ] INVITE-07 Kontaktabgleich datensparsam, authentifiziert und begrenzt; nur verifizierte und ausdrücklich auffindbare Konten als Treffer.
- [x] INVITE-08 Keine automatischen SMS, WhatsApp-Nachrichten oder Freundesanfragen; Empfänger und Versand wählt der Nutzer. *(Quellstand.)*
- [ ] INVITE-09 Ablehnung/Widerruf, Nummernnormalisierung, Blockierung, Deep-Link-Login-Fortsetzung und Konto-/Gerätewechsel testen.
- [ ] INVITE-10 SMS-Versandkonfiguration und tatsächlich nutzbaren Einladungslink prüfen; mögliche externe Freigabe-/Dienstkosten nicht stillschweigend einrichten.
