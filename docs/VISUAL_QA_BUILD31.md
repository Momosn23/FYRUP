# Bildschirmprüfung – Build 31

Geprüft am 05.09.2026. Tatsächliche Simulator-Aufnahmen, keine neuen Mockups. Quelle: [Codemagic Build 31](https://codemagic.io/app/6a9aff9f64377f6028cc8d18/build/6a9befa83cf4759eab7d62a6), Commit `7910f6c`: **382 Einzeltests und 27 UI-Abläufe bestanden**, insgesamt 28 min 41 s. Lokal wurden 71 PNGs nach `.qa/build31/` entpackt. Die Tabelle nennt ausschließlich einzeln betrachtete Aufnahmen bzw. ausdrücklich offene Nachweise.

Referenz: [helles 24-Seiten-Storyboard](reference/FYRUP-light-storyboard.png). Neuere Nutzeraufträge ergänzen Wochenleiste, Streak, Supplements, Workout-Pläne und Muskelgrafik. Neue Terminologie hat Vorrang vor alten Bildbeschriftungen. Der Build ist **nicht pixelgleich zur Referenz** und **kein neuer TestFlight-Stand**.

## Grundseiten

| Referenz | Betrachtete Aufnahme | Ergebnis / Restabweichung |
| --- | --- | --- |
| 1 Splash | Keine separate Aufnahme | Startanimation und separates Splash-Motiv nicht abgenommen. |
| 2 Einführung | `02-onboarding-intro.png` | Helle Fläche, Überschrift und Crew-Fotos; Collage statt einzelnem Gruppenfoto. |
| 3 Crew-Einführung | `03-onboarding-crew.png` | Collage und neue Überschrift vollständig; das gleiche Motiv wird auf Seite 2 verwendet. |
| 4 Login | `00-welcome.png` | Gemeldete horizontale Bildkante nicht mehr sichtbar. Wortmarke, Foto und Leerraum weichen von der Vorlage ab. |
| 5 Apple-Bestätigung | Kein Systemdialog | Echte Apple-Anmeldung am Gerät offen; kein nachgebauter Dialog. |
| 6 E-Mail-Registrierung | `06-email-registration.png` | Formular, Passwortregeln und Anmeldewege sichtbar. Kein Nachweis einer echten Registrierung. |
| 7 Profil erstellen | `onboarding-01-profile.png` | Kameraaktion, Name, Username, Jahr/Stadt und Weiter lesbar. Tatsächliche Bildauswahl/-übertragung offen. |
| 8 Sportarten | `onboarding-02-sports.png` | Drei Spalten und grüne Mehrfachauswahl ohne abgeschnittene Namen. Icons nicht identisch zur Vorlage. |
| 9 Gym-Fokus | `onboarding-03-gym.png` | Push/Pull und weitere Schwerpunkte mit Beschreibung; längere Liste scrollbar, Footer sichtbar. |
| 10 Freunde finden | `onboarding-04-friends.png` | Suchergebnis, Hinzufügen und Später/Fertig vollständig. Demo verwendet Initialen statt Porträts. |
| 11 Heute | `01-home-feed.png` | Wochenleiste, Status, „Deine Streak“ und Supplements vorhanden. Neue Karten schieben Crew unter den ersten Bildschirm. |
| 12 Plus-Einstieg | `12-plus-menu.png` | „Was hast du vor?“, JETZT LOS/Planen und Sportarten lesbar. Vollbild statt kleinem Overlay. |
| 13 Session planen | `05-plan-workout.png` | Foto-Hero, Modus, Dauer und Standort vorhanden. **Datum abgeschnitten**; DatePicker-Zeilen in `6e79a31` umgebaut, Bildnachtest offen. |
| 14 Einladung | `14-invitation.png` | Neue Session-Sprache und drei Antworten ohne Überlappung. Demo mit Initialen. |
| 15 Geplante Session | `06-hosted-session.png` | Termin, Ort, Notiz und Teilnehmer sichtbar. Bearbeitungsansicht statt kompakter Lesekarte; untere Aktionen im Ausgangsbild teilweise hinter Tab-Leiste, scrollende Prüfung offen. |
| 16 LIVE | `07-live-training.png` | LIVE, Timer, Pause und Abschluss sichtbar. Keine erfundenen Puls-/Kalorienwerte; weniger Kennzahlen als im Mockup. |
| 17 Abschluss | `08-workout-complete.png` | Konfetti, Ergebnis, Rückblick und Feed-Aktion sichtbar. **Fertig hinter Tab-Leiste**; zusätzlicher Scrollfreiraum und geometrischer UI-Test in `6e79a31`, Nachtest offen. |
| 18 Freunde | `18-friends.png` | Suche, Segmente, Crews und Status sichtbar. Neue Funktionen verändern Reihenfolge; Initialen statt Porträts. |
| 19 Freundesprofil | `19-friend-profile.png` | Profil, Sportarten, Woche und Blind-Workout-Aktion vollständig; größere Kopfzone als im Mockup. |
| 20 Crew-Ziel | `20-crew-goal.png` | Balken, Beiträge und Restziel lesbar. Nullwerte sind Demo-Zustand, kein echter gemeinsamer Fortschrittsnachweis. |
| 21 Eigenes Profil | `09-profile.png` | Einheiten/Monat, Streak, Wochenplan und Statistik sichtbar; Anordnung durch neue Karten verändert. |
| 22 Mitteilungen | `10-notifications.png` | Session-/Aktivität-Texte vollständig; Kategoriesymbole statt Personenfotos. |
| 23 Einstellungen | `23-settings.png` | Profilkopf, geordnete Zeilen und Logout lesbar. Unterseiten dadurch nicht abgenommen. |
| 24 Hell/Dunkel | Keine eigene Aufnahme | Heller Standard vorhanden; optionaler Auswahldialog/dunkle Darstellung nicht abgenommen. |

## Weitere einzeln betrachtete Aufnahmen

- `03-activity-details.png`: Gym-Hero, Unterkategorie, Datum und „MITZIEHEN 🔥“ lesbar.
- `37-weekly-goal.png`: 3–7 Einheiten, Erklärung und Aktion ohne Kürzung.
- `62-interactive-body-front-back.png`: Vorder-/Rückseite, grüne Brust-/Core-Auswahl, Zählung und Bibliotheksaktion sichtbar. Eigene vereinfachte Figur. Standbild beweist keine Animation; Filter-/Auswahltests bestehen separat.
- `65-supplement-editor.png`: Eigener Name, Tage, Uhrzeit, standardmäßig ausgeschaltete Erinnerungen und Speichern sichtbar. Rote Unterstreichung stammt von der System-Rechtschreibprüfung.
- `66-supplement-confirmed.png` / `67-supplement-skipped.png`: Unterschiedliche bestätigte Zustände, Zeitpunkt und Rückgängig klar. **Einleitung nach zwei Zeilen gekürzt**; vertikal ungekürzte Darstellung in `6e79a31` ergänzt, Bildnachtest offen.

### Ergänzende Einzelprüfung am selben Tag

- `04-activity-categories.png`: Drei Spalten, alle zehn Sportarten und Moduswahl lesbar. `04-gym-body-areas.png`: vier markierte Muskelgruppen, Schnellgruppen und Startaktion sichtbar; Figur im gescrollten Bild nur teilweise sichtbar, vollständige Figur separat in Aufnahme 62 geprüft.
- `06-email-login.png`: E-Mail, Passwort, Apple-Alternative und Passwort-vergessen-Aktion vollständig. `onboarding-05-complete.png`: Abschluss, Fortschrittsanzeige und FYRUP STARTEN ohne Überlappung.
- `friends-training-groups.png`: Zwei Crew-Karten, Mitgliederzahlen und Freundesstatus lesbar; horizontale Crew-Liste. Personen bleiben Demo-Initialen.
- `25-workout-plan-editor.png`, `26-exercise-library.png`, `27-custom-exercise.png`, `28-workout-plan-detail.png`: Plan, Bibliothek, eigene Übung und Detailkarte einzeln angesehen. Formulartexte, Foto-Hero und zentrale Aktionen lesbar; lange Listen erfordern Scrollen. Eigene Planbezeichnungen bleiben unverändert.
- `29-workout-easy-live.png`, `30-workout-set-tracking.png`, `31-workout-plan-done.png`: Ablauf, 80 kg / 8 Wiederholungen und Ergebnis sichtbar. Aufnahme 30 zeigt Pause/Abschluss/Abbruch nach Scrollen vollständig oberhalb der Tab-Leiste; Aufnahme 31 ebenso Teilen/Fertig. Erste Bildschirmposition allein enthält nicht alle Aktionen.
- `32-unsaved-workout-draft.png`, `33-restored-workout-draft.png`: gleicher Entwurf vor/nach Neustart; Wiederherstellungshinweis und Speichern sichtbar. Das Standbild ergänzt den bestandenen Persistenztest, ersetzt ihn nicht.
- `34-health-explanation.png`, `35-own-daily-steps.png`, `36-step-privacy.png`: Opt-in-Erklärung, Demo-Schritte und getrennte Freigaben lesbar. Eigene Anzeige an, Freundesfreigabe aus. Kein Nachweis echter Health-Daten.
- `38-weekly-flames.png`, `39-weekly-goal-next-week.png`, `40-weekly-goal-restored.png`: „Deine Streak“, aktuelles Viererziel und vorgemerktes Fünferziel nach Neustart sichtbar. **Speichern auf Aufnahme 39 teilweise hinter der Tab-Leiste**; der bestehende Test klickt erfolgreich, eine vollständig freie Schaltfläche ist damit noch nicht bewiesen. Geometrische Scroll-Abnahme ergänzen.
- `41-blind-workout-create.png`, `42-blind-invitation-private.png`: Ersteller sieht Vorgaben, Empfänger nur Anzahl/Equipment/Fokus. Annahme und Ablehnung lesbar; keine vorzeitigen Übungsnamen im Empfängerbild.
- `43-blind-first-reveal.png`, `44-blind-second-reveal.png`: erste/zweite Übung und Fortschritt wechseln sichtbar; Easy/Mittel/Hardcore vollständig. Pause liegt in der ersten Bildschirmposition am unteren Rand. Die Ansicht besitzt zusätzlichen Scrollraum; Endlagen und Fertig separat geometrisch prüfen.
- `45-blind-workout-done.png`, `46-blind-private-plan-copy.png`, `47-blind-completed-restored.png`: Ergebnis, private Plan-Kopie und wiederhergestellter Abschluss sichtbar. Kopieren/Abschluss wurden im zugehörigen UI-Ablauf tatsächlich ausgeführt. Vollständig sichtbarer Fertig-Footer fehlt als eigenes Bild.
- `48-shot-explicit-confirmation.png`, `49-shot-called.png`, `50-shot-current-four-next-five.png`: ausdrückliche Freigabe, angekündigtes Viererziel und getrennte Änderung für nächste Woche lesbar. Keine Beschämungs-/Straftexte.
- `51-friend-shot-confirmed-reaction.png`, `52-friend-shot-reaction-removed.png`: Reaktion wechselt sichtbar von grün markiert / 1 auf unmarkiert / 0.
- `53-workout-share-preview.png`: konkrete Zusammenfassung und ausgeschlossene private Inhalte vollständig; Versand wird erst im nächsten nativen Dialog gewählt. Keine tatsächliche externe Nachricht versendet.
- `54-unsaved-set-with-keyboard.png`, `55-restored-set-draft.png`: Tastatur-schließen-Aktion und wiederhergestellte Werte 81 / 9 sichtbar. **Nach Eingabe fehlen dauerhafte Feldbeschriftungen mit kg/Wiederholungen**. Im anschließenden lokalen Arbeitsstand feste Labels „Gewicht (kg)“ und „Wiederholungen“ bzw. „Zeit (Sekunden)“ ergänzt; UI-Entwurfstest prüft Beschriftungen vor/nach Neustart. Sprachprüfung besteht, nativer Bildnachtest offen. Nicht in `6e79a31` / TestFlight 8 enthalten.
- `56-discover-selected-sport.png`: Laufen korrekt vorausgewählt, Fokus horizontal scrollbar, JETZT LOS unten frei.
- `57-onboarding-training-routine.png`, `59-weekly-routine-editor.png`, `60-weekly-routine-restored.png`: freiwilliger Einstieg und Wochenplan mit Gym zweimal/Montag/Freitag; Auswahl nach Neustart erhalten. Speicheraktion frei, untere Erklärung in Ausgangsposition unterhalb der Tab-Leiste; Scroll-Abnahme der gesamten Erklärung offen.
- `58-private-workout-review.png`, `61-private-exercise-effort.png`: drei Bewertungen, freiwillige private Notiz sowie farbige Hardcore-Auswahl sichtbar. In Aufnahme 61 sind Pause/Abschluss/Abbruch nach Scrollen vollständig frei.
- `63-muscle-filter-excludes-unrelated.png`, `64-muscle-filter-matching-exercise.png`: Core-Filter ergibt für Bankdrücken null Treffer, für Pallof Press einen passenden Treffer. Leerzustand und Rücksetzen lesbar.

Damit sind alle **70 einzelnen App-Aufnahmen** dieses Archivs betrachtet; die zusätzliche Datei `fyrup-contact-sheet.png` ist nur eine Montage. Das ist weder jede mögliche App-Seite noch eine Abnahme aller Zustände, Animationen oder realer Konten. Die oben genannten sichtbaren Mängel bleiben ausdrücklich offen bzw. im Folge-Build nachzuprüfen.

## Offene Abnahme

Keine Aussage „alle Seiten identisch“. Weitere Unterseiten, Leer-/Fehlerzustände, größere Schrift, kleine iPhones, VoiceOver, Fotoauswahl, HealthKit und Pushzustellung bleiben separat zu prüfen. Build 31 zeigt die alte Fotoauswahl vor den GitHub-Korrekturen. Der Folge-Build muss diese sowie die drei Layout-Nachbesserungen bestätigen.
