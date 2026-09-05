# Signierter Build 8 – Einlesen des Apple-Profils

Am 05.09.2026 scheiterte der [signierte Build 8](https://codemagic.io/app/6a9aff9f64377f6028cc8d18/build/6a9bfd86b233a8e3792c5733) nach 1 min 16 s in „Verify renewed HealthKit signing profile“. **Keine IPA und kein Apple-Upload.** Die Bereitstellung der Signierungsidentitäten war zuvor erfolgreich.

Konkreter Fehler: `plistlib.load(sys.stdin.buffer)` versucht bei der Formaterkennung `seek(0)`, aber die Ausgabe von `security cms` kommt über eine nicht positionierbare Pipe. `io.UnsupportedOperation: File or stream is not seekable` ist ein Skriptfehler, kein Nachweis fehlender HealthKit-Berechtigung im Profil.

Die Prüfung liegt nun in `scripts/verify-signing-profile.py`. Sie liest die Bytes zuerst vollständig ein und verwendet `plistlib.loads`. App-ID, HealthKit, Apple-Anmeldung und Production-Push bleiben zwingend erforderlich. Ungültige Daten führen zu Exitcode 1; `pipefail` lässt auch einen vorgelagerten Apple-Decoderfehler scheitern. Es werden weder Profilinhalt noch Schlüssel ausgegeben.

Sieben lokale Python-Tests bestanden: XML/Binärformat, echte stdin-Pipe für beide Formate, leere/defekte Daten, falsche Struktur, falsche und jeweils fehlende Berechtigungen sowie nicht erfolgreicher Prozessausgang bei falschem Push-Umfeld. Die Testdateien enthalten ausschließlich synthetische Daten. Die gleiche Testsuite läuft vor jeder echten Profilprüfung in Codemagic.

Die isolierte Skriptkorrektur wurde als `7472300` separat hochgeladen, ohne GitHub-Lauf 45 oder Simulator-Build 35 abzubrechen. Beide haben ihre App-Prüfungen inzwischen erfolgreich abgeschlossen.

**Nachtest gegen das echte Apple-Profil bestanden:** [Signierter Build 9](https://codemagic.io/app/6a9aff9f64377f6028cc8d18/build/6a9c07536942048ebcb1f844), Zweig `codex/signing-profile-pipe`, hat sieben Tests in 0,064 s ausgeführt und anschließend ausdrücklich „Verified FYRUP profile: HealthKit, Apple sign-in and production push“ protokolliert. Danach startet die vollständige native Testsuite. IPA-Bau und Apple-Upload bleiben zum Zeitpunkt dieser Kontrolle noch offen. Die nachfolgenden lokalen Datenschutz-/Layoutänderungen sind nicht Teil dieses Builds.
