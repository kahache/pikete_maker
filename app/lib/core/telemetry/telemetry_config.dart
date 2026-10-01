/// D33 (amended) telemetry — compile-time configuration.
///
/// Telemetry is OFF unless an ingest endpoint is baked in at build time:
///
/// ```
/// flutter build apk --dart-define=TELEMETRY_ENDPOINT=https://.../v1/signals \
///                   --dart-define=TELEMETRY_API_KEY=pk_...
/// ```
///
/// With [kTelemetryEndpoint] EMPTY (every build today, and every test run)
/// the whole subsystem is inert: no network call, no local storage touched,
/// no notice shown — the app behaves exactly as r10. This keeps the D15
/// "100% offline" posture the default and makes turning telemetry on an
/// explicit, auditable build decision (no runtime toggle can enable it).
///
/// Wire contract: `docs/api/telemetry-ingest-v1.md` (POST /v1/signals,
/// anonymous cards). Rationale/card shapes: the 2026-07-19 telemetry ADR.
/// Notice/opt-out copy: `docs/legal/consent-copy-first-run.md`.
library;

/// Ingest endpoint (full URL, e.g. `https://host/v1/signals`).
/// EMPTY (the default) ⇒ telemetry fully OFF.
const String kTelemetryEndpoint = String.fromEnvironment('TELEMETRY_ENDPOINT');

/// Write-only app key sent as `X-Api-Key` (contract §4). Not a real secret
/// (it ships in the client); the server's rate-limit is the actual guard.
const String kTelemetryApiKey = String.fromEnvironment('TELEMETRY_API_KEY');

/// Version string of the first-run notice the user saw (legal doc §4: the
/// audit trail is this app-level flag + the published notice version — there
/// is no per-user consent receipt because there is no user id).
const String kTelemetryNoticeVersion = 'notice-v1';

/// Optional privacy-policy URL behind the notice's secondary link ("Cómo
/// tratamos los datos"). EMPTY ⇒ the link is hidden (no policy page exists
/// yet; the CEO publishes it before any telemetry-enabled build ships).
const String kPrivacyPolicyUrl = String.fromEnvironment('PRIVACY_POLICY_URL');

/// Coarse app version stamped on every card (`app_version`, major.minor ONLY
/// — contract §5 keeps cardinality low so no card is a fingerprint). Kept as
/// a const to avoid a runtime package-info dependency (G1: zero new plugins);
/// bump alongside the pubspec minor.
const String kTelemetryAppVersion = '0.1';

/// Default attribution while no install-referrer integration exists (ADR §3
/// leaves the seam: a deep-link / Play Install Referrer source can overwrite
/// this once, at first run, via [TelemetryController.setSource]).
const String kTelemetryDefaultSource = 'organic-unattributed';

/// Default cohort. `paid:*` campaigns flip this via the same seam.
const String kTelemetryDefaultCohort = 'organic';
