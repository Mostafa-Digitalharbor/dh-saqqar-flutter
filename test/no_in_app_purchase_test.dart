// No payment is ever taken inside the app.
//
// Paymob is live on saqqaar.com and takes every subscription. The app shows
// the catalogue and opens the browser; it never sees a card, an order or a
// payment reference. That is the claim filed with Apple and it is the claim
// these tests hold to, because it is invisible from inside the app — you
// cannot notice a missing purchase flow in code review the way you notice a
// broken one.
//
// What is deliberately NOT asserted here is that prices are hidden. Showing
// prices and linking out is a store-policy judgement (App Store 3.1.1, Google
// Play Payments anti-steering) that lives behind one build flag —
// `kShowWebSubscribe`. Both sides of it are exercised below, because the
// branch nobody tests is the one shipped in a hurry when App Review objects.
//
// See docs/STORE_PAYMENTS_COMPLIANCE.md.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/error/app_failure.dart';
import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/routing/route_names.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/features/billing/data/billing_visibility.dart';
import 'package:saqqar_app/features/billing/data/plan_models.dart';
import 'package:saqqar_app/features/billing/data/web_checkout.dart';
import 'package:saqqar_app/features/chat/widgets/chat_plan_banner.dart';
import 'package:saqqar_app/shared/widgets/ghost_button.dart';

/// Answers every request with a fixed status + body, and records what was
/// sent. Nothing leaves the process.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.status, [this.body, this.contentType]);

  final int status;
  final Object? body;

  /// Defaults to JSON. Pass `text/html` to reproduce Django's 404 page, which
  /// is what the not-yet-built endpoint actually returns in production — the
  /// generic on `dio.post<Map<String, dynamic>>` cannot hold a String, so
  /// that path throws rather than returning a non-200, and it has to be
  /// covered separately.
  final String? contentType;

  Map<String, dynamic>? sentBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final data = options.data;
    if (data is Map) sentBody = data.cast<String, dynamic>();
    final isJson = contentType == null;
    return ResponseBody.fromString(
      body == null ? '' : (isJson ? jsonEncode(body) : body.toString()),
      status,
      headers: {
        Headers.contentTypeHeader: [contentType ?? Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Stands in for offline / DNS failure / timeout.
class _ThrowingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'no route to host',
      );

  @override
  void close({bool force = false}) {}
}

Widget _harness(Widget child, {String locale = 'en'}) => MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ar')],
      theme: AppTheme.light(Locale(locale)),
      home: Scaffold(body: child),
    );

void main() {
  tearDown(() => debugShowPaidUpsell = null);

  group('the app cannot take a payment', () {
    test('no store-billing SDK is declared', () {
      // Adding one of these is the single change that would make the "nothing
      // is charged in this app" statement filed with Apple untrue, and it
      // would do so without touching a widget. It would also be inert: the
      // server has no receipt-verification endpoint to hand a purchase to
      // (`POST /billing/iap/verify/` → 404, verified against production
      // 2026-07-29), so a purchase would take the money and credit nothing.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final pkg in const [
        'in_app_purchase',
        'purchases_flutter',
        'flutter_inapp_purchase',
      ]) {
        expect(
          pubspec.contains(pkg),
          isFalse,
          reason: '$pkg is declared — read the header of this file before '
              'adding any store-billing SDK',
        );
      }
    });

    test('a tier at or below the current one is not sellable', () {
      // Mirrors the guard in PricingScreen: a Business customer was being
      // offered "Subscribe on the web" on Starter, Solo and Professional —
      // a tap that takes money for a downgrade the server has no path to
      // apply (QA 2026-08-02, P1). Ranking is the server's own `sort`.
      bool sellable({required int tierSort, required int? currentSort}) =>
          currentSort == null || tierSort > currentSort;

      const business = 4; // sort values from GET /api/v1/plans/
      expect(sellable(tierSort: 1, currentSort: business), isFalse); // Starter
      expect(sellable(tierSort: 3, currentSort: business), isFalse); // Pro
      expect(sellable(tierSort: 4, currentSort: business), isFalse); // itself
      expect(sellable(tierSort: 3, currentSort: 0), isTrue); // Free → Pro
      // Unknown current plan sells everything rather than guessing — hiding a
      // tier someone wants to buy is the worse failure.
      expect(sellable(tierSort: 1, currentSort: null), isTrue);
    });

    test('the in-app Paymob checkout has no route of its own', () {
      // `/billing/checkout` still exists so an old deep link lands somewhere
      // sensible, but it redirects to the catalogue. If these two ever became
      // the same path the redirect would be a loop, and if the checkout path
      // stopped being registered an old link would dead-end instead.
      expect(RouteNames.checkoutPath, isNot(RouteNames.pricingPath));
      expect(RouteNames.pricingPath, '/pricing');
    });
  });

  group('the login hand-off', () {
    // `POST /auth/web-session/` went live 2026-08-03. Verified against
    // production the same day: 200 `{ok, url}` in ~100 ms, and an off-site or
    // protocol-relative `next` correctly refused with
    // `400 {ok:false, error:"Invalid 'next': must be a same-site relative
    // path."}`.
    //
    // Every case below is a way the call can go wrong. **None of them may
    // break the tap** — the plain price list always opens. What varies is
    // whether the user is told why they'll be asked to sign in, because
    // silently dropping a signed-in user on a login form is the failure that
    // reads as "the app logged me out".
    Dio dioReturning(int status, [Object? body]) =>
        Dio()..httpClientAdapter = _StubAdapter(status, body);

    test('200 with a same-host URL → signed-in hand-off, nothing to say',
        () async {
      final t = await WebCheckout.resolveTarget(
        dioReturning(200, {
          'ok': true,
          'url': 'https://saqqaar.com/auth/handoff/?t=abc123',
        }),
        'pro',
      );
      expect(t.uri.toString(), 'https://saqqaar.com/auth/handoff/?t=abc123');
      expect(t.signedIn, isTrue);
      expect(t.failure, isNull);
      expect(t.blocking, isFalse);
    });

    test('404 → plain page, silent (nothing the user can act on)', () async {
      final t = await WebCheckout.resolveTarget(dioReturning(404), 'pro');
      expect(t.uri.toString(), endsWith('/pricing/?plan=pro'));
      expect(t.signedIn, isFalse);
      expect(t.failure, isNull, reason: 'a missing feature is not an error');
      expect(t.blocking, isFalse);
    });

    test("Django's HTML 404 body — a rollback would look like this", () async {
      // An unrouted Django path answers `text/html`, and
      // `post<Map<String, dynamic>>` cannot hold a String, so this *throws*
      // inside Dio rather than returning a status. Different code path, same
      // required outcome.
      final dio = Dio()
        ..httpClientAdapter = _StubAdapter(
          404,
          '<!doctype html><html><title>Page not found</title></html>',
          'text/html; charset=utf-8',
        );
      final t = await WebCheckout.resolveTarget(dio, 'pro');
      expect(t.uri.toString(), endsWith('/pricing/?plan=pro'));
      expect(t.blocking, isFalse);
      // Dio wraps the cast failure as a ParseFailure, which we deliberately
      // treat as "no hand-off offered" rather than surfacing — an unreadable
      // body is not something the user can act on, and the page still opens.
      expect(t.failure, isNull);
    });

    test('401 → do not open a browser, say the session ended', () async {
      // Opening mid-way just adds a second sign-in screen to the one the app
      // is about to show anyway.
      final t = await WebCheckout.resolveTarget(
        dioReturning(401, {'ok': false, 'error': 'Not authenticated.'}),
        'pro',
      );
      expect(t.blocking, isTrue);
      expect(t.failure, isA<UnauthorizedFailure>());
    });

    test('400 (our bad next) → plain page, silent; it is our bug', () async {
      // The server refusing our `next` is a client defect. Putting a
      // validation error in front of someone who tapped Subscribe tells them
      // nothing useful — it goes to the log instead.
      final t = await WebCheckout.resolveTarget(
        dioReturning(400, {
          'ok': false,
          'error': "Invalid 'next': must be a same-site relative path.",
        }),
        'pro',
      );
      expect(t.uri.toString(), endsWith('/pricing/?plan=pro'));
      expect(t.failure, isNull);
      expect(t.blocking, isFalse);
    });

    test('500 → open the plain page AND report it', () async {
      final t = await WebCheckout.resolveTarget(dioReturning(500), 'pro');
      expect(t.uri.toString(), endsWith('/pricing/?plan=pro'));
      expect(t.failure, isA<ServerFailure>());
      expect(t.blocking, isFalse, reason: 'the price list still works');
    });

    test('200 with an OFF-HOST url is refused and reported', () async {
      // The hand-off URL carries a live login token. A wrong or tampered
      // `url` would deliver the user's session to whoever it points at.
      final t = await WebCheckout.resolveTarget(
        dioReturning(200, {'ok': true, 'url': 'https://evil.example/steal'}),
        'pro',
      );
      expect(t.uri.host, 'saqqaar.com');
      expect(t.signedIn, isFalse);
      expect(t.failure, isA<ServerFailure>());
    });

    test('200 over plain http is refused', () async {
      final t = await WebCheckout.resolveTarget(
        dioReturning(200, {'ok': true, 'url': 'http://saqqaar.com/auth/h/?t=x'}),
        'pro',
      );
      expect(t.uri.toString(), endsWith('/pricing/?plan=pro'));
      expect(t.signedIn, isFalse);
    });

    test('200 with a missing or empty url → plain page, reported', () async {
      for (final body in [
        {'ok': true},
        {'ok': true, 'url': ''},
      ]) {
        final t = await WebCheckout.resolveTarget(dioReturning(200, body), '');
        expect(t.uri.toString(), endsWith('/pricing/'));
        expect(t.signedIn, isFalse);
        expect(t.failure, isA<ServerFailure>());
      }
    });

    test('offline → do not open an empty browser tab', () async {
      final dio = Dio()..httpClientAdapter = _ThrowingAdapter();
      final t = await WebCheckout.resolveTarget(dio, 'max-20x');
      expect(t.uri.toString(), endsWith('/pricing/?plan=max-20x'));
      expect(t.blocking, isTrue);
      expect(t.failure, isA<NetworkFailure>());
    });

    test('the request carries the relative next path, not an absolute URL',
        () async {
      // Production rejects an absolute or protocol-relative `next` with a 400,
      // so this is the shape that has to stay right.
      final adapter = _StubAdapter(200, {
        'ok': true,
        'url': 'https://saqqaar.com/auth/handoff/?t=x',
      });
      await WebCheckout.resolveTarget(Dio()..httpClientAdapter = adapter, 'pro');
      expect(adapter.sentBody, {'next': '/pricing/?plan=pro'});
    });
  });

  group('the web hand-off', () {
    // The URL shape is a contract with the web team — if `?plan=` is renamed
    // or the trailing slash dropped, the site loses the preselection and the
    // user lands on a generic page after tapping a specific tier.
    test('carries the server plan slug, untranslated', () {
      expect(debugPricingUrl('pro'), endsWith('/pricing/?plan=pro'));
      expect(debugPricingUrl('max-20x'), endsWith('/pricing/?plan=max-20x'));
    });

    test('falls back to the plain pricing page with no slug', () {
      expect(debugPricingUrl(''), endsWith('/pricing/'));
      expect(debugPricingUrl(''), isNot(contains('?')));
    });

    test('points at the configured host, not a hardcoded one', () {
      // Built from ApiEndpoints.baseUrl so a staging build sends a tester to
      // staging rather than to production's live payment page.
      expect(WebCheckout.pricingUrl.scheme, 'https');
      expect(WebCheckout.pricingUrl.path, '/pricing/');
    });
  });

  group('the store-policy switch works in both positions', () {
    testWidgets('off: an exhausted quota states the limit and stops there',
        (tester) async {
      debugShowPaidUpsell = false;
      await tester.pumpWidget(_harness(ChatPlanBanner(
        plan: null,
        exceededWindow: QuotaWindow.day,
        onUpgrade: () => fail('no purchase path when the switch is off'),
      )));

      // Asserted against the exact string: the two bodies differ only in a
      // trailing clause, so a loose "usage limit" needle matches both and
      // would pass whichever one rendered.
      expect(
        find.text(
          "You've reached your daily usage limit. "
          'It resets when the window rolls over.',
        ),
        findsOneWidget,
      );
      expect(find.text('See plans'), findsNothing);
      expect(find.byType(GhostButton), findsNothing);
    });

    testWidgets('on: the same banner offers the route to the catalogue',
        (tester) async {
      debugShowPaidUpsell = true;
      await tester.pumpWidget(_harness(ChatPlanBanner(
        plan: null,
        exceededWindow: QuotaWindow.day,
        onUpgrade: () {},
      )));

      expect(find.textContaining('upgrade your plan'), findsOneWidget);
      expect(find.text('See plans'), findsOneWidget);
    });

    testWidgets('off, in Arabic too', (tester) async {
      debugShowPaidUpsell = false;
      await tester.pumpWidget(_harness(
        ChatPlanBanner(
          plan: null,
          exceededWindow: QuotaWindow.month,
          onUpgrade: () => fail('no purchase path when the switch is off'),
        ),
        locale: 'ar',
      ));

      expect(
        find.text('لقد بلغت حدّ الاستخدام الشهري. ستُعاد التهيئة عند انتهاء '
            'الفترة.'),
        findsOneWidget,
      );
      // 'أو رقِّ خطتك' is the upsell clause, 'عرض الباقات' the CTA label.
      expect(find.textContaining('رقِّ خطتك'), findsNothing);
      expect(find.text('عرض الباقات'), findsNothing);
      expect(find.byType(GhostButton), findsNothing);
    });
  });
}
