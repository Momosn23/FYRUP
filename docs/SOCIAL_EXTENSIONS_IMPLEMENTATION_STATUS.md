# Blind Workout / Call My Shot – Arbeits- und Prüfnachweis

Stand 05.09.2026. Code integriert, noch kein neuer TestFlight-Upload. Die Installation auf dem iPhone ist nicht mit diesem Quellstand gleichzusetzen.

## Blind Workout

- Einstieg in Freunde und im einzelnen Freundesprofil; eigene Erstellung mit Bibliothek/eigenen Übungen, Reihenfolge, Zielvorgaben, Equipment und freiwilligen Notizen.
- Tatsächlich reduzierte Serverantwort vor Start: Fokus, Dauer, Anzahl, Equipment und Muskelgruppen. Keine versteckte vollständige Übungsliste im Client.
- Explizite Equipment-Bestätigung, Annehmen/Ablehnen, später planen, erste Übung starten, bestätigtes schrittweises Aufdecken, Pause/Fortsetzen und neutraler Abbruch.
- Einfach/Tracken benutzen denselben bestätigten Fortschritt. Wechsel nach Einfach löscht keine bereits gespeicherten Satzwerte.
- Private Ist-Werte nur für den Empfänger; Ersteller sieht seinen Aufbau. Freunde außerhalb des Paars können höchstens die freigegebene DONE-Aktivität sehen.
- Abschluss, Feedback, unabhängige eigene Plankopie und Wiederöffnung über die Aktivität. Nur qualifizierter Abschluss erzeugt genau einen Wochen-Credit.
- Keine alten Detaildaten nach Kontowechsel, Blockierung oder verweigertem Lesen; autorisierte Summary-Änderung löst eine vollständige neue Detailprüfung aus.
- Kleine Reveal-Animation berücksichtigt „Bewegung reduzieren“. Begrenzte Vorgaben sind Produktgrenzen, keine medizinische Sicherheitsgarantie für individuelle Übungen.

## Call My Shot

- Freiwillige zweistufige Bestätigung auf der Wochenzielseite; keine automatische Aktivierung.
- Verwendet ausschließlich das bestätigte aktuelle Ziel. Vorgemerkte Änderungen wirken erst nächste Woche.
- Ein Call pro Woche, nicht nach verdienter Flamme. Die bestätigte Wochen-ID wird zusätzlich als Server-Vorbedingung geprüft, damit ein Wochenwechsel im Netzwerk keine andere Woche unbemerkt callt.
- Badge und Fortschritt in eigenem Heute/Profil, Freundeszeile und Freundesprofil; Reaktionen 🔥 🎯 💪 mit bestätigtem Zustand und Widerruf.
- Achievement aus derselben serverseitigen Wochentransaktion wie die Flamme. Eine gemeinsame Erfolgsanzeige statt zweier konkurrierender Prämien.
- Historie neutral; kein negativer Score, keine Beschämung, kein Zwang. Kein eigenes lokales Achievement- oder Fortschrittskonto.

## Tatsächliche Nachweise

- Lokaler PostgreSQL-Lauf: **678 Tests bestanden** (171 Blind,119 Shot,183 Weekly,82 Pläne,23 Pause,100 Schritte), einschließlich Wochen-ID-Vorbedingung. Weitere50 Onboardingprüfungen separat bestanden.
- Push-Dispatcher:29 lokale Tests bestanden; prüft Empfänger, noch gültige Freundschaft/Blockierung und Einstellungen vor jedem Geräteversand erneut. Kein tatsächlicher APNs-Versand im Test.
- Neue native Repository-/Store- und Zwei-Konten-Bedientests sind geschrieben. Ihre neue Cloud-Ausführung steht noch aus; nicht als bestanden markiert.
- Vorheriger Cloud-Build24 (`bb03c6f`), ohne Blind/Shot: 159 Unit-Tests ausgeführt,158 bestanden;20 UI-Tests ausgeführt,18 bestanden. Alle4 Workout-UI-Tests und der Weekly-Zielwechsel-/Neustart-Test bestanden. Fehler: fehlendes Profil im privaten Weekly-Testfixture, veralteter Feed-Buttontext im Test und falsches äußeres Switch-Tap-Ziel im Schritte-Test. Korrekturen vorbereitet, erneute Ausführung erforderlich.

## Veröffentlichung und offene Abnahme

Produktive Struktur am 05.09.2026 read-only geprüft: keine Workout-/Steps-/Weekly-/Blind-/Commitment-Tabellen, keine neuen Onboarding-/Pausenspalten. Änderungen in `supabase/migrations/202609050001`–`009` noch nicht ausgerollt. Keine Nutzerdaten bei dieser Prüfung geändert.

Noch offen: neuer vollständiger nativer Lauf, frische Einzelbilder visuell prüfen, produktive Migration und PostgREST-Zugriffe, reale getrennte Konten, APNs-Zustellung mit deaktivierten Einstellungen, physischer HealthKit-Test sowie signierter TestFlight-Upload. Eine Datenbank-Testsimulation ist keine echte iPhone- oder Push-Abnahme.

Zentrale offene Abnahme: [PRODUCT_CHECKLIST.md](PRODUCT_CHECKLIST.md).
