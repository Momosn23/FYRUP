# Bestätigte Aktivitätssichtbarkeit

Befund am 05.09.2026: `PrivacyView` verwendete `try?` beim Speichern des ganzen Profils und zeigte anschließend auch bei einem Fehler den gewählten neuen Wert. Eine verspätete Antwort konnte außerdem das lokal inzwischen gewechselte Profil überschreiben.

## Korrektur im aktuellen Arbeitsstand

- Eigenständiger `ActivityPrivacyStore`: unbekannter Stand ist keine Auswahl „Freunde“. Vorhandene Werte sind während eines Aufrufs gesperrt; erst eine passende Serverantwort bestätigt die neue Auswahl.
- Bei Fehler oder verlorener Antwort kein automatischer Neuversuch und keine Erfolgsanzeige. Sichtbare Meldung und bewusstes erneutes Laden.
- Konto und Antwortgeneration werden geprüft, auch bei erneuter Anmeldung desselben Nutzers. Alte Erfolge/Fehler können weder einen neuen Kontostand noch dessen Ladezustand ersetzen.
- Die Serveränderung aktualisiert ausschließlich `activity_visibility`, gefiltert auf Nutzer-ID und zuvor bestätigten Wert. PostgreSQL prüft diesen Vergleich in derselben Änderung; die bestehende RLS erlaubt nur das eigene Profil. Kein neues Administrationsrecht, keine neue Migration und keine Übermittlung zusätzlicher Profilfelder.
- Die App übernimmt anschließend nur das bestätigte Sichtbarkeitsfeld in ihr vorhandenes Profil. Name, Foto und sonstige parallele lokale Bearbeitungen werden nicht durch einen alten vollständigen Schnappschuss ersetzt.
- Der Bediennachtest wechselt in der Demo auf „Niemand“, wartet auf Bestätigung, öffnet die Seite erneut und prüft den gespeicherten Wert. Er stellt die Demo-Auswahl danach auf „Freunde“ zurück.

## Nachweise und Grenzen

15 neue lokale PostgreSQL-Prüfungen bestanden, zusammen mit allen bisherigen 960 Prüfungen: Besitzergrenze, fehlende Anmeldung, Fremdschreiben, enger Änderungsumfang, konkurrierender gespeicherter Wert, tatsächlicher Entzug des Aktivitätszugriffs für einen Freund und keine soziale Nachricht durch Einstellungsänderungen. Testdaten existieren nur in der wegwerfbaren lokalen Datenbank.

13 native Einzeltests vorbereitet: unbekannt/abgemeldet, Lesefehler, falsche Konten/Werte, bestätigte Änderung, verlorene Antwort, Konkurrenz, Doppeltipp, verspätete Antworten, gleiche Person mit neuer Sitzung, Demo-Repository und AppStore-Abmeldung. **Noch nicht nativ ausgeführt.** Die bestehenden grünen Builds enthalten diese Korrektur noch nicht.

Die Spaltenfreigabe und Besitzer-RLS stammen aus bestehenden Migrationen 001/005. Lokale Datenbanktests sind kein Netzwerk-/Produktiv- oder Zweigeräte-Test. Andere ältere Vollprofil-Speicherpfade sind nicht durch diese Änderung automatisch auf einen Versionsvergleich umgestellt.
