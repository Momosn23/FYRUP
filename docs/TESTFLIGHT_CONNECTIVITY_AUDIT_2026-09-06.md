# TestFlight-Verbindungsprüfung – 06.09.2026

## Nachprüfung am 09.09.2026

[QA #71](REFERENCE_QA_71.md) bestätigt die Netzwerk-Regressionsklassen erneut: `AppStoreConnectivityTests` 5/5, `SupabaseRESTClientTests` 7/7 und `WorkoutStoreTests` 35/35 PASS; insgesamt 544/544 Unit- und 12/12 Referenz-UI-Tests erfolgreich. Die vorherige unabhängige Suchregression ist behoben. Einmaliges signiertes Paket aus `6d97776` (unveränderter App-Code `b538d05`) als [TestFlight 1.0.0 (16)](TESTFLIGHT_16_2026_09_09.md) hochgeladen, von Apple verarbeitet und FYRUP Intern zugeordnet. Auch die tatsächlich eingebettete Produktionskonfiguration und Signierung der fertigen IPA sind geprüft. Sämtliche echten iPhone-Fälle unten bleiben **NICHT AUSGEFÜHRT**. Keine neue vollständige Release-Testsuite in diesem Paketlauf.

## Folgekorrekturen vom 08.09.2026 – inzwischen in internem Build 16 enthalten

Erneuter ausdrücklicher Nutzerhinweis: keine wiederkehrenden „Kein Netzwerk“-/„Kein Internet“-Anzeigen in TestFlight. Der aktuelle Quellstand enthielt noch einen direkten Darstellungsweg außerhalb des bereits stillen Heute-Feeds: `WorkoutStore` gab vorübergehende Transportfehler aus Bibliotheks-/Plan-/Protokollabfragen direkt an die Oberfläche weiter. Dies ist ein belegter verbleibender Codepfad, nicht die abschließend bewiesene Ursache auf dem nicht steuerbaren iPhone.

- Workout-Leseausfälle bleiben jetzt still; bereits bestätigte Pläne, Übungen und Satzdaten bleiben bestehen. Die konkret fehlgeschlagenen Lesevorgänge werden kontogebunden für den bestehenden Reconnect vorgemerkt. Auch fehlende vorherige Übungsleistungen werden erneut gelesen. Kein automatisches Wiederholen von Speichern, Einladungen oder Workout-Starts nach unklarem Schreibausgang.
- Der zentrale Reconnect bindet diese ausstehenden Workout-Abfragen ein. Rückmeldung nur im vorhandenen technischen Systemprotokoll; keine neuen Secrets, Nutzernamen, Mailadressen oder Inhaltsdaten im Log. Ein erfolgreicher Feed allein setzt die Wartezeit nicht zurück, solange Workout-Abfragen noch ausstehen.
- Ein vorübergehender Profil-Ladefehler beim Kaltstart hält die wiederhergestellte Sitzung und wiederholt den Start still, statt zur abgemeldeten Seite zu wechseln. Definitiv ungültige Authentifizierung bleibt ein eigener Fehler; sie wird nicht als Netzproblem unterdrückt.
- Ein direkter Wechsel der Schnittstelle bei weiterhin verfügbarer Route, etwa WLAN → Mobilfunk, löst nun ebenfalls Aktualisierung aus. Unveränderte Meldungen und der erste unbekannte Zustand tun dies nicht. Es werden nur Schnittstellentypen, keine WLAN-Namen/IPs/Standorte verglichen.
- Automatische Lesestatus-Versuche erzeugen bei kurzem Transportausfall kein Modal. Der frühere Offline-Standardtext wurde aus dem App-Code entfernt. Ein bewusst ausgelöster, nicht bestätigter Schreibvorgang behält dagegen eine neutrale Fehlerrückmeldung: „Die Aktion wurde noch nicht bestätigt. Versuche es erneut.“ Ein Hintergrund-Refresh löscht dieses Speicherergebnis nicht und täuscht keinen Erfolg vor.
- Zwölf zusätzliche native Tests für Fehlerkategorien, Kaltstart/Anmeldeverlust, Schnittstellenwechsel, Schutz nicht bestätigter Aktionen, stille Workout-Leseausfälle/Erholung, Berechtigungen, Kontowechsel und Leistungs-Nachladen: **AUSGEFÜHRT UND BESTANDEN in QA #70** (`704674e`). Vollständiges Nutzer-ZIP ausgewertet: `AppStoreConnectivityTests` 5/5, `SupabaseRESTClientTests` 7/7, `WorkoutStoreTests` 35/35 PASS. Diese Klassenzahlen enthalten auch bestehende Tests; die zwölf neuen Fälle sind enthalten. Simulierte Antworten, kein echter Offline-/Supabase-/TestFlight-Gerätetest. Gesamt-QA #70 bleibt wegen eines unabhängigen Suchfehlers FAIL: [Test-/Bildnachweis](REFERENCE_QA_70.md).

Die darunterstehenden Build-13-/Codemagic-56-Nachweise beziehen sich auf den älteren Commit, nicht auf diese Änderungen. Alle echten Gerätefälle am Dokumentende bleiben **NICHT AUSGEFÜHRT**. Die installierte TestFlight-Buildnummer wurde in dieser Runde nicht bestimmt; kein Upload erfolgt.

## Gefundene Ursachen und Korrekturen im Quellstand

- Die signierten Builds setzen `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` und `APP_ENVIRONMENT=production` vor der Projektgenerierung in `BackendConfig.plist`. Die fertige IPA wird bereits entpackt und gegen genau diese Build-Werte geprüft. Der Ablauf bricht nun zusätzlich sofort ab, wenn URL oder Schlüssel im Codemagic-Bereich fehlen. Die signierte Test-Suite läuft ausdrücklich mit der Release-Konfiguration. Außerdem verdeckt die eingecheckte Platzhalterdatei gültige Debug-/Release-Buildwerte nicht mehr; zuvor gewann der Platzhalter allein durch seine Existenz.
- Die Auth-Daten lagen bereits kontogeschützt im Schlüsselbund und wurden beim Kaltstart geladen. Der Zugriffstoken wurde bisher jedoch nur beim Start erneuert. Jetzt wird er vor jedem geschützten Backend-Aufruf bei nahendem Ablauf erneuert. Antwortet ein Aufruf mit HTTP 401, wird genau einmal zentral erneuert und derselbe noch nicht angenommene Aufruf wiederholt. Nur eine tatsächlich abgelehnte Erneuerung löscht die lokale Auth-Sitzung; Offline- und Serverfehler tun das nicht.
- HTTP 401, HTTP 403/RLS, HTTP 408/429/5xx, sonstige API-Fehler und Transportfehler werden getrennt behandelt. Nach dem Nutzerfeedback vom 07.09.2026 bleiben automatische Feed-Aktualisierungen bei vorübergehendem Offline-/Serverzustand vollständig still: Der aktuelle Stand bleibt sichtbar und FYRUP versucht die Verbindung nach 5, 15, 30 und anschließend 60 Sekunden erneut. Auth-, Zugriffs-, Validierungs- und bewusst ausgelöste Speicherfehler werden weiterhin passend angezeigt; dadurch wird ein fehlgeschlagener Schreibvorgang nicht fälschlich als erfolgreich behandelt.
- Reine Leseaufrufe werden bei kurzzeitigen Transport- oder Serverfehlern begrenzt wiederholt. Schreibaktionen werden wegen möglicher doppelter Ausführung nicht blind nach einem unklaren Transportabbruch wiederholt. Ein 401 kann sicher wiederholt werden, weil der Server den ursprünglichen Aufruf nicht autorisiert hatte.
- Ein systemweiter Netzmonitor erkennt die Rückkehr einer Route nach einem Ausfall. Danach werden Heute, Einladungen, Mitteilungen, Gruppen, Supplemente, Schritte, Energie, Wochenfortschritt und Blind Workouts erneut geladen. Das gilt auch, wenn der erste Start wegen fehlendem Netz keine Auth-Erneuerung abschließen konnte. Der bestehende Foreground-Weg lädt dieselben Kernbereiche nach Rückkehr aus dem Hintergrund.
- Ein Fehler in einer Nebenabfrage ersetzt vorhandene Einladungen, Mitteilungen, Gruppen, Ziele oder letzte Aktivitäten nicht mehr stillschweigend durch leere Listen. Widerrufene Freundesdaten werden weiterhin entfernt.
- FYRUP verwendet im untersuchten Quellstand für diese Kernbereiche ausschließlich HTTPS/REST und keine Supabase-Realtime-/WebSocket-Verbindung. Deshalb existiert derzeit kein verlorener Realtime-Kanal, der separat wieder verbunden werden könnte. Der verlangte Unterbrechungsfall ist für den jetzigen Stand **NICHT ZUTREFFEND**; Aktualität wird durch Foreground-, Pull-to-refresh- und Reconnect-Ladevorgänge hergestellt.

## Datenschutzsicheres TestFlight-Logging

Das Systemprotokoll enthält pro Backend-Aufruf eine zufällige kurze Vorgangskennung, den logischen Endpunkt, die HTTP-Methode, den HTTP-Status bzw. Supabase-Fehlercode, den Auth-Status, den bekannten Netzstatus, Wiederholungsversuche sowie Erfolg oder Fehlschlag der Auth-Erneuerung und des Reconnect-Ladevorgangs. URL, Anon-Key, Zugriffstoken, Refresh-Token, Request-Body, E-Mail, Username und sonstige personenbezogene Inhalte werden nicht protokolliert.

## Ausgeführte Prüfungen

- Lokaler Konfigurations-/Codeaudit von Debug-, Release-, Codemagic-, IPA-Prüf-, Schlüsselbund-, Auth-, Fehler- und Foreground-Pfaden: **AUSGEFÜHRT**.
- Lokale Fehlermapping-Tests für Offline, Timeout, 401, 403/RLS, 503 und sonstige API-Fehler: im nativen Testsatz ergänzt; Ausführung benötigt den nächsten macOS-/Codemagic-Lauf.
- Lokaler Datenbanktest des gleichzeitig ergänzten privaten Übungsverlaufs: **AUSGEFÜHRT UND BESTANDEN**. Kein produktives Konto wurde verändert.
- Codemagic 49 (`4503d12`) führte alle lokalen Vorprüfungen erfolgreich aus und erreichte die native Kompilierung. Sie stoppte dort nach 2 Minuten 23 Sekunden an einer uneindeutigen Swift-Typableitung im Demo-Pfad der neuen Übungshistorie (`[Any]` statt des lokalen Eintragstyps). Die Rückgabe ist im Folgequellstand ausdrücklich typisiert. Das ist kein festgestellter Verbindungs- oder Backendfehler.
- Native Simulator-Kompilierung sowie Unit- und UI-Tests des korrigierten Folgequellstands: **AUSGEFÜHRT UND BESTANDEN** in Codemagic 56 (`a6a9e1b`) mit **475 Einzeltests und 37 Bedienabläufen, jeweils 0 Fehlern**.
- Native Release-/TestFlight-Prüfung desselben Commits: **AUSGEFÜHRT UND BESTANDEN**. Die nur für den Testschritt gesetzte Option `ENABLE_TESTABILITY=YES` beseitigte den belegten Fehler des ersten signierten Versuchs. Der Folgelauf bestätigte 475 Release-Einzeltests ohne Fehler, erzeugte die signierte FYRUP-IPA `1.0.0` / Build `13`, bestand die Prüfung der eingebetteten Produktionskonfiguration und lud die IPA am 07.09.2026 um 05:20 CEST ohne Uploadfehler an App Store Connect. Apples anschließende Verarbeitung und sämtliche physischen Funkwechsel-/Wiederanlauftests bleiben davon getrennt offen.

## Noch zwingend am echten iPhone/TestFlight zu prüfen

- Normaler App-Start: **NICHT AUSGEFÜHRT**.
- App vollständig schließen und wieder öffnen: **NICHT AUSGEFÜHRT**.
- Mehr als zehn Minuten im Hintergrund: **NICHT AUSGEFÜHRT**.
- WLAN ausschalten und wieder einschalten: **NICHT AUSGEFÜHRT**.
- WLAN zu Mobilfunk wechseln: **NICHT AUSGEFÜHRT**.
- Flugmodus kurz ein- und ausschalten: **NICHT AUSGEFÜHRT**.
- Eine abgelaufene Auth-Sitzung im Release-Build simulieren: **NICHT AUSGEFÜHRT**.
- Einen echten RLS-Fehler auslösen und den Text prüfen: **NICHT AUSGEFÜHRT**.
- Supabase Realtime unterbrechen: **NICHT ZUTREFFEND**, solange kein Realtime-Kanal Teil der App ist.

Ein grüner Cloud-Build belegt Kompilierung und Simulation, aber nicht die ausstehenden Funkwechsel auf einem physischen iPhone.
