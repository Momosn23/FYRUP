# Folgeblock: E-Mail-Anmeldung, Supplements und Veröffentlichungsvoraussetzungen

Stand 08.09.2026, gebündelte Revision `4679d89`, geprüft in [QA #68](REFERENCE_QA_68.md): **510/511 Unit-Tests, 5/7 Referenz-UI-Tests PASS**, Gesamtstatus FAIL. Die drei eingegrenzten Testfehler sind in der Arbeitskopie korrigiert, noch ohne nativen Folgelauf. Kein Apple-Upload aus diesem Block.

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
- Eigener SMTP-Versand am 08.09.2026 eingerichtet und nach frischem Laden unabhängig bestätigt: aktiviert, Sendername **FYRUP**, Absender und SMTP-Benutzer **kundenservice@minaluneva.com**, Host **smtppro.zoho.eu**, Port **465/SSL**, Mindestabstand **60 Sekunden**. Das vom Nutzer selbst erstellte App-Passwort wurde ausschließlich in Supabase gespeichert, nicht in Repository/Prüfberichten. Kein normaler Login-Code; Zoho-MFA bleibt aktiviert.
- Die ursprünglich vorgesehene ObjektSignal-Adresse ist im selben Zoho-Konto als externe „Mail senden als“-Adresse vorhanden. Das beweist nicht, dass sie gegenüber einem externen SMTP-Client als echter Kontoalias authentifiziert werden kann. Nach Klärung hat der Nutzer ausdrücklich die Minaluneva-Adresse für diesen Versand freigegeben. **Support in der App bleibt Kundenservice@objektsignal.com.** Andere Postfach-, DNS-, MFA- oder Anbieterregeln nicht geändert; kein neues Abo.
- Den genauen Host hat die geöffnete Zoho-Kontoseite unter Ausgangsserver bestätigt, nicht nur ein MX-Lookup. [Zoho SMTP](https://www.zoho.com/mail/help/zoho-smtp.html), [App-Passwörter bei MFA](https://help.zoho.com/portal/en/kb/accounts/manage-your-zoho-account/articles/mfa-application-specific-passwords). Eine gespeicherte Konfiguration beweist **noch keine Zustellung**. [Supabase SMTP](https://supabase.com/docs/guides/auth/auth-smtp).
- Migrationen **017/018/019 produktiv angewendet und unabhängig nachgeprüft**, zuvor fehlenden Journalbeleg 016 nach exaktem Code-/Rechtevergleich ergänzt. Keine bestehenden Nutzerdatensätze umgeschrieben. Details und Hashes: [Backend-Nachweis](REFERENCE_BACKEND_2026_09_08.md). Absichtliche Fehler-/Rollbacktests ausschließlich in isolierter Datenbank.

## Datenschutz / Rechtstexte

Der Nutzerlink `https://objektsignal.com/datenschutz` beschreibt die Immobilienplattform, nicht FYRUP. Er wird nicht als FYRUP-Datenschutzerklärung ausgegeben. Die lokale Willkommensseite benennt ihn ausdrücklich als „Datenschutz der ObjektSignal-Website“; das ist ein vorläufiger, **nicht veröffentlichungsreifer** Zustand.

Auf ausdrücklichen Wunsch liegt ein [separater FYRUP-Entwurf](FYRUP_PRIVACY_DRAFT_2026_09_08.md) vor. Nicht veröffentlicht, bestehende Website nicht überschrieben. Verantwortlicher, Verarbeitungsgrundlagen insbesondere für Gesundheitsdaten, Dienstleisterverträge/Region, Fristen, Löschumfang, Zielalter und Kontaktangaben sind vor Freigabe zu bestätigen. Eigene veröffentlichte FYRUP-URL und Nutzungsbedingungen fehlen weiterhin.

## Prüfungen – strikt getrennt

| Ebene | Stand |
| --- | --- |
| Lokaler Gesamt-Preflight | 08.09.2026, 15:13 UTC: **21/21 PASS**, einschließlich des Deployment-/Testkorrekturblocks und R02; kein Swift-Compiler |
| Isolierte SQL-Tests | 019 mit Wiederholung, Erstellen/Lesen/Ändern/Löschen der Menge, Grenzen, Altdaten/Altclient, Versionskonflikt, fremdem Konto und anonymem Zugriff geprüft |
| Swift-Unit | #68: **510/511 PASS**, einschließlich aller 7 neuen Auth-Tests. Einrichtungs-Test aktivierte Wochen-Store nicht; lokale Korrektur noch nicht erneut nativ geprüft |
| Referenz-UI-Suite | #68: **5/7 PASS**; Ernährung/Supplements brachen im Tap-Helfer ab. Folgekorrektur vorbereitet, echte nachgelagerte Speicher-/Rückkehrschritte noch nicht nachgewiesen |
| E-Mail-Zustellung | **NICHT AUSGEFÜHRT**. SMTP gespeichert/aktiviert und frisch nachgeladen, aber noch kein echter Empfangs-/Linknachweis. Kein Versand an erfundene Testempfänger |
| Echter Link / Mail-App / Kaltstart / Passwortwechsel auf iPhone | **NICHT AUSGEFÜHRT** |
| Native aktuelle Screenshots | **17 PNGs aus #68 einzeln geprüft**; Gestaltung weiterhin TEILWEISE, konkrete Restabweichungen in QA-Bericht |
| TestFlight / physisches iPhone | **NICHT AUSGEFÜHRT** für diesen Stand |

Die gültige lokale Gesamtprüfung steht in `build/reference-preflight/report.json`. Sie enthält keinen Swift-Compiler. Ein grüner lokaler Lauf oder eine gespeicherte SMTP-Konfiguration ist kein Zustellungs- oder Produktnachweis.
