# Referenz-Prüfpunkt – 08.09.2026

## Geltender Auftrag und Arbeitsstand

Der neue Auftrag `839a13d5-5cbe-483f-9c2c-66198bc0df65` hat Vorrang. Die 18 Registrierungs- und 8 Appseiten sind unter `docs/reference/2026-09/` zugeordnet. Dies sind ausgeschnittene Vorlagen, keine App-Screenshots. Vollständige [Funktionsmatrix](REFERENCE_IMPLEMENTATION_MATRIX.md) und [Designregeln](DESIGN_2026_09_SPEC.md).

Erster Codeblock: Design-Tokens/Komponenten, Heute, Wochenplan-Tab, optionale Körperdaten, manuelles privates Ernährungstagebuch, ausgelagerte LIVE-/Satzpauseneinstellungen, Mindestwochenziel 2 sowie WeatherKit. Nach Runner-, Navigations- und Großschriftkorrekturen ist `e39caf6` auf main. Der gebündelte native Lauf #67 hat **495 Unit-Tests und 3/3 ausgewählte UI-Tests bestanden**. Sieben echte Simulatorbilder wurden geprüft; [Restabweichungen und Nachweise](REFERENCE_QA_67.md). Kein neuer TestFlight-/Store-Upload. Die gesamte App ist **nicht abgeschlossen**. Die vollständige Registrierung ist weiterhin offen; bestehende gespeicherte Schritte wurden nicht pauschal umnummeriert.

Bei Arbeitsbeginn vorhandene Änderungen an `docs/MODERN_SETUP_LIVE_CHECKLIST.md` und der Ordner `AppStoreAssets/` wurden erhalten. Nicht ungeprüft einem neuen Commit hinzufügen.

**Danach lokal weitergearbeitet:** [Folgeblock Einrichtung/Übersichten](REFERENCE_LOCAL_SETUP_2026_09_08.md). Gemeinsamer benannter 14-Schritt-Unterablauf nach Profil/Sport, Auswahlseiten, editierbare Zusammenfassung, kompaktere Heute-/Mahlzeitenkarten und Migration 018. Diese Arbeitskopie ist **NICHT nativ kompiliert/getestet**; die unten stehenden #67-Nachweise beziehen sich weiterhin nur auf `e39caf6`. 21 lokale Prüfgruppen bestanden. Keine zusätzlichen Cloud-Läufe und keine Kosten in diesem Folgeblock; 017/018 noch nicht produktiv angewendet.

## Nachweise sauber getrennt

| Ebene | Stand |
| --- | --- |
| Quellcode | `e39caf6` erfolgreich kompiliert und im ausgewählten nativen Prüfpunkt getestet |
| Lokal | Alle 21 Preflight-Gruppen PASS, einschließlich 2 synthetischer Tests des Vergleichswerkzeugs, YAML/Entitlements und 4 Simulatorauswahlfällen. Bericht `build/reference-preflight/report.json`; lokales Ergebnis ist kein Swift-/Gerätenachweis |
| Datenbank | Migration 017 lokal gegen bestehende Migrationen geprüft: Bestandsdaten bleiben, 2 ist zulässig, 1/8/null unzulässig, Folgewoche, Idempotenz und fremder/anon Zugriff |
| Produktives Supabase | Migration 017 NICHT angewendet; Ernährung noch rein lokal, keine Behauptung vollständiger Mehrgeräte-Synchronisierung |
| Apple-Konfiguration | WeatherKit-Capability und App Service bei bestehender `app.fyrup.ios` aktiviert; Profil `FYRUP App Store 2026` erneuert, Zertifikat und Live-Extension unverändert |
| Codemagic-Signierung | Profil direkt über bestehende Apple-Integration als `fyrup_app_store_weatherkit` gespeichert; neuer YAML-Verweis gesetzt. Profilbytes/IPA-Entitlements werden erst im signierten Lauf geprüft |
| Native Unit-/UI-Tests | #67: 495 Unit-Tests PASS, 3/3 Referenz-UI-Tests PASS; keine vollständige UI-Regression. Frühere Fehler und Korrekturen in REFERENCE_QA_65/66/67.md getrennt dokumentiert |
| Neue echte Screenshots | Sieben PNGs aus #67 geprüft: A01 oben/gescrollt, R05 normal/Tastatur/Großschrift oben/gescrollt, A19. Safe Areas und Erreichbarkeit korrigiert, visuelle Referenzabnahme bleibt TEILWEISE |
| WeatherKit live | NICHT GETESTET; keine echte Wetterantwort bisher abgerufen |
| Physisches iPhone/TestFlight | NICHT AUSGEFÜHRT für diese Änderungen |

## Kosten und Laufgrenzen

Live im Codemagic-Konto geprüft: Pay as you go, M2 0,095 USD/Minute zuzüglich 19 % MwSt. Freies macOS-Kontingent verbraucht (Anzeige 501 Minuten). Bereits aufgelaufen laut Konto: 821 bezahlte Minuten, 78 USD netto, 92,82 USD einschließlich MwSt., nächste Abrechnung 01.10.2026. Das ist kein nachgewiesenes Prepaid-Guthaben; es wurde kein kontoseitiger Ausgabenstopp angezeigt.

Der Nutzer hat am 08.09.2026 mit „ok“ **maximal 10 USD zusätzlich inklusive MwSt.** für die nächsten gebündelten Prüfungen freigegeben. Keine Abos, Tarife oder Wetter-Zusatzkontingente gebucht. Vier Läufe beendet (konservativ insgesamt **2,61 USD**, Rest **7,39 USD**); geplante und tatsächliche Kosten werden in [CI_BUDGET_2026_09.md](CI_BUDGET_2026_09.md) fortgeschrieben. **Kein Lauf aktiv.** Kostensparendes Arbeiten erneut bekräftigt: keine weiteren Builds für einzelne Layoutkorrekturen, zuerst den nächsten substanziellen Arbeitsblock lokal bündeln. Vor jedem weiteren Lauf Restbudget prüfen; keine Freigabe für eine unbegrenzte Schleife.

- `ios-cloud-validation`: manueller erster Prüfpunkt, 30 Minuten hartes Joblimit, Scriptlimit 24 Minuten, ungefähr höchstens 3,40 USD inklusive MwSt. bei angezeigtem Tarif. Keine automatische Wiederholung, kein Archiv/Upload.
- `ios-full-regression`: getrennt manuell, 60 Minuten Joblimit, nur nach Prüfung des Restbudgets. Nicht parallel zum ersten Prüfpunkt starten.
- `ios-testflight`: bestehender signierter Weg, erst nach bestandener QA. Kosten gesondert ins Restbudget rechnen.
- Änderungen der Trigger sind mit `451ad09` auf GitHub. Der manuelle Lauf zeigt den neuen Workflow „FYRUP iOS QA (manual milestone)“ und bestätigt den Checkout von `451ad09`. Commit mit `[skip ci]`, kein GitHub-Push-Workflow und keine Codemagic-Push-Events.

Letzter historisch erfolgreicher QA-Lauf: #63, Revision `30a2f9c`, 39m44s. Xcode 26.6 (17F113) im tatsächlichen Vorbereitungslog geprüft. Letztes historisches signiertes Archiv: #15, `ee44420`, 6m37s. Beide sind **kein** Nachweis für diesen Umbau.

## Reproduzierbare nächste Schritte

1. Lokaler Preflight: `node scripts/reference-preflight.mjs`; `FYRUP_PYTHON` muss unter Windows auf den vorhandenen Python-Runtimepfad zeigen. Lokale Hilfspakete: Pillow im Runtimebestand, PyYAML 6.0.2 unter `.qa/reference-tools` (nicht versionieren). Unter eingeschränktem Windows-Prozess waren PyYAML-Dateien nicht lesbar; die erlaubte Ausführung außerhalb dieser Einschränkung war erfolgreich.
2. Erster nativer Prüfpunkt abgeschlossen (#67). Kein unveränderter erneuter Lauf und kein automatisches Archiv. Nächste Änderungen zunächst lokal bündeln, bevor ein neuer bezahlter Prüfpunkt sinnvoll ist.
3. Simulator: iPhone 16 (ersatzweise gleich großes iPhone 15), 393 × 852 pt. Xcode bleibt 26.6; die iOS-Laufzeit wird separat aus den tatsächlich installierten verfügbaren Versionen ausgewählt und mit vollständigem Simulatorinventar dokumentiert. Xcode-Version nicht mit iOS-Version gleichsetzen. Deutsch, feste Referenzzeit 22.05.2025 09:41 Berlin. `--reference-checkpoint` nutzt echte Views mit isolierten Demo-Daten; dieser Einstieg ist im physischen Release-Build nicht verfügbar. `--reference-body` öffnet den echten Körperdatenschritt. Kein Fake-Wetter: ohne ausgewählten Wetterort steht dort Ort wählen.
4. Artefakte: `build/reference-qa/run.json`, Log, XCResult, `/tmp/fyrup-screenshots/*.png` und gleichnamige JSON-Metadaten. A01 oben/gescrollt, R05 normal/Tastatur/große Schrift; A19 lediglich zusätzlicher Zwischenstand.
5. Lokal vergleichen: `python scripts/compare-reference-screens.py REFERENZ.png ECHT.png ECHT.json NEUER_AUSGABEORDNER`. Erzeugt Gegenüberstellung, Overlay, Differenz und Bericht; weigert sich vorhandene Ergebnisse zu überschreiben. Die Collage wird proportional auf dieselbe Breite skaliert, nicht auf eine abweichende Höhe verzerrt. Keine Prozentgleichheit behaupten. Synthetische Werkzeugtests sind keine App-Abnahme.
6. Sichtbare Restunterschiede aus REFERENCE_QA_67.md lokal beheben; die nun bedienbaren gemeinsamen Komponenten nicht als vollständige Referenzabnahme behandeln. Bestehende vollständige UI-Regressionspfade (Home-Aktionen, entfernte Planen-Karte, aktive Energie nun im Profil, Satzpause nur im Workout) müssen weiter angepasst werden, bevor der Vollregressionslauf sinnvoll ist.
7. Vollständiges Onboarding mit Apple/E-Mail, echter Mailversand, Export und getrennte Freigaben bleiben auf der Matrix. Gemäß späterer [Umfangsänderung](RELEASE_SCOPE_2026_09_08.md) ist Google gestrichen; Lebensmittelanbieter/-suche, Barcode, Rezepte und Ernährungssynchronisierung sind ausdrücklich auf eine spätere Version verschoben, nicht als umgesetzt abgehakt.

Kein Apple-Video und keine erneute Einreichung vor Korrektur und Abnahme. Keine permanente Hintergrundarbeit oder automatische Coding-Schleife eingerichtet.
