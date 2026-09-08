# Native QA #68 – Ergebnis und Korrekturblock

08.09.2026, [Codemagic #68](https://codemagic.io/app/6a9aff9f64377f6028cc8d18/build/6aa017afec706db602ed05ee), Revision `4679d897164865cd0cc65ee3aa2052686d07d352`. Xcode 26.6 (17F113), iPhone-16-Simulator mit iOS 26.5, 393 × 852 Punkte. **FAIL**, kein Store-/TestFlight-Upload. Gesamtdauer 12m39s, keine automatischen Wiederholungen.

## Belege

Das vom Nutzer bereitgestellte `FYRUP_68_artifacts.zip` wurde lokal nach `build/native-qa/68-4679d89/` entpackt. SHA-256 des Originalarchivs: `371d5af448471846d6ccc81f1327393a42c9a7ef2dae2751d4f61f570d30ba2e`. Das Original bleibt unverändert unter Downloads.

- `build/reference-qa/xcodebuild.log`: **510/511 Unit-Tests PASS**, **5/7 ausgewählte Referenz-UI-Tests PASS**. Die übrigen UI-Suiten waren in diesem begrenzten Meilenstein nicht ausgewählt.
- Alle **7 EmailAuthFlowTests PASS**: PKCE, strikter Callback, Ablauf/Wiederaufnahme, Recovery-Isolation, Passwortwechsel über Mock-Transport, fehlender ausstehender Vorgang, definitive/ungewisse Ablehnung und erneuter Versand.
- 17 unveränderte PNGs mit Accessibility-Hierarchie und Metadaten. Echte SwiftUI-Simulatoransichten mit isolierten Fixtures, keine Bildgenerierung und keine produktiven Nutzerkonten.
- **Physisches iPhone, TestFlight, echte E-Mail-Zustellung und echte Apple-Anmeldung: NICHT AUSGEFÜHRT.**

## Drei Fehler und Folgekorrekturen

1. `SetupJourneyTests.testOptionalSetupCanFinishWithoutSportsOrAutomaticGoalAndReopenOnToday`: verglich den noch nicht aktivierten Wochen-Store (`nil`) mit `false`. `MainTabView.task` aktiviert ihn beim echten Eintritt. Der Test führt jetzt denselben Leseaufruf explizit aus und verlangt anschließend einen bestätigten Datenstand, `goalConfirmed == false` und keine aktive bestätigte Woche. Keine automatische Zielbestätigung hinzugefügt; keine Prüfung durch `nil`-Fallback abgeschwächt.
2. Ernährungs-Bedientest: Log zeigt erfolgreiche Eingabe von 250 g, danach zehn erfolglose Scrollversuche vor dem Tastaturknopf „Fertig“. Der Helfer begrenzte dessen Position durch die darunterliegende Hauptnavigation. Tastaturaktionen werden jetzt gegen den Bildschirm, nicht gegen verdeckte Navigation geprüft.
3. Supplement-Bedientest: `R11-own-supplement-amount.png` zeigt einen sichtbaren grünen Speichern-Knopf. Die Hierarchie zeigt `save-supplement` bei y=750…802; der verdeckte Einrichtungsfooter liegt bei y=706. Der Helfer wies deshalb den sichtbaren Modal-Knopf zurück. Präsentierte Fenster verwenden nun ihre eigene Bildschirmgrenze, weiterhin mit Hittability-/Sichtbarkeitsprüfung. Scrollversuche wählen einen erreichbaren vertikalen Container. Weitere Fehler liefern zusätzlich aufrufende Testzeile, Bild, Hierarchie und Elementrahmen.

Diese Testkorrekturen sind **noch nicht erneut nativ ausgeführt**. #68 bleibt FAIL; das erwartete Ergebnis wird nicht als bestanden verbucht. Echte Speicher-/Rückkehrschritte hinter den beiden abgebrochenen UI-Tests sind weiterhin offen.

Der Screenshot-Export prüft zusätzlich bis zu sechs aufeinanderfolgende Bildstände mit je 0,1 Sekunden Abstand und vermerkt `frameSettled`; er schaltet keine Produktanimationen ab. Die Supplement-Rasteraufnahme wartet ausdrücklich auf das geschlossene Editorfenster. Lokaler Gesamt-Preflight nach dem vollständigen Korrekturblock: **21/21 PASS am 08.09.2026, 15:13 UTC**; keine native Swift-Ausführung auf Windows.

Zusätzliche bestätigte R02-Korrektur in der Arbeitskopie: native weiße Apple-Schaltfläche mit einem einzigen zur Außenform passenden Rand statt beschnittener doppelter Outline; E-Mail-Auswahl im hellen Outline-Stil der Vorlage. Echte Apple-Anmeldung und finale Bildkontrolle bleiben offen.

## Visuelle Einzelkontrolle aller 17 PNGs

| Bilder | Ergebnis |
| --- | --- |
| A01-top / A01-scroll | Richtige Reihenfolge: Kopf, Schritte/Nahrungsaufnahme, Wochenleiste/Streak, Supplements, Crew. Werte 8.421/10.000 und 1.850/2.500 mit korrektem Rest. Aber zu große vertikale Dichte: Crew-Aktionen erst nach Scrollen; Magnesium ungünstig getrennt. Ohne echte Avatar-/Wetterdaten werden bewusst Ersatzdarstellungen verwendet. **Referenzabnahme offen.** |
| A19-manual-diary-checkpoint | Vier Mahlzeiten im Datenmodell, korrekte Aufnahme/Makros. Nur erste zwei Zeilen im initialen sichtbaren Bereich; kompaktere Referenzanordnung und echte Lebensmittelbilder fehlen. Kein Nachweis der abgebrochenen Mengenänderung. |
| R01 / R02 / R03 | Echte neue Seiten sichtbar. R01 zeigt noch das alte Motiv statt der Bergvorlage. R02 Apple-Outline wird unsauber von zusätzlicher Rundung beschnitten; E-Mail-Knopf ist schwarz statt der hellen Vorlage. R03 stärker gefüllte Felder und zusätzliche Anbieteraktionen weichen ab. FYRUP-Rechtstexte bleiben Veröffentlichungsvoraussetzung. |
| R05-body / R05-keyboard | Werte ohne unerwünschtes „.0“; Weiter/Überspringen und Tastaturabschluss erreichbar. Nach Tastaturabschluss Rückkehr mit 182 cm bestanden. |
| R05-large-type-top / R05-large-type-scroll | Große Bedienung und Datenfelder scrollbar, Zielgewicht oberhalb der festen Aktion erreicht. Lange Erklärung benötigt Scrollen; keine vollständige Großschriftprüfung anderer Seiten. |
| R06 / R07 | Auswahlkarten und gespeicherte Auswahl vorhanden. R06-PNG zeigt noch eine Übergangsfarbe, obwohl die unmittelbar folgende Hierarchie bereits „Selected“ und Häkchen meldet; kein Beweis eines verlorenen Wertes, aber erneute stabile Bildaufnahme nötig. R07 zeigt beide grünen Mehrfachauswahlen. Kartenabstände und fehlende Untertexte weichen von der Vorlage ab. |
| R08 / R09 / R10 | 2–7, Wochentage und Uhrzeit sichtbar/bedienbar. Die 4 in R08 stammt aus der ausdrücklich bestätigten Bestands-Fixture, nicht aus einer automatischen Neuregistrierung. Runde Referenz-Auswahl und kompaktere Abstände fehlen; R09/R10 speichern Mo/Sa bzw. Unterschiedlich. |
| R11-own-supplement-amount | Eigene 1,5 g sichtbar, keine Dosierung vorgegeben, Speichern sichtbar. Der anschließende Speicherschritt brach im Testhelfer ab; neue Rasteraufnahme und Wiederöffnung noch nicht belegt. |
| R18-setup-summary | Gespeicherte Ziele/Tage und Bearbeitungsrücksprung belegt. Zu viele große Einzelkarten gegenüber der kompakten Vorlage; weitere Punkte unterhalb des sichtbaren Ausschnitts. |

## Nächster gebündelter Meilenstein

- Testkorrekturen zusammen mit echten Layoutverbesserungen lokal vorprüfen; keine einzelne kosmetische Änderung sofort kostenpflichtig bauen.
- Heute/Ernährung/Summary kompakter, R02-Knöpfe und Referenz-Auswahlkarten korrigieren; Bedienflächen mindestens 44 Punkte und Dynamic Type erhalten.
- Fehlende Bilder/Anbieter/Rechtstexte nicht durch erfundene Ergebnisse verdecken.
- Danach einen bewusst begrenzten nativen Meilenstein erwägen, nicht automatisch wiederholen. Verfügbares Budget siehe [Laufbuch](CI_BUDGET_2026_09.md).

Produktiv angewendete Schemaänderungen sind separat in [Backend-Nachweis](REFERENCE_BACKEND_2026_09_08.md) dokumentiert. Ein korrektes Schema ist kein Nachweis der Mailzustellung oder Gerätefunktion.
