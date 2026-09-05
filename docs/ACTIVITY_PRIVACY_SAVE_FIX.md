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

13 native Einzeltests für unbekannt/abgemeldet, Lesefehler, falsche Konten/Werte, bestätigte Änderung, verlorene Antwort, Konkurrenz, Doppeltipp, verspätete Antworten, gleiche Person mit neuer Sitzung, Demo-Repository und AppStore-Abmeldung **in GitHub 46 bestanden**: `ActivityPrivacyStoreTests` am 05.09.2026 um 14:35:21 CEST, 0 Fehler, 10,416 s. Anschließend endete die vollständige Unit-Suite um 14:36:29 CEST mit **396 Tests und 0 Fehlern**. Auch `testProfilePrivacyAndLogoutFlow` mit bestätigter Änderung und Wiederöffnen bestand um 14:46 CEST nach 54,856 s. Der Gesamtlauf ist wegen eines separaten Datumsknopf-Tests nicht fehlerfrei. Die zuvor vollständig grünen Builds enthalten diese Korrektur nicht.

Die Spaltenfreigabe und Besitzer-RLS stammen aus bestehenden Migrationen 001/005. Lokale Datenbanktests sind kein Netzwerk-/Produktiv- oder Zweigeräte-Test. Andere ältere Vollprofil-Speicherpfade sind nicht durch diese Änderung automatisch auf einen Versionsvergleich umgestellt.

## Produktive Strukturprüfung

Am 05.09.2026 um 14:34:43 CEST wurde im tatsächlichen FYRUP-Projekt `dwpuzcpnzldlnadfivcm` ausschließlich eine Metadaten-SELECT-Abfrage ausgeführt. Ergebnis: `row_security=true`, Spaltenänderung für `authenticated=true`, für `anon=false`; einzige UPDATE-Richtlinie `profiles_update` mit `USING (id = auth.uid())` und `WITH CHECK (id = auth.uid())`, Rolle `authenticated`. Damit sind die vorausgesetzten Rechte im produktiven Bestand vorhanden. Keine Profiländerung, kein Testkonto und keine Nachricht wurden dort erzeugt. [Abfrage](https://supabase.com/dashboard/project/dwpuzcpnzldlnadfivcm/sql/aa156b7a-2f90-4f85-9efd-1408f9be61f8).

Implementierung und neue Tests sind als `717472c` auf `main` hochgeladen. [GitHub 46](https://github.com/Momosn23/FYRUP/actions/runs/33966306003/job/101306940982) läuft nach erfolgreicher Unit-Suite und erfolgreichem Privatsphäre-Bedientest weiter; [Simulator 36](https://codemagic.io/app/6a9aff9f64377f6028cc8d18/build/6a9c0bbdfac9a246bed9917e) wartet hinter dem älteren signierten Build 9. Neue Screenshots und echte iPhone-Prüfung dieses Commits sind noch offen.

Zusätzlicher noch offener Befund: `upsert_profile` aus Migration 005 und ältere vollständige Profil-Speicherpfade nehmen `activity_visibility` weiterhin entgegen. Ein veralteter Namens-/Foto-Entwurf kann daher die separate Auswahl zurücksetzen. Ein enger eigener Profil-Details-Speicherpfad samt bestätigter Antwort und Kontoschutz ist vor vollständiger Datenschutz-Abnahme nachzurüsten; nicht durch bloßes erneutes Lesen vor dem Schreiben als atomar ausgeben. Bisher nur im Quellcode festgestellt, keine Änderung echter Profile zur Reproduktion.
