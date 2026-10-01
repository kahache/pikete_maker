import 'dart:convert';
import 'dart:io';

/// How a flush attempt resolved — the controller maps each outcome to the
/// contract's client rules (wire contract §2 status table + §3):
///
/// * loss is ALWAYS preferred over duplication (there is no server-side
///   dedup, by design — a dedup key would be a linkable id);
/// * only outcomes where the request provably never reached the wire are
///   safe to retry.
enum TelemetrySendOutcome {
  /// `2xx` — cards counted. Clear the queue, set the local sent-flags.
  delivered,

  /// The request never left (no connectivity, DNS/connect failure). The only
  /// UNAMBIGUOUSLY safe retry: keep the cards queued for a later flush.
  notSent,

  /// The request (partially) reached the wire but the response is unknown
  /// (timeout, dropped socket). The server MAY have counted the cards —
  /// resending risks double-count, so the client treats this as sent and
  /// accepts the possible loss (ADR §5).
  ambiguous,

  /// `4xx` (bad schema / bad key / oversized) — never retry malformed
  /// (contract: "drop the batch"). Clear and move on.
  rejected,

  /// `429` — rate-limited. Keep the cards queued, try again later.
  rateLimited,

  /// `5xx` — transient server trouble. Contract §2: retry AT MOST ONCE,
  /// then give up (accept loss). The controller tracks the single retry.
  serverError,
}

/// Transport seam: ships a batch of anonymous cards to the ingest endpoint.
/// Implementations must never throw — every failure is an outcome.
abstract interface class TelemetryTransport {
  /// Ships [cards] to the ingest endpoint. Never throws: every failure comes
  /// back as a [TelemetrySendOutcome].
  Future<TelemetrySendOutcome> send(List<Map<String, Object?>> cards);
}

/// Real transport over `dart:io` [HttpClient].
///
/// Deliberately NOT `package:http` nor any networking package: the payload is
/// one tiny JSON POST a handful of times per install-lifetime, and the SDK
/// client costs zero APK bytes (G1: no dependency that doesn't pull its
/// weight).
class HttpTelemetryTransport implements TelemetryTransport {
  /// Creates a transport posting to [endpoint], optionally authenticated
  /// with [apiKey].
  HttpTelemetryTransport({required this.endpoint, this.apiKey = ''});

  /// Full ingest URL (`https://host/v1/signals`).
  final String endpoint;

  /// Write-only app key (`X-Api-Key`, contract §4). Empty ⇒ header omitted.
  final String apiKey;

  /// Short, generous timeouts: this is a background fire-and-forget send —
  /// it must never hold resources for long, and a timeout is just a normal
  /// [TelemetrySendOutcome.ambiguous].
  static const Duration _connectTimeout = Duration(seconds: 8);
  static const Duration _responseTimeout = Duration(seconds: 12);

  @override
  Future<TelemetrySendOutcome> send(List<Map<String, Object?>> cards) async {
    final HttpClient client = HttpClient()..connectionTimeout = _connectTimeout;
    HttpClientRequest request;
    try {
      // Connection establishment happens inside postUrl: an exception here
      // means NOTHING reached the server → the safe-retry outcome.
      request = await client.postUrl(Uri.parse(endpoint));
    } catch (_) {
      client.close(force: true);
      return TelemetrySendOutcome.notSent;
    }
    try {
      request.headers.contentType = ContentType.json;
      if (apiKey.isNotEmpty) request.headers.set('X-Api-Key', apiKey);
      request.add(utf8.encode(jsonEncode(<String, Object?>{'signals': cards})));
      final HttpClientResponse response =
          await request.close().timeout(_responseTimeout);
      await response.drain<void>(); // body content is irrelevant to the client
      final int code = response.statusCode;
      if (code >= 200 && code < 300) return TelemetrySendOutcome.delivered;
      if (code == 429) return TelemetrySendOutcome.rateLimited;
      if (code >= 500) return TelemetrySendOutcome.serverError;
      return TelemetrySendOutcome.rejected; // 4xx: malformed/unauthorized
    } catch (_) {
      // The body may already have hit the server: ambiguous by definition.
      return TelemetrySendOutcome.ambiguous;
    } finally {
      client.close(force: true);
    }
  }
}
