# FYRUP Light-Storyboard-Abnahme

Referenz: `docs/reference/FYRUP-light-storyboard.png`

Neuester Einzelbild-Nachweis: [Build 31](VISUAL_QA_BUILD31.md). Jede Referenzseite ist dort einer tatsächlich betrachteten Aufnahme oder einem ausdrücklich offenen Nachweis zugeordnet. Abweichungen sind dokumentiert; keine vollständige Gleichheit und keine neue iPhone-Auslieferung behauptet.

Diese Tabelle erfasst die 24 bestehenden Referenzseiten. Die [zentrale Produkt-Checkliste](PRODUCT_CHECKLIST.md) ergänzt verbindlich neue Seiten, Funktionsprüfung, Animationen und Abnahmetests. „Umgesetzt“ ist hier kein Beleg für Funktionsfähigkeit oder visuellen Gleichstand im aktuellen TestFlight-Build. Neue Erweiterungen sind noch nicht abgenommen.

Status: ✅ umgesetzt · 🧪 im Cloud-Build visuell zu prüfen · ⚙️ iOS-Systemansicht

| Nr. | Referenzseite | Umsetzung |
| ---: | --- | --- |
| 1 | Splash Screen | 🧪 Helles Runner-Hero, Wortmarke und Claim |
| 2 | Onboarding 1 | 🧪 „Gemeinsam mehr erreichen“ mit Crew-Motiv |
| 3 | Onboarding 2 | 🧪 Foto-Collage und „Eine stärkere Crew“ |
| 4 | Login-Auswahl | 🧪 Heller Hero, Apple-, E-Mail- und Registrierungsaktion |
| 5 | Apple Login | ⚙️ Native `SignInWithAppleButton`-Bestätigung von iOS |
| 6 | E-Mail-Registrierung | 🧪 Helles Formular mit sichtbaren Passwortregeln |
| 7 | Profil erstellen | 🧪 Foto, Name, Username, Jahr und Stadt |
| 8 | Sportarten auswählen | 🧪 Helles 3-Spalten-Raster mit grüner Auswahl |
| 9 | Gym-Unterkategorien | 🧪 Mehrfachauswahl mit Schwerpunktbeschreibung |
| 10 | Freunde finden | 🧪 Username-Suche und Freundschaftsanfrage |
| 11 | Heute / Feed | 🧪 Begrüßung, eigener Status, Crew-Aktivitäten und FYR UP |
| 12 | Plus-Menü | 🧪 Starten/Planen-Auswahl und beliebte Sportarten |
| 13 | Training planen | 🧪 Sport, Termin, Dauer, Ort, Notiz und Einladungen |
| 14 | Einladung | 🧪 Eigene Detailansicht mit Dabei/Vielleicht/Kann nicht |
| 15 | Geplantes Training | 🧪 Terminübersicht und Teilnehmerstatus |
| 16 | Live-Training | 🧪 LIVE-Badge, Timer, Kennzahlen, Pause und Stop |
| 17 | Training beenden | 🧪 Trophy, Ergebnis, Teilen und Fertig |
| 18 | Freunde-Liste | 🧪 Freunde/Anfragen-Segmente, Suche und Wochenstatus |
| 19 | Freundesprofil | 🧪 Profil, Wochenfortschritt, Sportarten und Aktivität |
| 20 | Crew-Ziel | 🧪 Gesamtfortschritt und Beiträge der Crew |
| 21 | Eigenes Profil | 🧪 Profilkopf, Statistiken, Sportarten und Einstellungen |
| 22 | Mitteilungen | 🧪 Alle/Einladungen/Reaktionen und Ereignisliste |
| 23 | Einstellungen | 🧪 Profilkopf und strukturierte Einstellungsgruppen |
| 24 | Hell/Dunkel | 🧪 Light Design ist verbindlicher Standard; heller Referenzvergleich offen, Dark Mode bleibt optional |

## Abnahmeregel

Jeder neue UI-Cloud-Build erzeugt Screenshots. Akzeptiert wird eine Seite erst, wenn Informationshierarchie, Weißraum, Kartengrößen, grüne Akzente, Kontrast und Navigation sichtbar zur Referenz passen und der dazugehörige UI-Test bestanden ist.

Zusätzlich jede sichtbare Aktion manuell bedienen, kleine/große Schrift und Leer-/Fehlerzustände prüfen. Bei iOS-eigenen Apple-/Foto-/Health-Dialogen die native Systemansicht korrekt verwenden; die Illustration ist kein Auftrag für einen nachgebauten Systemdialog. Pro Seite Build/Commit, Screenshot, Ergebnis und Restabweichungen dokumentieren. Standbilder allein belegen weder funktionierende Pause noch Animationen oder gespeicherte Eingaben.
