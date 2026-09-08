# Lokaler Folgeblock: Einrichtung und kompaktere Übersichten

Stand 08.09.2026, Arbeitskopie nach `e39caf6`. **Diese Änderungen sind noch nicht nativ kompiliert oder auf dem iPhone geprüft.** Der grüne Lauf #67 belegt ausschließlich den vorherigen Stand. Kein neuer Codemagic-Lauf, kein Upload und keine zusätzlichen CI-Kosten in diesem Arbeitsblock.

**Fortgeschriebener Stand:** Der nachfolgende [Auth-/Supplement-Block](REFERENCE_AUTH_SUPPLEMENTS_2026_09_08.md) ergänzt inzwischen R01–R03, Recovery, Auswahlraster, Mengen und Migration 019. Die entsprechenden nachstehenden „noch offen“-Angaben dokumentieren den früheren Zwischenstand und sind dort aktualisiert. Native Abnahme und Veröffentlichungsvoraussetzungen bleiben offen.

## Im Quellcode umgesetzt

- E-Mail-Formular: Passwort sichtbar/unsichtbar ohne Wertverlust, beim Verlassen aus dem Formularzustand entfernt; Login verwechselt bestehende Zugangsdaten nicht mit den Registrierungs-Mindestregeln. „E-Mail & Passwort“ und eindeutige Aktion „Konto erstellen“. Backend-Regelabgleich/Verifikation/Recovery weiterhin offen.
- Profil: benannte Felder, optionales Foto/Geburtsjahr, kein öffentliches Stadtfeld in der ersten Einrichtung, feste Weiter-Aktion. Eigener Navigationscontainer für Tastatur und Zurück; Geburtsjahrgrenzen entsprechen dem vorhandenen Datenbankfeld, keiner neu erfundenen Altersrichtlinie.
- Sportwahl: drei Spalten, bei Bedienungshilfen zwei; lesbare Bezeichnungen statt stark verkleinerter Schrift. Auswahl später separat bearbeitbar. Leere Sportvorlieben schicken fertige Konten nicht zurück ins Onboarding.
- Ein gemeinsamer persönlicher Ablauf mit 14 **stabil benannten** Schritten nach Profil/Sport: Körperdaten, Hauptziel, Zusatzwünsche, Wochenziel, Tage, Uhrzeit, Supplements, Ernährung, Health, Rechte, Privatsphäre, Freunde, erste Aktion, Zusammenfassung.
- Hauptziel/Mehrfachwünsche/Tage/Uhrzeit speichern in der bestehenden kontogetrennten privaten Ablage. Kein vorausgewähltes Ziel, keine Termine aus Vorlieben und keine Zustimmung durch bloßes Öffnen. Alte numerische Schritte 0–3 behalten ihre ursprüngliche Bedeutung. Bestehende fertige Konten bleiben fertig.
- Körperdaten zeigen beispielsweise `180` und `81,5`, ohne `.0` oder Verlust bereits gespeicherter Nachkommastellen. Weiter validiert und speichert; Überspringen überschreibt keine Daten.
- Health und Freunde-Freigabe sind getrennte Seiten. Ein noch nicht geladenes Schrittziel kann nicht durch ein leeres Formular gelöscht werden. Öffnen fordert keine Systemfreigabe an.
- Rechte verlinken echte Unterseiten: manuelle Wetterstadt, Mitteilungen, LIVE/Satzpausen. Kein Schalter „Alle erlauben“ und keine behauptete Genehmigung durch das Schließen eines Systemdialogs.
- Freunde: vorhandene Benutzernamensuche, gezielte Kontaktauswahl und eigener Profil-Link. Späte Suchantworten werden nach neuer Suche, Verlassen oder Kontowechsel verworfen.
- Drei erste Aktionen: direkt beginnen, später planen, erst ansehen. Nach erfolgreichem Abschluss öffnen die ersten beiden nur den echten Aktivitätsdialog; noch keine Aktivität/Session wird angelegt.
- Zusammenfassung zeigt gespeicherte Werte und bestätigt geladene Zustände; Zeilen öffnen die jeweilige Korrekturseite und kehren zurück. Ausstehende Wochenzieländerungen werden als nächste Woche kenntlich gemacht.
- Heute: geringere Abstände, kleinere Ringe, kompaktere Crew-Köpfe, mindestens 44-Punkt-Aktionen und mehr Textbreite für Supplement-Namen. Daten und Reihenfolge bleiben echt; keine Musterwerte hinzugemischt.
- Ernährung: vier kompakte Mahlzeitenzeilen mit tatsächlich erfasster Summe; Tippen öffnet Einträge zum Bearbeiten, Löschen und Hinzufügen. Keine beliebigen Essensbilder als angebliche Fotos der Mahlzeiten.

## Backend-Voraussetzung – noch nicht produktiv

`202609080018_optional_setup.sql` setzt ausschließlich den Standard **neuer** Profile auf `nobody` und trennt den Einrichtungsabschluss von einer erzwungenen Sport-/Wochenzielauswahl. Bestehende Sichtbarkeit, Ziele, Bestätigungen und Aktivitäten werden nicht umgeschrieben. Die gezielten Ziel-/Freigabe-RPCs bleiben unverändert zuständig. `upsert_profile` bewahrt weiterhin die geschützten Einstellungen bestehender Profile.

Migrationen **017 und 018 vor einer Veröffentlichung kontrolliert anwenden**. Bis dahin ist ein optionaler Abschluss ohne Wochenziel im produktiven alten Backend nicht zugesichert. Keine produktiven SQL-Ausführungen in diesem Arbeitsblock.

## Prüfstatus

| Ebene | Ergebnis |
| --- | --- |
| Lokaler Gesamt-Preflight | 21/21 Gruppen PASS. Isolierte Datenbanktests, Katalog, Terminologie, Konfigurations-/Signierungsprüfprogramme und Vergleichswerkzeug. Kein Swift-Compiler enthalten |
| Migration 018 lokal | PASS: zweimalige Anwendung, bestehende Daten unverändert, neues Profil privat/unbestätigt, Abschluss ohne Sport/Ziel möglich, Wiederholung, Auth/RLS, ungültige Schritte/Fokuswerte, keine erfundenen Abschlüsse |
| Acht neue Swift-Einzeltests | Vorbereitet, **NICHT AUSGEFÜHRT**: alte gespeicherte Daten, stabile Reihenfolge, Kontotrennung, Wiederaufnahme, fehlende implizite Freigaben, Versionsprüfung, Zahlenformat und optionaler Abschluss |
| Bestehende Swift-/UI-Regression | Pfade für Profil/Sport/Einrichtung, aktive Energie im Profil, Planen im Wochenplan und Satzpause/Intervalle im LIVE-Bereich angepasst; **NICHT AUSGEFÜHRT** |
| Erweiterte Referenz-UI-Suite | Jetzt fünf Tests vorbereitet: zusätzlich Auswahl-/Zusammenfassungsfluss und Mengenänderung mit identischer Kalorienaktualisierung auf Ernährung/Heute. **NICHT AUSGEFÜHRT** |
| Aktuelle native Screenshots | **NICHT ERZEUGT**. Sieben vorhandene Bilder gehören ausschließlich zu #67 / `e39caf6` |
| Produktives Backend / echtes iPhone / TestFlight | **NICHT AUSGEFÜHRT** für diesen Folgeblock |

Ein erster eingeschränkter Windows-Preflight konnte das bereits installierte YAML-Paket wegen Dateirechten nicht lesen (20/21). Der erlaubte erneute **lokale** Gesamtprüflauf mit Zugriff auf die vorhandenen Bibliotheken bestand 21/21. Kein Cloud-Build als Ersatz gestartet.

## Nicht als erledigt behandeln

- R01–R03: Willkommen, Anmeldeart, bestätigte Backend-Passwortregeln, Verifikation und vollständiger Recovery-Ablauf bleiben zu überarbeiten. R03-Sichtbarkeit/Beschriftung sind lokal ergänzt, aber kein vollständiger Auth-Nachweis. Google ist bislang nicht produktiv konfiguriert; deshalb kein täuschender Loginbutton.
- R11: Der neue Schritt öffnet die echte eigene Liste, aber Referenz-Auswahlraster sowie eigene Mengen/Einheiten fehlen weiterhin teilweise.
- R15: Aktivitäts- und Schritte-Freigabe vorhanden; Ernährungs-/Stadtfreigabe nicht implementiert und daher keine funktionslosen Schalter.
- R18: Die Anzeige der 14 persönlichen Schritte ist keine Behauptung einer bereits vollständigen 18-Seiten-Referenzumsetzung. Foto/Sport sind bestehende vorgelagerte bzw. nachträglich editierbare Bereiche.
- Ernährung bleibt ein privates, manuelles lokales Tagebuch. Lebensmittelanbieter, Barcode, Rezepte, Cloud-Synchronisierung und Export bleiben offen.
- Neue Layoutmaße sind erst Codeänderungen. Großschrift, Tastatur, echte Bildschirmproportionen und Kontowechsel müssen nativ erneut geprüft werden.

## Nächste gebündelte Arbeit

1. R01–R03 und Supplement-Details vervollständigen; vorhandene Auth-/Daten-/Freigaberegeln beibehalten.
2. Verbleibende ältere UI-Regressionspfade mit der tatsächlichen neuen Navigation abgleichen. Keine Tests bloß wegen geänderter Oberfläche entfernen.
3. Ein sinnvoller nativer Prüfpunkt erst nach weiterem gebündeltem Fortschritt und Abgleich des Restbudgets; keine Einzelkorrektur-Schleife.
4. Tatsächliche neue PNGs mit denselben Referenzen vergleichen, Matrix aktualisieren und verbleibende Backend-/Gerätetests getrennt ausweisen. Kein Apple-Upload vor Abnahme.
