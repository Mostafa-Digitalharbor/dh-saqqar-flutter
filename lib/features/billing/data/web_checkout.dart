import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/error/app_failure.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_error_mapper.dart';

/// What to open in the browser, and what the user should be told first.
@immutable
class WebCheckoutTarget {
  const WebCheckoutTarget({
    required this.uri,
    required this.signedIn,
    this.failure,
    this.blocking = false,
  });

  final Uri uri;

  /// True when [uri] carries a one-time login hand-off, so the browser opens
  /// already signed in as this user.
  final bool signedIn;

  /// Set when something went wrong that the user should hear about. Null both
  /// when the hand-off worked and when the server simply doesn't offer one —
  /// neither is an error the user can act on.
  final AppFailure? failure;

  /// True when opening the browser would be pointless or misleading (no
  /// connection, or the session has ended). The caller shows [failure] and
  /// stops instead of launching.
  final bool blocking;
}

/// The hand-off to where subscriptions are actually sold.
///
/// Paymob is live on saqqaar.com and takes every payment. The app's job is to
/// show the catalogue and open the right page — it never sees a card number, a
/// payment reference or an order.
///
/// Deliberately a URL rather than a `POST /billing/checkout/` round-trip. The
/// app holding a payment reference would mean the app owning a payment state
/// machine, which is the thing that has to change every time pricing does.
/// Handing the browser a URL means the web checkout can change entirely —
/// processor, currencies, cycles, VAT handling — without a store release.
class WebCheckout {
  WebCheckout._();

  static const _tag = 'WebCheckout';

  /// How long we'll wait for the login hand-off before giving up and opening
  /// the plain page. A tap that hangs is worse than a tap that lands you on a
  /// sign-in form. Measured against production 2026-08-03: ~100 ms warm.
  static const _handoffTimeout = Duration(seconds: 6);

  /// Built from [ApiEndpoints.baseUrl] so a staging build points at staging
  /// rather than sending a tester to production's payment page.
  static Uri get pricingUrl => Uri.parse('${ApiEndpoints.baseUrl}/pricing/');

  /// Relative path for a tier, e.g. `/pricing/?plan=pro`.
  ///
  /// The slug is the server's own (`free` / `starter` / `max-5x` / `pro` /
  /// `max-20x`, from `GET /api/v1/plans/`), passed straight through — the app
  /// must not invent plan identifiers, and these are already the ones the web
  /// checkout knows.
  static String nextPath(String slug) =>
      slug.isEmpty ? '/pricing/' : '/pricing/?plan=$slug';

  /// Absolute pricing URL for a tier.
  static Uri pricingUrlFor(String slug) =>
      Uri.parse('${ApiEndpoints.baseUrl}${nextPath(slug)}');

  /// Resolves the target, then opens it in the **external** browser.
  ///
  /// External, not an in-app web view: the user is about to type card details
  /// and needs the browser's own address bar and padlock to see who they are
  /// paying. An in-app view also can't share the session cookie, so they would
  /// have to sign in again on a page that then asks for a card — which is
  /// indistinguishable from a phishing flow.
  ///
  /// Returns the resolved target so the caller can explain what happened.
  /// `launched` is false when the browser refused the URL or when the target
  /// was [WebCheckoutTarget.blocking].
  static Future<({WebCheckoutTarget target, bool launched})> open(
    Dio dio, {
    String slug = '',
  }) async {
    final target = await resolveTarget(dio, slug);
    if (target.blocking) return (target: target, launched: false);
    try {
      final ok = await launchUrl(target.uri, mode: LaunchMode.externalApplication);
      return (target: target, launched: ok);
    } catch (e, st) {
      AppLogger.warn(_tag, 'launch failed', error: e, stackTrace: st);
      return (target: target, launched: false);
    }
  }

  /// Asks the server for a one-time signed-in hand-off, falling back to the
  /// plain pricing page.
  ///
  /// `POST /auth/web-session/` returns `{ok, url}` where `url` is
  /// `/auth/handoff/?t=<one-time-token>` (verified live 2026-08-03, ~100 ms).
  /// It rejects an off-site or protocol-relative `next` with a 400, so a
  /// tampered path can't turn it into an open redirect.
  ///
  /// **Every failure still yields a usable URL** — the plain price list. What
  /// differs is whether the user is told why they'll have to sign in, which is
  /// the whole point of returning a [WebCheckoutTarget] rather than a `Uri`:
  /// silently dropping someone on a signed-out page after they tapped
  /// "Subscribe" reads as the app being broken.
  @visibleForTesting
  static Future<WebCheckoutTarget> resolveTarget(Dio dio, String slug) async {
    final fallback = pricingUrlFor(slug);
    WebCheckoutTarget plain({AppFailure? failure, bool blocking = false}) =>
        WebCheckoutTarget(
          uri: fallback,
          signedIn: false,
          failure: failure,
          blocking: blocking,
        );

    Response<Map<String, dynamic>> res;
    try {
      res = await dio.post<Map<String, dynamic>>(
        ApiEndpoints.authWebSession,
        data: {'next': nextPath(slug)},
        options: Options(
          sendTimeout: _handoffTimeout,
          receiveTimeout: _handoffTimeout,
          // Handle the status ourselves — a 404 from a server that hasn't
          // deployed this yet is an expected answer, not an exception, and it
          // must not reach the 401 interceptor and end the session.
          validateStatus: (_) => true,
        ),
      );
    } on DioException catch (e) {
      final failure = ApiErrorMapper.toFailure(e);
      // A body we can't parse — Django's HTML 404 page is the shape this
      // takes — is functionally "no hand-off offered". The price list still
      // opens and there is nothing the user could do with a parse error, so
      // it gets the same silent treatment as a 404 rather than a technical
      // sentence about response shapes.
      if (failure is ParseFailure) {
        AppLogger.warn(_tag, 'hand-off returned an unreadable body', error: e);
        return plain();
      }
      // No connection means the browser has nothing to load either, so say so
      // and don't launch — an empty browser tab is a worse answer than a
      // sentence.
      final offline = failure is NetworkFailure || failure is TimeoutFailure;
      AppLogger.warn(_tag, 'hand-off request failed', error: e);
      return plain(failure: failure, blocking: offline);
    } catch (e) {
      AppLogger.debug(_tag, 'hand-off unavailable: $e');
      return plain();
    }

    final status = res.statusCode ?? 0;
    if (status != 200) {
      final failure = ApiErrorMapper.toFailure(
        DioException.badResponse(
          statusCode: status,
          requestOptions: res.requestOptions,
          response: res,
        ),
      );
      switch (status) {
        case 404:
          // Server doesn't offer the hand-off. Nothing the user can do and
          // nothing they'd want told — open the plain page.
          AppLogger.debug(_tag, 'hand-off not deployed (404)');
          return plain();
        case 400:
          // We sent a `next` the server refused. That is our bug, not the
          // user's — log it loudly, and don't put a validation error in front
          // of someone who just tapped Subscribe.
          AppLogger.error(_tag,
              'hand-off rejected our next path — check nextPath(): ${res.data}');
          return plain();
        case 401:
          // The session is gone. Opening a browser mid-way just adds a second
          // sign-in screen to the one they're about to get in the app.
          return plain(failure: failure, blocking: true);
        default:
          AppLogger.warn(_tag, 'hand-off failed with $status: ${res.data}');
          return plain(failure: failure);
      }
    }

    final raw = res.data?['url'];
    if (raw is! String || raw.isEmpty) {
      AppLogger.warn(_tag, 'hand-off 200 with no url: ${res.data}');
      return plain(failure: const ServerFailure(statusCode: 200));
    }
    final parsed = Uri.tryParse(raw);
    if (parsed == null) {
      AppLogger.warn(_tag, 'hand-off url unparseable: $raw');
      return plain(failure: const ServerFailure(statusCode: 200));
    }
    // Host-check the response before handing it to a browser. This URL carries
    // a live login token; a wrong or tampered `url` would deliver the user's
    // session to whoever it points at. The server should never return an
    // off-host URL — so if it does, we don't follow it.
    if (parsed.host != pricingUrl.host || parsed.scheme != 'https') {
      AppLogger.error(
        _tag,
        'hand-off URL rejected: ${parsed.scheme}://${parsed.host} '
        '(expected https://${pricingUrl.host})',
      );
      return plain(failure: const ServerFailure(statusCode: 200));
    }
    return WebCheckoutTarget(uri: parsed, signedIn: true);
  }
}

/// Visible for tests — the URL shape is part of the contract with the web
/// team, so it is asserted rather than eyeballed.
@visibleForTesting
String debugPricingUrl(String slug) => WebCheckout.pricingUrlFor(slug).toString();
