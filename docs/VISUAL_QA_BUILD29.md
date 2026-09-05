# Native und visuelle Prüfung – Build29

Codemagic: `6a9bdab8fac9a246bed9296b`, Commit `073b9337138211105c98ce54eea3a7e7603ff97c`, 05.09.2026. Simulator iPhone 17 Pro. **365 Einzeltests und 26 UI-Abläufe bestanden**, einschließlich fünf Muskelzuordnungstests und des durchgehenden Figur-/Listen-/Übungsfilters. Kein signierter TestFlight-Build.

Die ZIP-Artefakte wurden nach `.qa/build29` geladen und die folgenden Original-PNGs tatsächlich visuell angesehen:

| Aufnahme | Ergebnis |
| --- | --- |
| `62-interactive-body-front-back.png` | Große, getrennte Vorder-/Rückfigur. Brust und Körpermitte grün, Auswahlanzahl eindeutig; sichtbare Abschluss-Schaltfläche. Listenalternative weiter unten erreichbar. |
| `64-muscle-filter-matching-exercise.png` | Körpermitte filtert tatsächlich auf die passende Pallof-Press-Übung. Kleiner Textfehler „1 passende Übungen“ erkannt und im nachfolgenden Arbeitsstand korrigiert. |
| `04-gym-body-areas.png` | Mehrfachauswahl Brust/Schultern/Trizeps/Körpermitte, beschriftete Auswahl und erreichbare Startaktion. |
| `01-home-feed.png` | Wochentage gleich hoch; „Deine Streak“ korrekt. Demo-Abschlüsse vor Einrichtung des Wochenziels werden absichtlich nicht rückwirkend gutgeschrieben. |

Keine vollständige Abnahme aller Seiten: große Schrift, kleine Displays, VoiceOver, Bewegungseffekte und echte Gerätebedienung sind aus diesen Standbildern nicht bewiesen. Die neue Sprachüberarbeitung und Supplement-Fundamente sind erst nach diesem Build entstanden und benötigen ihren eigenen Build-/Bildschirmnachweis.
