/**
 * PiketeMaker — anonymous-signal sink (D33 amended · stack A': Cloudflare Worker + KV).
 *
 * Implements EXACTLY `POST /v1/signals` from docs/api/telemetry-ingest-v1.md:
 * anonymous G2-R outcome cards in, pure counters out.
 *
 * The server-side privacy guarantee lives HERE: a card carrying any field
 * outside the per-kind allow-list — above all an id-shaped one (install_id,
 * device_id, event_id, timestamps...) — is REFUSED, so neither a client bug
 * nor a tampered client can turn this sink into a per-device store. Values are
 * enum/pattern-checked so a rare free-form value cannot become a fingerprint
 * (contract §5, bucket allow-listing).
 *
 * Storage: KV counters keyed by the card's canonical field tuple plus the ISO
 * RECEIPT week. No raw rows, no ids, no precise timestamps — the finest time
 * grain stored anywhere is the ISO week (coarser than the contract's
 * day-granular allowance, §6). Counter TTL enforces the retention window.
 *
 * KV vs D1 (why KV): KV increments are read-modify-write, not atomic, so two
 * truly concurrent flushes onto the same counter could lose one count. At
 * Phase-A volume (~180 cards trickling in over weeks) that probability is
 * negligible, and the ADR (§5) already accepts low-single-digit counting noise
 * by design. KV needs zero schema/migrations (one `wrangler kv namespace
 * create`), which keeps the CEO's deploy to 5 commands. If Phase B brings real
 * concurrency or SQL cohorting, graduate to D1/Postgres behind this SAME
 * contract (stack option B) — the app never changes.
 *
 * MIRROR NOTE: backend/telemetry/local/shim_server.py re-implements this exact
 * logic in Python for the node-less local test path. Keep BOTH in sync; the
 * shared suite (backend/telemetry/local/test_ingest.py) is the sync check.
 */

// --- Wire-contract constants (docs/api/telemetry-ingest-v1.md) ---------------

const SIGNALS_PATH = "/v1/signals"; // path-versioned; breaking changes open /v2/
const CARD_SCHEMA = "g2r/v1";
const MAX_BODY_BYTES = 32 * 1024; // contract §5 body cap -> 413
const MAX_CARDS_PER_BATCH = 50; // contract §5 batch cap -> 413
// Per-(truncated)IP budget. A real device sends 1-3 requests over its LIFETIME
// (contract §5); 30/min is a generous NAT allowance yet still kills a naive flood.
const RATE_LIMIT_PER_MIN = 30;
const RATE_WINDOW_TTL_S = 120; // rate-limit keys evaporate: IP is transient (§5)
const COUNT_TTL_S = 180 * 24 * 3600; // §6 retention: raw counters live <= 180 days

// Fixed enums (ADR §2.2) — free-form values are rejected, never stored.
const KINDS = new Set(["install", "week1", "week2"]);
const COHORTS = new Set(["organic", "paid"]);
const PLATFORMS = new Set(["android", "ios"]);
const ANALYSES_BUCKETS = new Set(["0", "1-2", "3-5", "6-10", "10+"]);
const MODE_BUCKETS = new Set(["outfit", "zapas", "mixed"]);

// Per-kind field allow-lists — EXACT card shape; anything else is refused.
const COMMON_FIELDS = ["schema", "kind", "source", "cohort", "platform", "app_version", "locale"];
const KIND_FIELDS = {
  install: [],
  week1: ["retained_w1", "analyses_bucket", "mode_bucket"],
  week2: ["returned_w2"],
};

// Id-shaped field-NAME detector: only refines the rejection reason (any
// unknown field is rejected regardless) so tests/logs can prove the privacy
// rule explicitly. Never logs the value.
const ID_SHAPED_RE = /(^|[_-])(id|uid|uuid|guid|token|key|secret|hash|email|user|device|session|ts|time|timestamp|date|referrer)([_-]|$)/i;

// Per-field value validators. Patterns are deliberately narrow: low
// cardinality is the anti-fingerprint guarantee (ADR §2.2). "|" is excluded
// everywhere because it is the counter-key separator.
const FIELD_RULES = {
  schema: (v) => v === CARD_SCHEMA,
  kind: (v) => KINDS.has(v),
  source: (v) => typeof v === "string" && /^[a-z0-9_.:-]{1,64}$/.test(v),
  cohort: (v) => COHORTS.has(v),
  platform: (v) => PLATFORMS.has(v),
  app_version: (v) => typeof v === "string" && /^\d{1,3}\.\d{1,3}$/.test(v), // major.minor only
  locale: (v) => typeof v === "string" && /^[a-z]{2,3}$/.test(v), // language only
  retained_w1: (v) => typeof v === "boolean",
  returned_w2: (v) => typeof v === "boolean",
  analyses_bucket: (v) => ANALYSES_BUCKETS.has(v),
  mode_bucket: (v) => MODE_BUCKETS.has(v),
};

// --- Pure helpers (mirrored in shim_server.py) -------------------------------

/** Validates one card. Returns {ok:true} or {ok:false, reason}. */
function validateCard(card) {
  if (card === null || typeof card !== "object" || Array.isArray(card)) {
    return { ok: false, reason: "not_an_object" };
  }
  if (!KINDS.has(card.kind)) return { ok: false, reason: "bad_kind" };
  const allowed = new Set([...COMMON_FIELDS, ...KIND_FIELDS[card.kind]]);
  for (const field of Object.keys(card)) {
    if (!allowed.has(field)) {
      // The privacy rule, enforced server-side: refuse potential identifiers.
      return { ok: false, reason: ID_SHAPED_RE.test(field) ? "identifier_refused" : "unknown_field" };
    }
  }
  for (const field of allowed) {
    if (!(field in card)) return { ok: false, reason: `missing_field:${field}` };
    if (!FIELD_RULES[field](card[field])) return { ok: false, reason: `bad_value:${field}` };
  }
  return { ok: true };
}

/**
 * Canonical counter key for a valid card — the whole §6 "counts table" is
 * these keys. Formats (field count disambiguates, parsed by g2r_report.py):
 *   c|v1|install|src|cohort|platform|appver|locale|week            (9 parts)
 *   c|v1|week1|src|cohort|t/f|abucket|mbucket|platform|appver|locale|week (12)
 *   c|v1|week2|src|cohort|t/f|platform|appver|locale|week          (10)
 */
function counterKey(card, week) {
  const b = (v) => (v ? "t" : "f");
  const head = ["c", "v1", card.kind, card.source, card.cohort];
  if (card.kind === "week1") head.push(b(card.retained_w1), card.analyses_bucket, card.mode_bucket);
  else if (card.kind === "week2") head.push(b(card.returned_w2));
  return [...head, card.platform, card.app_version, card.locale, week].join("|");
}

/** ISO-8601 year-week ("2026W29") — matches Python date.isocalendar(). */
function isoWeek(d) {
  const u = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
  const day = u.getUTCDay() || 7; // Mon=1..Sun=7
  u.setUTCDate(u.getUTCDate() + 4 - day); // nearest Thursday decides the ISO year
  const yearStart = Date.UTC(u.getUTCFullYear(), 0, 1);
  const week = Math.ceil(((u.getTime() - yearStart) / 86400000 + 1) / 7);
  return `${u.getUTCFullYear()}W${String(week).padStart(2, "0")}`;
}

/** Rate-limit bucket: IPv4 /24, IPv6 ~/48 — never stored beyond the window. */
function truncateIp(ip) {
  if (ip.includes(":")) return ip.split(":").slice(0, 3).join(":");
  return ip.split(".").slice(0, 3).join(".") + ".0";
}

function json(status, obj, headers = {}) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { "content-type": "application/json", ...headers },
  });
}

// --- Handler -----------------------------------------------------------------

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname !== SIGNALS_PATH) return json(404, { error: "not_found" });
    // Method hygiene. No CORS headers on purpose: the client is a native app;
    // browsers are denied by default (nothing to relax until a web client exists).
    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: { allow: "POST" } });
    if (request.method !== "POST") return json(405, { error: "method_not_allowed" }, { allow: "POST" });

    // Auth (§4): write-only app key. Fail closed if the secret is unset.
    if (!env.API_KEY || request.headers.get("X-Api-Key") !== env.API_KEY) {
      return json(401, { error: "unauthorized" });
    }

    // Rate limit (§5): per-truncated-IP counter in KV with a short TTL.
    // Read-modify-write, i.e. approximate — a "low bar against casual spam"
    // per the contract, not a fortress.
    const ip = truncateIp(request.headers.get("CF-Connecting-IP") || "0.0.0.0");
    const rlKey = `rl|${ip}|${Math.floor(Date.now() / 60000)}`;
    const hits = parseInt((await env.SIGNALS.get(rlKey)) || "0", 10);
    if (hits >= RATE_LIMIT_PER_MIN) {
      return json(429, { error: "rate_limited" }, { "retry-after": "60" });
    }
    await env.SIGNALS.put(rlKey, String(hits + 1), { expirationTtl: RATE_WINDOW_TTL_S });

    // Body caps (§5) -> 413.
    const raw = await request.text();
    if (new TextEncoder().encode(raw).length > MAX_BODY_BYTES) {
      return json(413, { error: "payload_too_large" });
    }

    // Envelope: exactly {"signals": [...]} — anything else is malformed (400).
    let body;
    try {
      body = JSON.parse(raw);
    } catch {
      return json(400, { error: "malformed_json" });
    }
    if (
      body === null || typeof body !== "object" || Array.isArray(body) ||
      !Array.isArray(body.signals) || Object.keys(body).length !== 1
    ) {
      return json(400, { error: "bad_envelope" });
    }
    if (body.signals.length > MAX_CARDS_PER_BATCH) return json(413, { error: "too_many_cards" });

    // Per-card validation is NON-FATAL (§2): valid cards still count.
    // NO dedup by design (§3): a re-sent card increments again — accepted noise.
    const week = isoWeek(new Date());
    const increments = new Map(); // counterKey -> n (aggregate within the batch)
    let accepted = 0;
    let rejected = 0;
    for (const card of body.signals) {
      const v = validateCard(card);
      if (!v.ok) {
        rejected += 1;
        console.log(`card_rejected reason=${v.reason}`); // reason only — never the payload
        continue;
      }
      const key = counterKey(card, week);
      increments.set(key, (increments.get(key) || 0) + 1);
      accepted += 1;
    }
    for (const [key, n] of increments) {
      const current = parseInt((await env.SIGNALS.get(key)) || "0", 10);
      await env.SIGNALS.put(key, String(current + n), { expirationTtl: COUNT_TTL_S });
    }

    return json(202, { accepted, rejected });
  },
};

// Exported for potential unit tests under node/wrangler (unused by the runtime).
export { validateCard, counterKey, isoWeek, truncateIp };
