# FYRUP – freigegebene Editorial-UI

Freigabe durch den Nutzer am 11.09.2026. Diese Bildserie ersetzt die frühere kartenlastige Gestaltung als visuelle Zielrichtung. Die fachlichen Regeln, Datenschutzvorgaben und die verbindliche Terminologie bleiben vorrangig. Texte und Beispielwerte in generierten Bildern sind keine Produktdaten und werden nicht ungeprüft übernommen.

## Verbindliche Gestaltungsregeln

- FYRUP-Flamme und Wortmarke links oben auf allen Haupt- und Markenansichten.
- Heller, warmer Hintergrund; klare fast schwarze Typografie; Grün nur für Auswahl, Fortschritt, LIVE und Erfolg.
- Schwarze Hauptaktionen mit weißem Text. Sekundäraktionen bleiben flach und erhalten höchstens eine feine Kontur.
- Echte Sport-, Crew-, Übungs- und Essensbilder führen durch inhaltliche Bereiche. Bilder sind kein Schmuck ohne Funktion.
- Weniger einzelne Karten: verwandte Daten werden mit Linien, Weißraum und typografischer Hierarchie gruppiert.
- Keine Mint-Schleier, Neon-Glows, riesigen schwebenden Flächen, 3D-Knöpfe oder dauerhaften Animationen.
- Animationen bleiben kurz, zustandsbezogen und respektieren „Bewegung reduzieren“.
- Navigation und Eingaben bleiben native iOS-Komponenten mit mindestens 44 pt großen Bedienflächen.

## Freigegebene Boards

| Datei | Abgedeckte Ansichten |
| --- | --- |
| `00-direction.png` | Grundrichtung für Heute, Aktivitätswahl und laufendes Workout |
| `01-onboarding-account.png` | Willkommen, Konto, Profil, Körper und Ziel |
| `02-onboarding-preferences.png` | Sportarten, Woche, Supplements/Ernährung, Health/Privatsphäre |
| `03-home-planning.png` | Heute, Wochenplan, Session planen, Aktivität wählen |
| `04-gym-overview.png` | Workout-Plan, laufendes Workout, Satz, Abschluss |
| `05-onboarding-finish.png` | Privatsphäre, Freunde finden, erste Session, Zusammenfassung |
| `06-crew-invitations.png` | Crew, Suche/Kontakte, Einladung, Gruppe |
| `07-discover-library.png` | Entdecken, Übungsbibliothek, Muskeln, Workout-Plan-Editor |
| `08-workout-live-flow.png` | Laufendes Workout, Satz erfassen, Satzpause, nächste Übung |
| `09-live-surfaces-finish.png` | Live Activity, Dynamic Island, Bewertung, Abschluss |
| `10-nutrition-supplements.png` | Ernährung, Mahlzeit, Supplements, Erinnerung |
| `11-profile-progress.png` | Profil, Ziele, Statistiken, Körperdaten |
| `12-settings-support.png` | Mitteilungen, Erinnerungen, Einstellungen, Hilfe/Über FYRUP |
| `13-blind-call-my-shot.png` | Blind Workout und Call My Shot |

Die Dateien liegen unter `docs/reference/2026-09/editorial-approved/`.

## Korrekturen gegenüber Beispielbildern

- „Training“ wird nicht als generischer neuer UI-Begriff übernommen. Es gelten `docs/TERMINOLOGY.md` und `AGENTS.md`.
- Kalorien auf Heute sind aufgenommene Nahrungsenergie. Aktive Energie bleibt getrennt.
- Bilder enthalten teilweise illustrative Namen, Daten und Messwerte; die App zeigt ausschließlich echte oder ausdrücklich als Demo gekennzeichnete Daten.
- Die Live Activity zeigt keine privaten Gewichte oder Wiederholungen auf dem Sperrbildschirm. „Satz & Gewicht“ öffnet die geschützte App-Eingabe.
- Google-Anmeldung bleibt gestrichen. Apple und E-Mail sind die einzigen Anmeldewege im aktuellen Umfang.
- Verschobene Ernährungssuche, Barcode- und Synchronisierungsfunktionen werden nicht durch funktionslose Bildaktionen vorgetäuscht.

## Umsetzung und Abnahme

Die Bildserie ist eine freigegebene Soll-Vorlage, kein Nachweis einer fertigen App. Pro Bereich werden Quellcode, lokale Prüfungen, nativer Build, Simulatorbild und echte iPhone-/TestFlight-Abnahme getrennt dokumentiert. Kostenpflichtige Builds werden gebündelt und erst nach vollständigem lokalen Prüfblock gestartet.

## Quellstand der Editorial-Umsetzung

Die zusammenhängende Quelländerung überträgt die Richtung auf Willkommen/Konto, Profil- und Sporteinrichtung, Heute, Wochenplan, Aktivitätswahl, Workout-Pläne und Übungsbibliothek, laufendes Workout mit Satzdialog und Satzpause, Abschluss, Crew, Entdecken, Ernährung, Supplements, Profil, Mitteilungen, Einstellungen, Hilfe, Blind Workout und Call My Shot. Der laufende Workout-Ablauf zeigt jeweils die aktuelle Übung, den vorherigen Bestwert, Satzwerte und Anstrengung; nach dem ersten Abschluss eines Satzes startet die große Satzpause. Erledigte Übungen bleiben aufklappbar und die nächste Übung wird separat angekündigt.

Der Muskelwähler bleibt eine native, bedienbare Vektorgrafik. Gewählte Bereiche leuchten grün; nicht gewählte Bereiche und der Hintergrund bleiben neutral. Es wird kein Bild als nicht bedienbare Ersatzoberfläche verwendet.

Die neuen redaktionellen Sport-, Übungs-, Crew-, Essens- und Abschlussmotive sind unter [EDITORIAL_ASSET_MANIFEST_2026_09_11.md](EDITORIAL_ASSET_MANIFEST_2026_09_11.md) dokumentiert. Native Kompilierung, Simulatorbilder und TestFlight-Abnahme werden erst nach dem gebündelten lokalen Abschlusslauf eingetragen; sie sind an dieser Stelle noch nicht als bestanden ausgewiesen.

Lokaler Abschlussstand vor dem gebündelten nativen Lauf: Terminologieprüfung für 137 App-Textdateien bestanden, Katalogabgleich für 122 Übungen und 127 Muskelzuordnungen bestanden, alle neuen Asset-Katalogdateien lesbar und alle Swift-Dateien ohne unausgeglichene Klammern. Die vollständige vorhandene Backend-Suite einschließlich Workout, Blind Workout, Call My Shot, Wochenlogik, Supplements, Onboarding und Versandterminologie endete ohne Fehler. Diese Prüfungen ersetzen ausdrücklich weder die Xcode-Kompilierung noch den visuellen Simulator- oder iPhone-Abgleich.

Der aktuelle native Prüfstand mit getrennt ausgewiesenen Erfolgen, Restpunkt und nicht ausgeführten Gerätetests steht in [EDITORIAL_NATIVE_QA_2026_09_11.md](EDITORIAL_NATIVE_QA_2026_09_11.md).
