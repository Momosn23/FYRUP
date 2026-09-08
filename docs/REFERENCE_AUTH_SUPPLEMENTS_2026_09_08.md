# Folgeblock: E-Mail-Anmeldung, Supplements und Veröffentlichungsvoraussetzungen

Stand 08.09.2026, gebündelte Arbeitskopie nach `e39caf6`. **Noch kein nativer Nachweis für diesen Code.** #67 belegt nur den vorherigen Stand. Kein Apple-Upload aus diesem Block.

## Im Code ergänzt

- R01/R02: direkter Willkommen-Einstieg und eigene Anmeldeart statt der alten dreiteiligen Einführung. Echte Apple-/E-Mail-Aktionen; kein funktionsloser Google-Button. Bestehendes Motiv bleibt vorläufig; genaue Bergvorlage und Nutzungsnachweis fehlen.
- R03: Passwort sichtbar/verdeckt, Inline-Rückmeldung und Trennung zwischen Registrierung, Login und Reset. Mindestlänge 6 entspricht der tatsächlich gelesenen Supabase-Konfiguration; keine nicht vorhandenen Pflichtregeln für Großbuchstaben/Zahlen vortäuschen. Längeres einzigartiges Passwort wird empfohlen. Versand/Anmeldung sperren konkurrierende Formularaktionen.
- R03a: eigene Bestätigungsseite mit maskierter Adresse, 60-Sekunden-Abstand, erneutem Versand und Wechsel der Adresse. Rückkehr auf demselben iPhone über exakt `fyrup://auth-callback`. Bei erneutem Versand neue PKCE-Challenge und lokaler Beweis.
- R03c: Passwort-Reset erhält einen separaten Zustand und eine eigene Eingabeseite. Der E-Mail-Code wird mit dem zufälligen lokalen PKCE-Beweis beim Server getauscht; keine Tokens aus Links akzeptieren. Ein Recovery-Token aktiviert weder Heute noch Health-/Social-Stores. Nach erfolgreichem Passwortwechsel zurück zum normalen Login, kein automatisches Einloggen.
- Der ausstehende Vorgang inklusive Beweis liegt in einer gerätegebundenen Keychain, nicht in Logs/UserDefaults. Fremde Hosts, Pfade, URL-Zugangsdaten, Fragmente, doppelte Codes, abgelaufene und wiederverwendete Vorgänge werden verworfen. Während einer laufenden Anfrage wird genau ein gültiger Callback nur im Speicher zur anschließenden Verarbeitung vorgemerkt.
- Bekannte endgültige Ablehnungen stellen den vorherigen ausstehenden Vorgang wieder her bzw. löschen die fehlgeschlagene Neuanfrage. Ungewisse Transport-/Serverantworten behalten den Beweis, falls die Mail bereits versandt wurde; sie werden nicht als Erfolg gemeldet.
- Supabase-Fehlerdecoder versteht auch `error_code`, `msg` und numerisches `code`. Logs enthalten nur begrenzte technische Fehlercodes, niemals Request-Body, E-Mail-Adresse, Passwort oder Token.
- R11/R11a/A22: echtes Auswahlraster mit vorhandenen Einträgen; selbst gewählte optionale Menge und Einheit im Editor, Tagesliste und auf Heute. Keine Dosierungsvorgaben. Keine neue Erinnerungszustimmung durch Mengenwahl. Mengen werden mit den vorhandenen privaten Supplement-Daten gespeichert.
- Migration 019: optionale Menge, serverseitige Validierung, eigene Kontorechte und bestehender Versionskonfliktschutz. Alte App-Versionen ohne Mengenfeld löschen den neuen Wert nicht; explizites `null` entfernt ihn bewusst. Keine Änderung älterer angewendeter Migrationen.

## Tatsächlich produktiv kontrolliert

- Supabase-Projekt `dwpuzcpnzldlnadfivcm`: E-Mail/Apple aktiviert, Google deaktiviert. E-Mail-Bestätigung aktiviert. Passwort mindestens 6 Zeichen, keine zusätzlichen Zeichenklassen. Diese Anbieter-/Passwortregeln wurden nicht verändert.
- Nach konkreter Nutzerfreigabe Site URL von `http://localhost:3000` auf `fyrup://auth-callback` geändert, exakt dieselbe Rückkehradresse erlaubt. Nach Neuladen geprüft: genau ein Eintrag, kein Wildcard. Das lokale `supabase/config.toml` folgt derselben Rückkehradresse.
- Eigener SMTP-Versand fehlt. Supabase-Standardversand ist für Projektmitglieder gedacht, nicht für normale öffentliche Registrierung. [Offizielle Supabase-Dokumentation](https://supabase.com/docs/guides/auth/auth-smtp).
- Nutzer hat `Kundenservice@objektsignal.com` als vorhandenen Absender freigegeben. Sendername „FYRUP“ und Adresse im SMTP-Formular vorbereitet, **nicht gespeichert/aktiviert**, kein Passwort hinterlegt.
- Öffentliche MX-Einträge zeigen Zoho EU. Der genaue SMTP-Server hängt laut [Zoho](https://www.zoho.com/mail/help/zoho-smtp.html) von Kontotyp/Datacenter ab; MX allein ist kein ausreichender Nachweis für den Ausgangsserver. Die vorhandene Zoho-Sitzung öffnete ein anderes Postfach; Sicherheitsprüfung stoppte weiteren Zugriff. Nutzer wurde gebeten, zum freigegebenen Postfach und dessen Servereinstellungen zu wechseln. Kein neues Abo, kein Anbieterwechsel, keine DNS-Änderung.
- Migrationen **017/018/019 noch nicht produktiv angewendet**. Die SQL-Tests laufen ausschließlich in einer isolierten Wegwerf-Datenbank.

## Datenschutz / Rechtstexte

Der Nutzerlink `https://objektsignal.com/datenschutz` beschreibt die Immobilienplattform, nicht FYRUP. Er wird nicht als FYRUP-Datenschutzerklärung ausgegeben. Die lokale Willkommensseite benennt ihn ausdrücklich als „Datenschutz der ObjektSignal-Website“; das ist ein vorläufiger, **nicht veröffentlichungsreifer** Zustand.

Auf ausdrücklichen Wunsch liegt ein [separater FYRUP-Entwurf](FYRUP_PRIVACY_DRAFT_2026_09_08.md) vor. Nicht veröffentlicht, bestehende Website nicht überschrieben. Verantwortlicher, Verarbeitungsgrundlagen insbesondere für Gesundheitsdaten, Dienstleisterverträge/Region, Fristen, Löschumfang, Zielalter und Kontaktangaben sind vor Freigabe zu bestätigen. Eigene veröffentlichte FYRUP-URL und Nutzungsbedingungen fehlen weiterhin.

## Prüfungen – strikt getrennt

| Ebene | Stand |
| --- | --- |
| Lokaler Gesamt-Preflight | 08.09.2026, 14:04 UTC: **21/21 PASS**, einschließlich der aktuellen Auth-/Supplement-Dateien; kein Swift-Compiler |
| Isolierte SQL-Tests | 019 mit Wiederholung, Erstellen/Lesen/Ändern/Löschen der Menge, Grenzen, Altdaten/Altclient, Versionskonflikt, fremdem Konto und anonymem Zugriff geprüft |
| Swift-Unit | 7 neue Auth-Tests sowie Supplement-Mengen-/Altformat-Test vorbereitet; **NICHT AUSGEFÜHRT** |
| Referenz-UI-Suite | 7 Tests vorbereitet: Heute/Navigation, Körperdaten, Großschrift, Auswahl/Summary, Ernährungsmengen, Willkommen/Anmeldeart, Supplementmenge; **NICHT AUSGEFÜHRT** |
| E-Mail-Zustellung | **NICHT AUSGEFÜHRT**. SMTP noch nicht fertig; kein Versand an erfundene Testempfänger |
| Echter Link / Mail-App / Kaltstart / Passwortwechsel auf iPhone | **NICHT AUSGEFÜHRT** |
| Native aktuelle Screenshots und TestFlight | **NICHT AUSGEFÜHRT**. Sieben ältere PNGs ausschließlich aus #67 |

Die gültige lokale Gesamtprüfung steht in `build/reference-preflight/report.json`. Sie enthält keinen Swift-Compiler. Ein grüner lokaler Lauf oder eine gespeicherte SMTP-Konfiguration ist kein Zustellungs- oder Produktnachweis.
