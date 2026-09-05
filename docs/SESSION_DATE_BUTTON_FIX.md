# Datumsknopf: native Bedienbarkeit

Am 05.09.2026 meldete [GitHub 46](https://github.com/Momosn23/FYRUP/actions/runs/33966306003/job/101306940982#step:5:3863) für `717472c` einen Fehler in `testPlanWorkoutFlow`, Zeile 106. Nach dem Wechsel auf „SESSION PLANEN“ findet die Button-Abfrage `session-date` kein antippbares Element. Der Kalender wurde noch nicht geöffnet. Die 396 Einzeltests, der erweiterte Privatsphäre-Bedientest und der Supplement-Bedientest bestanden unabhängig davon.

Die neue vollständige Datumsanzeige ersetzt das abgeschnittene System-Pill aus Build 35. Ihr nativer `Button` war anschließend mit `.accessibilityElement(children: .ignore)` erneut umschlossen. Diese zusätzliche Elementbildung ist ein plausibler Grund für die fehlende Button-Rolle; das bisherige Protokoll allein zeigt keinen vollständigen Accessibility-Baum und beweist die Ursache noch nicht.

Lokale Korrektur: natives Button-Element und Aktion erhalten, Label „Datum“, vollständigen Datum-Wert und stabile ID weiterhin setzen, Button-Trait explizit ergänzen. Die gesamte Zeile erhält eine rechteckige Trefffläche. Keine Verkleinerung/Abkürzung des Datums und kein Ersetzen des nativen Kalenders durch eine Attrappe.

Der Bediennachtest verlangt weiterhin genau einen über seine Button-ID auffindbaren und antippbaren Knopf, ein Datum einschließlich vierstelligem Jahr, Öffnen des nativen Kalenders, Übernehmen und erfolgreiche Session-Planung. Bei fehlendem Button wird zusätzlich der tatsächliche Demo-Accessibility-Baum angehängt. Begrenztes Warten auf die laufende Ansichtsumschaltung ersetzt keine Zusicherung.

Stand: lokale Text-/Diff-Prüfung bestanden; nativer Nachtest und neue Bildschirmbilder der Korrektur noch offen. Nicht als behoben/ausgeliefert abhaken.
