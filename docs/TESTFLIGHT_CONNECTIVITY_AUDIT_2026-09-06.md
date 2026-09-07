# TestFlight-Verbindungsprüfung – 06.09.2026

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
