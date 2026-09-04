# FYRUP

FYRUP ist eine native Social-Fitness-App für iPhone. Die Startseite beantwortet zuerst, was heute in der eigenen Crew passiert: LIVE, PLANNED, DONE oder neutral NOT YET. Der Produktloop besteht aus Training starten/planen, Freunde einladen, mitziehen, FYR UP und Reaktionen – ohne GPS, Kalorien- oder Satztracking.

## Stand der V1

Enthalten sind eine native SwiftUI-App, ein Supabase/PostgreSQL-Backend mit RLS, APNs-Dispatch als Edge Function, Account-Löschung, lokale Demo-Daten, Unit-/UI-/RLS-Tests und Release-Konfiguration. Das Repository wird über XcodeGen reproduzierbar in ein Xcode-Projekt übersetzt; generierte `.xcodeproj`-Dateien werden nicht versioniert.

## Architektur

```text
FYRUP/
  App/             App entry, APNs registration
  Core/            configuration, design system, calendar logic
  Models/          typed domain models and state enums
  Services/        repository contract, Supabase REST/Auth client, Keychain, demo
  ViewModels/      @Observable application store
  Views/           SwiftUI features and reusable components
  Resources/       localization and asset catalog
supabase/
  migrations/      schema, constraints, RPCs, RLS, scheduling support
  functions/       APNs dispatch and authenticated account deletion
  seed/            guarded local development fixtures
  tests/           pgTAP security/schema checks
```

Views kennen keine Backend-Details. `AppStore` orchestriert UI-Zustand und ruft ausschließlich `AppRepository` auf. `LiveAppRepository` spricht Supabase Auth, PostgREST und Edge Functions. Kritische Mutationen laufen über atomare `security definer`-RPCs. Die Demo implementiert denselben Vertrag und wird nur mit `--demo` aktiviert; bei fehlender Production-Konfiguration zeigt die App einen Setup-Screen statt Fake-Daten.

## Voraussetzungen

- macOS mit Xcode 16 oder neuer
- XcodeGen 2.45 oder neuer (`brew install xcodegen`)
- Supabase CLI 2.x und Docker für die lokale Datenbank
- Apple Developer Team für Sign in with Apple, APNs und TestFlight
- Deno nur für optionale lokale Edge-Function-Checks

## Supabase lokal einrichten

```bash
supabase start
supabase db reset
supabase test db
```

Migrationen erzeugen alle Tabellen, Enums, Indizes, RLS-Policies, Seed-Kataloge und RPCs. `supabase/seed/seed.sql` ist absichtlich lokal und fügt Profildaten nur ein, wenn die fünf stabilen Auth-UUIDs bereits in Local Studio angelegt wurden. Für eine sofortige UI-Vorschau ist `--demo` einfacher.

Für ein Remote-Projekt:

```bash
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
supabase functions deploy dispatch-notifications
supabase functions deploy delete-account
```

Setze Function Secrets:

```bash
supabase secrets set APNS_KEY_ID=... APNS_TEAM_ID=... APNS_PRIVATE_KEY='...' APNS_TOPIC=app.fyrup.ios CRON_SECRET=...
```

Plane in Supabase Cron alle fünf Minuten `select public.process_scheduled_sessions();` und rufe danach `dispatch-notifications` mit `x-cron-secret` auf. APNs-Schlüssel liegen ausschließlich als Server-Secret vor.

## iOS konfigurieren

Erstelle `Config/Secrets.xcconfig` (wird von Git ignoriert):

```xcconfig
SUPABASE_URL = https:/$()/YOUR_PROJECT.supabase.co
SUPABASE_PUBLISHABLE_KEY = sb_publishable_...
```

Danach:

```bash
xcodegen generate
open FYRUP.xcodeproj
```

Wähle in Xcode dein Development Team. Der voreingestellte Bundle Identifier ist `app.fyrup.ios`; ändere ihn in `project.yml`, wenn dieser im Developer Account nicht verfügbar ist, und generiere erneut.

## Sign in with Apple

1. Lege eine explizite App ID mit dem Bundle Identifier an.
2. Aktiviere Sign in with Apple in Developer Portal und Supabase Auth Providers.
3. Hinterlege dort Services ID, Team ID, Key ID und das erzeugte Secret.
4. Prüfe, dass die Capability nach `xcodegen generate` am App Target sichtbar ist.

Die App erzeugt pro Login einen kryptografischen Nonce, sendet dessen SHA-256-Hash an Apple und tauscht das ID Token mit dem Original-Nonce bei Supabase Auth ein.

## Push Notifications

1. Aktiviere Push Notifications für die App ID und das Target.
2. Erzeuge einen APNs Authentication Key und setze die oben genannten Function Secrets.
3. Nutze `ios-sandbox` für Development-Tokens und `ios` für TestFlight/Production.
4. Teste auf einem echten Gerät; Simulator- und Push-Verhalten unterscheiden sich.

Der Client registriert nur den Device Token. Social Events erzeugen serverseitige Inbox-Einträge. Die Dispatcher Function sendet APNs, markiert verarbeitete Einträge und entfernt von APNs als ungültig gemeldete Tokens.

## Entwickeln und testen

Demo-Scheme-Argument: `--demo`. Dadurch werden Momo, Max (LIVE), Sarah (DONE) und Leon (NOT YET) geladen, ohne Production-Daten zu simulieren.

```bash
xcodegen generate
xcodebuild -project FYRUP.xcodeproj -scheme FYRUP \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  CODE_SIGNING_ALLOWED=NO build test
supabase test db
```

Unit Tests prüfen Tageswechsel, Feed-Priorität, Wochenziel-Streak, Timer, Activity-Lifecycle, genau eine LIVE-Aktivität, Planen und FYR-UP-Deduplizierung. UI Tests decken Start → LIVE → DONE und den Ein-Tap-FYR-UP-Flow ab. pgTAP prüft Kernschema, Constraints und RLS-Policy-Sets. GitHub Actions führt iOS Build und Tests auf macOS aus.

### Ohne eigenen Mac

`codemagic.yaml` enthält einen vollständigen macOS-Cloud-Workflow. Repository bei GitHub/GitLab/Bitbucket hochladen, in Codemagic verbinden und `FYRUP iOS Cloud Build & Tests` starten. Der Runner installiert XcodeGen, erzeugt das Projekt und führt Build, Unit Tests und UI Tests im iPhone-Simulator aus. Dafür ist noch kein Apple-Developer-Account nötig; Signierung und TestFlight benötigen ihn später.

Für den signierten Workflow `FYRUP Signed TestFlight Build` werden in Codemagic zwei geheime Variablengruppen benötigt:

- `appstore_credentials`: `APP_STORE_CONNECT_PRIVATE_KEY`, `APP_STORE_CONNECT_KEY_IDENTIFIER`, `APP_STORE_CONNECT_ISSUER_ID`, `CERTIFICATE_PRIVATE_KEY`
- `fyrup_backend`: `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`

Der Workflow holt oder erzeugt passende App-Store-Signing-Dateien für `app.fyrup.ios`, vergibt eine eindeutige Buildnummer, baut die IPA und lädt sie zu App Store Connect hoch. Secrets werden nur während des Builds in die ignorierte `Config/Secrets.xcconfig` geschrieben.

## Release / TestFlight

Die Version ist `1.0.0 (1)`, Release nutzt Whole Module Optimization, App Icon und Launch Screen sind vorhanden, das iPhone ist das einzige Zielgerät, und die Entitlements enthalten Apple Sign-In sowie Push. Vor dem ersten Archive:

1. Bundle ID und Team festlegen.
2. Production-Supabase-Projekt migrieren und Release-Secrets eintragen.
3. Apple-/APNs-Konfiguration abschließen.
4. Datenschutzangaben, Support-URL, Screenshots und App-Metadaten in App Store Connect ergänzen.
5. Auf zwei echten Accounts den Ablauf in `docs/RELEASE_CHECKLIST.md` abnehmen.
6. `Product > Archive`, anschließend `Distribute App > App Store Connect > Upload`.

## Datenschutz und Sicherheit

- Profile und Aktivitäten sind nicht öffentlich; Activity Visibility ist `friends` oder `nobody`.
- Freundschaft ist beidseitig, Blocks greifen in den zentralen Server-Helpern.
- Es gibt keinen Standortzugriff, kein GPS und kein HealthKit.
- Tokens liegen im Keychain; Publishable Key und Project URL sind keine Geheimnisse, RLS bleibt trotzdem zwingend.
- Service Role und APNs Credentials dürfen nie in `Secrets.xcconfig` oder die App.
- Account-Löschung validiert das JWT serverseitig und löscht den Auth-User; Cascades entfernen personenbezogene App-Daten.

## Bekannte Grenzen

- Das Repository wurde auf Windows erstellt; ein echter Xcode-/Simulator-Build muss auf macOS bzw. CI laufen.
- Remote E-Mail-Zustellung, Apple Login und APNs hängen von den jeweiligen externen Account-Einstellungen ab.
- Kein GPS, HealthKit, Apple Watch, öffentlicher Feed, Chat, Payment oder Community – bewusst außerhalb V1.
- Das Crew-Ziel ist in V1 automatisch aus Freundeskreis und Wochenbeiträgen abgeleitet; Gruppenverwaltung ist für V2 vorgesehen.

Siehe [Backend-Dokumentation](docs/BACKEND.md) und [Release-Checkliste](docs/RELEASE_CHECKLIST.md).
