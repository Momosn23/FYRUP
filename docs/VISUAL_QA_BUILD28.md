# Visuelle Prüfung Build28

Commit `f10d61a`, Simulator iPhone17 Pro. 360 native Unit-Tests und25 Bedienabläufe bestanden. Archiv mit65 PNGs inklusive Kontaktbogen lokal unter `.qa/build28`; nicht ins Repository aufgenommen.

Tatsächlich einzeln betrachtet:

- `57-onboarding-training-routine.png`: freiwilliger Rhythmus-Schritt mit Sportauswahl, Speichern und sichtbarem „Später festlegen“. Kein Pflichtziel und kein blockierter Einstieg.
- `59-weekly-routine-editor.png`: Gym2×, Montag/Freitag grün gewählt, weitere Sportart und Speichern erreichbar. Der erklärende Schlusssatz läuft beim gezeigten Scrollstand hinter die Tab-Leiste; die vorhandene80-Punkte-Reserve ermöglicht weiteres Scrollen. Nicht als vollständig sichtbarer Abschlussbildschirm ausgeben.
- `58-private-workout-review.png`: drei Gefühle, optionales Kommentarfeld, Speicher- und Schließen-Aktionen; private Verwendung erklärt.
- `61-private-exercise-effort.png`: Satz1 tatsächlich80kg/8Wdh., unbestätigte Sätze mit Strichen statt erfundenen Werten. Easy/Mittel/Hardcore und freiwillige Abwahl lesbar; ausgewähltes Hardcore deutlich markiert.
- `01-home-feed.png`: neue Wochenleiste ganz oben; tatsächliche Demo-Historie unterscheidet sich vom erst ab Demo-Zielbestätigung zählenden Streak-Zähler. Doppelte Überschrift „Deine Woche“ erkannt: zweite Karte im Folgestand zu „Deine Streak“ geändert. Unterschiedliche Symbolhöhen der Tagesfelder im Folgestand vereinheitlicht.
- `31-workout-plan-done.png`: Rückblick erreichbar, Teilen/Fertig gemeinsam sichtbar oberhalb der erhöhten Plus-Schaltfläche. Übungsliste weiterhin scrollbar.

Nicht aus statischen Bildern ableitbar: tatsächlicher Konfetti-Verlauf, Reduce Motion, VoiceOver, kleinste Displaygrößen oder echtes HealthKit. Kein vollständiger Designabgleich sämtlicher Seiten und kein TestFlight-Nachweis.
