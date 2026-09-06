# Moderne Bildsprache und interaktive Muskelgruppen

Zusatzauftrag vom 05.09.2026 anhand des Nutzerfotos. Die neue Referenz zeigt die gewünschte Funktion; sie ersetzt nicht die bereits gewählte helle FYRUP-Gestaltung durch einen dunklen Gesamtstil.

## Arbeitsstand – Körperauswahl

Build29 (`073b933`) besteht mit 365 Einzeltests und 26 UI-Abläufen. Die tatsächlichen Simulatorbilder der Körperauswahl wurden geprüft; ein TestFlight-/iPhone-Nachweis steht noch aus. Details: [VISUAL_QA_BUILD29.md](VISUAL_QA_BUILD29.md).

- Eigene skalierbare Vorder-/Rückansicht mit getrennten Muskelbereichen, grüner Auswahl und kurzem Übergang. Keine Bildkopie und keine externen Bildabrufe.
- Gemeinsame Auswahl für Figur, beschriftete Schaltflächen und vier Bereichsvorgaben; gezielte Mehrfachauswahl und Zurücksetzen. Große Schrift erhält eine einspaltige Listenalternative; reduzierte Bewegung schaltet den Übergang aus.
- Im Gym-Dialog an den gespeicherten Trainingsfokus gebunden; die bisher zehn Körpergruppen sind um Adduktoren, Trapez und Unterarme ergänzt. Nach freier Änderung wird ein unpassender Push-/Pull-Titel zu „Individuell“ korrigiert.
- Die Übungsbibliothek bietet alle 13 anatomischen Muskeln sowie die klar getrennten Kategorien Ganzkörper/Sonstiges. Haupt- und zusätzliche Muskeln fließen in den tatsächlichen Filter ein; mehrere gewählte Muskeln gelten als Alternativen.
- Fünf neue Logik-/Grafikzuordnungstests und ein durchgehender Bildschirmtest bestehen. Der bisherige Gym-Bedientest besteht ebenfalls. Echte Simulatorbilder sind geprüft; kleine Displays, große Schrift, VoiceOver und iPhone bleiben gesondert offen.

Die folgenden Kästchen bleiben bis zur jeweiligen vollständigen Abnahme offen. Die übrigen Seiten und Bildwünsche sind nicht durch diesen Teilblock erledigt.

## Interaktive Körperfigur

- [x] BODY-01 Bei der Muskelgruppenauswahl eine hochwertige Körperfigur mit Vorder- und Rückansicht anzeigen; beide Ansichten ohne umständliche Navigation erreichbar.
- [x] BODY-02 Muskelbereich direkt antippen oder über die beschriftete Auswahlliste wählen; Figur und Liste bleiben in beide Richtungen synchron.
- [x] BODY-03 Gewählte Muskelbereiche passend zur FYRUP-Farbwelt hervorheben, mit kurzem Aufleuchten/dezentem Übergang. Erneutes Antippen entfernt die Auswahl.
- [x] BODY-04 Mehrfachauswahl ermöglichen; Auswahlzustand auch mit Text/Markierung vermitteln, nicht ausschließlich durch Farbe.
- [x] BODY-05 Körpermitte, Oberkörper, Unterkörper und Ganzkörper als verständliche Gruppenauswahl abbilden; Zuordnung zu den vorhandenen einzelnen Muskelgruppen konsistent halten.
- [x] BODY-06 Alle vorhandenen Muskelgruppen korrekt abdecken, einschließlich kleinerer Bereiche wie Unterarme und Waden; primäre/sekundäre Muskeln bei Übungsdarstellung verständlich unterscheiden.
- [x] BODY-07 Auswahl mit passenden Übungen und Plan-/Gym-Filtern verbinden. Keine rein dekorative Figur, deren Antippen die tatsächliche Auswahl unverändert lässt.
- [x] BODY-08 Eigene skalierbare Grafik mit getrennten antippbaren Bereichen verwenden; keine unscharfe Kopie des beigefügten Werbescreenshots. Anatomische Zuordnung prüfen.
- [x] BODY-09 Ausreichende Trefferflächen und beschriftete Listenalternative für kleine Bereiche, VoiceOver, große Schrift und reduzierte Bewegung vorsehen.

## Einheitliche moderne Bildsprache

- [ ] VISUAL-01 Jede Seite anhand der Referenzliste prüfen und gezielt hochwertige Sportbilder, Illustrationen oder passende Vorschaubilder einsetzen – nicht wahllos jede Fläche füllen.
- [ ] VISUAL-02 Bildsprache auf Login, Heute, Sport-/Muskelwahl, Planbibliothek, Übungsdetails, Trainingsablauf und Abschluss konsistent halten; vorhandene Nutzereingaben und Aktionen erhalten.
- [ ] VISUAL-03 Einheitliche helle Flächen, Typografie, Abstände, Rundungen und FYRUP-Akzentfarben; keine willkürlichen Stilmischungen oder unlesbaren Texte über Bildern.
- [ ] VISUAL-04 Auswahl, Kartenwechsel, Fortschritt und erfolgreiche Abschlüsse dezent animieren; keine endlos blinkenden Figuren, ablenkende Effekte oder blockierte Schaltflächen.
- [ ] VISUAL-05 Nutzungsrechte/Quellen für Bildmaterial sichern; platzsparende Assets, schnelle Ladezeiten und sinnvolle Offline-/Fehlerdarstellung.
- [ ] VISUAL-06 Figuren und Bilder in verschiedenen Displaygrößen prüfen; keine abgeschnittenen Muskeln, Nahtlinien, überlagerte Texte oder unsichtbaren Bedienelemente.
- [ ] VISUAL-07 Visuelle Abnahme jeder betroffenen Seite mit echten App-Screenshots; Muskel-Taps, Mehrfachauswahl, Abwählen, Listen-Synchronisation und Navigation zusätzlich funktional testen.

Referenz: vom Nutzer beigefügtes Foto vom 05.09.2026, Körperfigur mit hervorgehobenen Rumpfmuskeln. Abnahme getrennt als Code, Funktion, visuelle Prüfung und iPhone-Nachweis führen.
