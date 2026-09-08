// Every API client, against the four responses a server actually sends when
// something is wrong.
//
// The pieces of the error path were each covered in isolation —
// `error_envelope_test` proves `ErrorInterceptor` catches `200 {ok: false}`,
// `api_error_localization_test` proves `ApiErrorMapper` localizes an
// `ApiException`. Neither proves that *a given client* routes its failure
// into that machinery: a method that parses its body before the interceptor's
// rejection surfaces, or that catches broadly and returns a default, drops
// out of the localized path without either test noticing.
//
// That gap is the difference between the user reading "انتهت مهلة الاتصال"
// and the user reading an empty list rendered as "you have no projects yet",
// which is the same screen the app shows when the request genuinely
// succeeded. A false success hides the retry.
//
// So this asserts the end-to-end property, per client, for the read path each
// screen's first paint depends on:
//
//   whatever the server does, the user gets a localized sentence
//
// Concretely, for each hostile response the client must throw something
// `ApiErrorMapper` classifies into the *expected* `AppFailure`, and that
// failure must render non-empty Arabic copy that is not a Dart type name, a
// traceback or a bare status code.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:saqqar_app/core/error/app_failure.dart';
import 'package:saqqar_app/core/i18n/app_strings.dart';
import 'package:saqqar_app/core/i18n/remote_i18n_api.dart';
import 'package:saqqar_app/core/network/api_error_mapper.dart';
import 'package:saqqar_app/core/network/error_interceptor.dart';

import 'package:saqqar_app/features/app_update/data/app_update_api.dart';
import 'package:saqqar_app/features/apps/data/apps_api.dart';
import 'package:saqqar_app/features/auth/data/auth_api.dart';
import 'package:saqqar_app/features/billing/data/billing_history_api.dart';
import 'package:saqqar_app/features/billing/data/plans_api.dart';
import 'package:saqqar_app/features/billing/data/usage_api.dart';
import 'package:saqqar_app/features/chat/data/saqqar_tools_api.dart';
import 'package:saqqar_app/features/chat/data/transcribe_api.dart';
import 'package:saqqar_app/features/conversations/data/conversations_api.dart';
import 'package:saqqar_app/features/conversations/data/conversations_repository.dart';
import 'package:saqqar_app/features/support/data/voice_support_api.dart';
import 'package:saqqar_app/features/support/data/voice_support_models.dart';
import 'package:saqqar_app/features/data_api/data/odoo_data_api.dart';
import 'package:saqqar_app/features/inbox/data/approvals_api.dart';
import 'package:saqqar_app/features/inbox/data/artifacts_api.dart';
import 'package:saqqar_app/features/meetings/data/meetings_api.dart';
import 'package:saqqar_app/features/push/data/devices_api.dart';
import 'package:saqqar_app/features/share/data/shares_api.dart';
import 'package:saqqar_app/features/trial/data/trial_api.dart';
import 'package:saqqar_app/features/trial/data/trial_models.dart';
import 'package:saqqar_app/features/vault/data/credential_models.dart';
import 'package:saqqar_app/features/vault/data/credentials_api.dart';
import 'package:saqqar_app/features/vault/data/projects_api.dart';

// ── Harness ──────────────────────────────────────────────────────────────

/// Serves one canned response to every request, exactly as the production
/// stack would see it.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.statusCode, this.body, this.contentType);

  final int statusCode;
  final Object? body;
  final String contentType;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      ResponseBody.fromString(
        body is String ? body as String : jsonEncode(body),
        statusCode,
        headers: {
          Headers.contentTypeHeader: [contentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

/// A Dio wired the way `DioClient` wires it — `ErrorInterceptor` last, so the
/// clients under test see the same normalized `ApiException` they see in the
/// app. Without this the test would be exercising raw Dio behaviour and would
/// pass while production failed.
Dio _dio(_Case c) => Dio(BaseOptions(baseUrl: 'http://x/'))
  ..httpClientAdapter = _StubAdapter(c.status, c.body, c.contentType)
  ..interceptors.add(ErrorInterceptor());

/// The hostile responses, and what each must classify as.
typedef _Case = ({
  String name,
  int status,
  Object? body,
  String contentType,
  Type failure,
});

const _json = Headers.jsonContentType;
const _html = 'text/html';

const _cases = <_Case>[
  // The envelope: HTTP 200, `ok: false`. Dio calls this a success, so a
  // client that reads its body without the interceptor turns it into an
  // empty list — the "you have nothing yet" false success.
  (
    name: '200 + {ok:false}',
    status: 200,
    body: {'ok': false, 'error': 'Environment is not reachable'},
    contentType: _json,
    failure: UnknownFailure,
  ),
  (
    name: '401',
    status: 401,
    body: {'detail': 'Invalid token'},
    contentType: _json,
    failure: UnauthorizedFailure,
  ),
  (
    name: '500',
    status: 500,
    body: {'error': 'boom'},
    contentType: _json,
    failure: ServerFailure,
  ),
  // nginx in front of a dead app server. Served as `text/html`, which is what
  // nginx actually sends — so Dio keeps the 502 and this stays a
  // ServerFailure. The body carries no usable text, which is what forces the
  // localized fallback rather than an HTML dump on screen.
  (
    name: '502 nginx HTML',
    status: 502,
    body: '<html><head><title>502 Bad Gateway</title></head></html>',
    contentType: _html,
    failure: ServerFailure,
  ),
  // The nastier variant: a body that *claims* to be JSON and isn't — a proxy
  // truncating the response, gzip cut short, or a Django debug page under the
  // wrong content type. Dio reports `unknown` with a FormatException and
  // throws the status away, so before `ApiExceptionKind.parse` existed this
  // was indistinguishable from "no internet" and the user was told to check a
  // connection that was working fine.
  (
    name: 'truncated JSON body',
    status: 200,
    body: '{"projects": [{"id": "p1", "na',
    contentType: _json,
    failure: ParseFailure,
  ),
  // A 200 that carries NO BODY. The subtlest of the five, and the one that
  // was actually shipping: a proxy that strips the payload, a gateway that
  // answers its own health check instead of proxying the route, a CDN
  // serving a cached 200 with `Content-Length: 0`.
  //
  // Dio reports complete success and hands the client `data == null`, so
  // this never reaches the interceptor — the client itself decides what an
  // absent body means, and twelve of them answered it with `?? const {}`.
  // That default is not a null-safety formality; it manufactures a body the
  // server never sent, and every field then reads its own null-tolerant
  // default. What came out the other side was a complete, plausible,
  // entirely invented answer:
  //
  //   * `/usage/`   → the free plan, not exempt, every feature off, three
  //                   usage windows of 0/0 — rendered on a paying account.
  //   * `/plans/`   → an empty catalogue, i.e. "nothing is for sale".
  //   * `share/`    → an empty share link, handed to the OS share sheet.
  //   * `stop/`     → `is_running: false`, i.e. "your run was cancelled".
  //   * `account/delete/` → `ok: true`, i.e. "your account is gone".
  //
  // None of them raised anything, so none of them offered a retry. That is
  // strictly worse than an error screen: the user cannot tell that the app
  // failed to ask, and acts on a number nobody sent.
  //
  // A body that IS present but empty (`{}`) is deliberately NOT this case —
  // each endpoint keeps its own lenient read of that, because the server
  // really does answer `{}` on some deploys.
  (
    name: _bodilessOk,
    status: 200,
    body: '',
    contentType: _json,
    failure: ParseFailure,
  ),
];

/// Named so `contractForAcknowledgement` can exclude exactly this case by
/// identity rather than by re-typing the string.
const _bodilessOk = '200 with no body';

/// Copy that must never reach a user, whatever the server sent.
final _leaks = <RegExp>[
  RegExp(r'DioException|TypeError|NoSuchMethod|_TypeError|FormatException'),
  RegExp(r'<html|<head|Traceback|IntegrityError|psycopg|django\.'),
  RegExp(r'^\s*$'),
];

void main() {
  final ar = AppStrings(const Locale('ar'));
  final en = AppStrings(const Locale('en'));

  /// Runs [call] against every hostile response and asserts the whole
  /// contract: right classification, localized copy, nothing leaked.
  /// [overrides] lets one client classify a shared case differently, keyed by
  /// case name.
  ///
  /// Exactly one client family needs it: the six Odoo reads reach through
  /// Saqqar into the customer's own database, so a gateway 502 there means
  /// THAT database is down, not that Saqqar is — and the message has to say
  /// so. Everything else still gets the shared expectation, so the override
  /// is a documented exception rather than a hole in the contract.
  void contractFor(
    String client,
    Future<void> Function(Dio dio) call, {
    Map<String, Type> overrides = const {},
  }) {
    group(client, () {
      for (final c in _cases) {
        final expected = overrides[c.name] ?? c.failure;
        test('${c.name} → $expected with localized copy', () async {
          Object? thrown;
          try {
            await call(_dio(c));
          } catch (e) {
            thrown = e;
          }

          expect(
            thrown,
            isNotNull,
            reason: '$client swallowed ${c.name} and returned normally. A '
                'client that defaults on failure renders an empty screen that '
                'is indistinguishable from a real empty account — the user '
                'never learns there is anything to retry.',
          );

          final failure = ApiErrorMapper.toFailure(thrown);
          expect(
            failure.runtimeType,
            expected,
            reason: '$client · ${c.name} classified as '
                '${failure.runtimeType}. The message the user reads is chosen '
                'by this type, so a misclassification is wrong advice: '
                '"try again later" for a 401 sends them into a loop that '
                'cannot succeed.',
          );

          for (final tr in [ar, en]) {
            final msg = ApiErrorMapper.messageForLocale(tr, thrown);
            expect(msg.trim(), isNotEmpty,
                reason: '$client · ${c.name} produced no copy at all');
            for (final leak in _leaks) {
              expect(
                leak.hasMatch(msg),
                isFalse,
                reason: '$client · ${c.name} leaked developer text to the '
                    'user: "$msg"',
              );
            }
          }
        });
      }
    });
  }

  /// Same contract, minus the bodiless-200 case, for endpoints that read no
  /// body at all.
  ///
  /// `signupStart`, `revokeShare`, `deleteEnvironment` and friends return
  /// `void`: the 2xx **is** the answer. A 200 with an empty body is a
  /// perfectly good "done" for them, so asserting `ParseFailure` there would
  /// pin the opposite of the contract — that a successful delete must fail.
  ///
  /// Everything else still applies, and is the part that matters: a 500 or a
  /// dropped connection on "send me a code" must reach the user, or they sit
  /// on a code-entry screen waiting for a message nobody sent.
  void contractForAcknowledgement(
    String client,
    Future<void> Function(Dio dio) call,
  ) {
    group(client, () {
      for (final c in _cases.where((c) => c.name != _bodilessOk)) {
        test('${c.name} → ${c.failure} with localized copy', () async {
          Object? thrown;
          try {
            await call(_dio(c));
          } catch (e) {
            thrown = e;
          }

          expect(
            thrown,
            isNotNull,
            reason: '$client swallowed ${c.name} and returned normally — the '
                'caller reads that as "done".',
          );
          expect(ApiErrorMapper.toFailure(thrown).runtimeType, c.failure);
          for (final tr in [ar, en]) {
            final msg = ApiErrorMapper.messageForLocale(tr, thrown);
            expect(msg.trim(), isNotEmpty);
            for (final leak in _leaks) {
              expect(leak.hasMatch(msg), isFalse,
                  reason: '$client · ${c.name} leaked developer text: "$msg"');
            }
          }
        });
      }
    });
  }

  // ── The read path behind each screen's first paint ─────────────────────

  contractFor('AppsApi.list', (d) => AppsApi(d).list());
  contractFor('BillingHistoryApi.fetch', (d) => BillingHistoryApi(d).fetch());
  contractFor('PlansApi.list', (d) => PlansApi(d).list());
  contractFor('UsageApi.fetch', (d) => UsageApi(d).fetch());
  contractFor('ProjectsApi.list', (d) => ProjectsApi(d).list());
  contractFor('ProjectsApi.get', (d) => ProjectsApi(d).get('p1'));
  contractFor(
    'ProjectsApi.defaultProject',
    (d) => ProjectsApi(d).defaultProject(),
  );
  contractFor('CredentialsApi.getSchemas', (d) => CredentialsApi(d).getSchemas());
  contractFor('CredentialsApi.list', (d) => CredentialsApi(d).list());
  contractFor('CredentialsApi.get', (d) => CredentialsApi(d).get('c1'));
  contractFor('ApprovalsApi.list', (d) => ApprovalsApi(d).list());
  contractFor('ArtifactsApi.list', (d) => ArtifactsApi(d).list());
  contractFor('ArtifactsApi.detail', (d) => ArtifactsApi(d).detail('a1'));
  contractFor('DevicesApi.list', (d) => DevicesApi(d).list());
  contractFor('TrialApi.status', (d) => TrialApi(d).status());
  contractFor('SharesApi.get', (d) => SharesApi(d).get('tok'));
  contractFor('AuthApi.me', (d) => AuthApi(d).me());
  contractFor(
    'ConversationsApi.list',
    (d) => ConversationsApi(d).list(),
  );
  contractFor(
    'ConversationsApi.getSnapshot',
    (d) => ConversationsApi(d).getSnapshot('c1'),
  );

  // The two raw-JSON clients. No UI reads them yet, which is exactly why
  // they are worth pinning now: a future meetings/reports screen inherits
  // whatever contract this client already has, and an empty map is
  // indistinguishable from a real "no rows" answer once it is three layers
  // deep in a chart.
  contractFor(
    'MeetingsApi.transcript',
    (d) => MeetingsApi(d).transcript('m1'),
  );
  contractFor('MeetingsApi.start', (d) => MeetingsApi(d).start(const {}));
  contractFor(
    'OdooDataApi.search',
    (d) => OdooDataApi(d).search('e1', const {}),
    overrides: const {'502 nginx HTML': OdooUnreachableFailure},
  );
  contractFor(
    'OdooDataApi.count',
    (d) => OdooDataApi(d).count('e1', const {}),
    overrides: const {'502 nginx HTML': OdooUnreachableFailure},
  );
  contractFor(
    'OdooDataApi.reportEntities',
    (d) => OdooDataApi(d).reportEntities(const {}),
  );

  // ── Write paths ────────────────────────────────────────────────────────
  //
  // A failed write is the case where a wrong message costs the most: the user
  // is deciding whether their change was saved, and an empty-list-style
  // default would tell them it was.

  contractFor('ConversationsApi.create', (d) => ConversationsApi(d).create());
  contractFor(
    'ProjectsApi.create',
    (d) => ProjectsApi(d).create(name: 'Acme'),
  );
  contractFor('AppsApi.launch', (d) => AppsApi(d).launch('zatca'));
  contractFor(
    'ConversationsApi.patch',
    (d) => ConversationsApi(d).patch(id: 'c1', title: 'x'),
  );
  contractFor(
    'ConversationsApi.sendMessage',
    (d) => ConversationsApi(d).sendMessage(conversationId: 'c1', content: 'hi'),
  );
  contractFor(
    'ConversationsApi.dismissPendingAction',
    (d) => ConversationsApi(d).dismissPendingAction(conversationId: 'c1'),
  );
  contractFor(
    'ApprovalsApi.decide',
    (d) => ApprovalsApi(d).decide(id: 'a1', approved: true),
  );
  contractFor(
    'DevicesApi.register',
    (d) => DevicesApi(d).register(
      platform: DevicePlatform.android,
      token: 'tok',
    ),
  );
  contractFor(
    'TrialApi.request',
    (d) => TrialApi(d).request(const TrialRequest(companyName: 'Acme')),
  );
  contractFor(
    'CredentialsApi.delete',
    (d) => CredentialsApi(d).delete('c1'),
  );

  // `CredentialsApi.testConnection` is deliberately absent from this sweep.
  // It is the one client that must NOT throw: it backs the editor's "Test
  // connection" button, whose entire purpose is to report a failed
  // connection inline on a badge. It catches everything and returns
  // `CredentialTestResult.failure(...)`, and the badge renders localized
  // copy from that. Adding it here would assert the opposite of its
  // contract. `credential_test_badge_test.dart` covers that path instead.

  // The three that decide whether a person is signed in, signed out, or
  // gone. `deleteAccount` is the sharpest: it used to answer `ok: true` —
  // "your account and everything in it is deleted" — for a response that
  // contained nothing at all.
  contractFor(
    'AuthApi.login',
    (d) => AuthApi(d).login(email: 'a@b.co', password: 'pw'),
  );
  contractFor(
    'AuthApi.register',
    (d) => AuthApi(d).register(email: 'a@b.co', password: 'pw'),
  );
  contractFor('AuthApi.deleteAccount', (d) => AuthApi(d).deleteAccount());
  contractFor(
    'AuthApi.changePassword',
    (d) => AuthApi(d).changePassword(oldPassword: 'a', newPassword: 'b'),
  );
  contractFor(
    'AuthApi.signupVerify',
    (d) => AuthApi(d).signupVerify(email: 'a@b.co', code: '123456'),
  );
  contractFor(
    'AuthApi.signupComplete',
    (d) => AuthApi(d).signupComplete(email: 'a@b.co', password: 'pw'),
  );
  contractFor(
    'AuthApi.loginEmailVerify',
    (d) => AuthApi(d).loginEmailVerify(email: 'a@b.co', code: '123456'),
  );
  contractFor(
    'AuthApi.passwordResetVerify',
    (d) => AuthApi(d).passwordResetVerify(email: 'a@b.co', code: '123456'),
  );

  // Sharing. A share link is the one value in the app that leaves the
  // device and cannot be recalled, so a blank one is not recoverable by a
  // retry the way a blank screen is.
  contractFor('ConversationsApi.share', (d) => ConversationsApi(d).share('c1'));
  contractFor('ConversationsApi.stop', (d) => ConversationsApi(d).stop('c1'));

  // ── The §6 / §8 clients ────────────────────────────────────────────────
  //
  // Added 2026-08-09 after an audit diffed every `*Api` class in `lib`
  // against the list above and found these three had never been here. They
  // are the newest clients in the app, which is exactly why: a contract test
  // that has to be remembered is one that lags the code it protects.
  //
  // Each fails in a way the user cannot see unaided, so a silent failure is
  // the expensive one:
  //
  //   * The three scans return a body the app deliberately ignores — the
  //     report arrives later as a posted message. A client that swallowed a
  //     failure would leave the working indicator spinning against a scan
  //     that never ran, with no error and nothing to retry.
  //   * `transcribe` is the only client that uploads a file. The user has
  //     already spoken; losing that recording to a silent failure means
  //     asking them to say it again with no explanation.
  //   * `createTicket` writes a real `helpdesk.ticket` into a live Odoo. A
  //     swallowed failure reports a ticket that does not exist, and the user
  //     waits on support that was never contacted.
  contractFor(
    'SaqqarToolsApi.runHealthRadar',
    (d) => SaqqarToolsApi(d).runHealthRadar(conversationId: 'c1', lang: 'ar'),
  );
  contractFor(
    'SaqqarToolsApi.runBusinessPulse',
    (d) => SaqqarToolsApi(d).runBusinessPulse(conversationId: 'c1', lang: 'ar'),
  );
  contractFor(
    'SaqqarToolsApi.runWhatIfIntro',
    (d) => SaqqarToolsApi(d).runWhatIfIntro(conversationId: 'c1', lang: 'ar'),
  );
  contractFor(
    'VoiceSupportApi.draft',
    (d) => VoiceSupportApi(d).draft(problem: 'الطابعة لا تعمل', lang: 'ar'),
  );
  contractFor(
    'VoiceSupportApi.createTicket',
    (d) => VoiceSupportApi(d).createTicket(
      draft: VoiceSupportDraft.fromJson(const {
        'title': 'Printer',
        'priority': '2',
        'customer_reply': 'جرّب تعيد تشغيل الطابعة.',
      }),
      transcript: 'الطابعة لا تعمل',
    ),
  );

  // ── The rest of every client ───────────────────────────────────────────
  //
  // Added 2026-08-12. An audit listed every public method on every `*Api`
  // class and diffed it against the entries above: 50 of 89 were covered, and
  // the 39 that were not were not the obscure ones. They included the whole
  // OTP entry path (`signupStart`, `loginEmailStart`, `passwordResetStart`),
  // every credential write, and every project/environment mutation — i.e. the
  // calls behind "send me a code", "save this password" and "delete this
  // environment".
  //
  // Coverage that stops at the methods someone remembered is coverage that
  // ages badly. This block closes the list so the next audit finds nothing.

  // Profile + session.
  contractFor(
    'AuthApi.updateProfile',
    (d) => AuthApi(d).updateProfile(firstName: 'Digital', lastName: 'Harbor'),
  );
  contractFor(
    'AuthApi.loginWithGoogle',
    (d) => AuthApi(d).loginWithGoogle(idToken: 'tok'),
  );
  contractFor(
    'AuthApi.loginWithApple',
    (d) => AuthApi(d).loginWithApple(idToken: 'tok'),
  );
  contractFor(
    'AuthApi.passwordResetComplete',
    (d) => AuthApi(d).passwordResetComplete(resetToken: 'rt', password: 'pw'),
  );

  // "We sent you a code." Every one of these returns `void`, so the 2xx is
  // the whole answer — but a failure that does not reach the user leaves them
  // staring at a code-entry screen for a message that was never sent.
  contractForAcknowledgement(
    'AuthApi.signupStart',
    (d) => AuthApi(d).signupStart(email: 'a@b.co'),
  );
  contractForAcknowledgement(
    'AuthApi.signupResend',
    (d) => AuthApi(d).signupResend(email: 'a@b.co'),
  );
  contractForAcknowledgement(
    'AuthApi.loginEmailStart',
    (d) => AuthApi(d).loginEmailStart(email: 'a@b.co'),
  );
  contractForAcknowledgement(
    'AuthApi.loginEmailResend',
    (d) => AuthApi(d).loginEmailResend(email: 'a@b.co'),
  );
  contractForAcknowledgement(
    'AuthApi.passwordResetStart',
    (d) => AuthApi(d).passwordResetStart(email: 'a@b.co'),
  );
  contractForAcknowledgement(
    'AuthApi.passwordResetResend',
    (d) => AuthApi(d).passwordResetResend(email: 'a@b.co'),
  );
  // `logout` reads `revoked` off the body and answers `false` when there
  // isn't one, which is the honest reading of "we cannot tell" — so it is an
  // acknowledgement, not a body-reader. Sign-out proceeds locally either way.
  contractForAcknowledgement('AuthApi.logout', (d) => AuthApi(d).logout());

  // Conversations: the reads and writes not already listed.
  // The transcript read, checked at the REPOSITORY rather than at the client.
  //
  // `ConversationsApi.fetchSnapshotBody` asks for `ResponseType.plain` so a
  // long transcript can be decoded off the UI isolate. That is deliberate,
  // and it costs it the central guard: `ErrorInterceptor` only recognises the
  // `{"ok": false}` envelope once Dio has decoded a Map, so on this one call
  // it sees a String and waves the failure through. The client is a faithful
  // pass-through of whatever arrived — there is nothing for it to classify.
  //
  // `getSnapshotOffIsolate` is where the body becomes a map, so it is where
  // the envelope is caught, and it is the seam every chat actually calls.
  // Running the contract here rather than one layer down is the difference
  // between testing the transport and testing what the user gets.
  contractFor(
    'ConversationsRepository.getSnapshotOffIsolate',
    (d) => ConversationsRepository(ConversationsApi(d))
        .getSnapshotOffIsolate('c1'),
  );
  contractFor(
    'ConversationsApi.getAttachmentStatus',
    (d) => ConversationsApi(d)
        .getAttachmentStatus(conversationId: 'c1', attachmentId: 'at1'),
  );
  contractFor(
    'ConversationsApi.setActiveCredential',
    (d) => ConversationsApi(d).setActiveCredential(id: 'c1', name: 'odoo'),
  );
  contractForAcknowledgement(
    'ConversationsApi.delete',
    (d) => ConversationsApi(d).delete('c1'),
  );
  // Revoking a share is the one write whose silent failure leaves a LIVE
  // public link the user believes they have killed.
  contractForAcknowledgement(
    'ConversationsApi.revokeShare',
    (d) => ConversationsApi(d).revokeShare('c1'),
  );

  // Credentials. These carry the user's live Odoo passwords; a save that
  // failed silently is a password the user believes is stored.
  contractFor(
    'CredentialsApi.save',
    (d) => CredentialsApi(d).save(
      name: 'odoo',
      kind: CredentialKind.xmlrpc,
      payload: const {'url': 'https://x.odoo.com'},
    ),
  );
  contractFor(
    'CredentialsApi.update',
    (d) => CredentialsApi(d).update(name: 'odoo', label: 'Production'),
  );
  contractFor(
    'CredentialsApi.listDatabases',
    (d) => CredentialsApi(d).listDatabases('https://x.odoo.com'),
  );

  // Projects and environments — the Vault's whole write surface.
  contractFor(
    'ProjectsApi.rename',
    (d) => ProjectsApi(d).rename(id: 'p1', name: 'Acme'),
  );
  contractFor(
    'ProjectsApi.createEnvironment',
    (d) => ProjectsApi(d).createEnvironment(projectId: 'p1', name: 'Prod'),
  );
  contractFor(
    'ProjectsApi.getEnvironment',
    (d) => ProjectsApi(d).getEnvironment('e1'),
  );
  contractFor(
    'ProjectsApi.updateEnvironment',
    (d) => ProjectsApi(d).updateEnvironment(id: 'e1', name: 'Prod'),
  );
  contractFor(
    'ProjectsApi.listEnvironmentCredentials',
    (d) => ProjectsApi(d).listEnvironmentCredentials('e1'),
  );
  contractFor(
    'ProjectsApi.getEnvironmentCredential',
    (d) => ProjectsApi(d).getEnvironmentCredential(
      environmentId: 'e1',
      kind: CredentialKind.xmlrpc,
    ),
  );
  contractFor(
    'ProjectsApi.upsertEnvironmentCredential',
    (d) => ProjectsApi(d).upsertEnvironmentCredential(
      environmentId: 'e1',
      kind: CredentialKind.xmlrpc,
      payload: const {'url': 'https://x.odoo.com'},
    ),
  );
  contractForAcknowledgement(
    'ProjectsApi.delete',
    (d) => ProjectsApi(d).delete('p1'),
  );
  contractForAcknowledgement(
    'ProjectsApi.deleteEnvironment',
    (d) => ProjectsApi(d).deleteEnvironment('e1'),
  );
  contractForAcknowledgement(
    'ProjectsApi.deleteEnvironmentCredential',
    (d) => ProjectsApi(d).deleteEnvironmentCredential(
      environmentId: 'e1',
      kind: CredentialKind.xmlrpc,
    ),
  );

  contractForAcknowledgement(
    'DevicesApi.revoke',
    (d) => DevicesApi(d).revoke('d1'),
  );

  // The raw-JSON data clients. No UI reads them yet — which is the reason to
  // pin them now rather than after a screen inherits whatever they do today.
  contractFor('MeetingsApi.stop', (d) => MeetingsApi(d).stop('m1'));
  contractFor('MeetingsApi.summarize', (d) => MeetingsApi(d).summarize('m1'));
  contractFor('MeetingsApi.chat', (d) => MeetingsApi(d).chat('m1', const {}));
  const gatewayMeansOdoo = {'502 nginx HTML': OdooUnreachableFailure};
  contractFor(
    'OdooDataApi.read',
    (d) => OdooDataApi(d).read('e1', const {}),
    overrides: gatewayMeansOdoo,
  );
  contractFor(
    'OdooDataApi.readGroup',
    (d) => OdooDataApi(d).readGroup('e1', const {}),
    overrides: gatewayMeansOdoo,
  );
  contractFor(
    'OdooDataApi.fields',
    (d) => OdooDataApi(d).fields('e1', const {}),
    overrides: gatewayMeansOdoo,
  );
  contractFor(
    'OdooDataApi.sql',
    (d) => OdooDataApi(d).sql('e1', const {}),
    overrides: gatewayMeansOdoo,
  );

  // The remote string bundle. It layers over the local table, so a failure
  // is survivable — but it must still be a failure the caller can see rather
  // than an empty map that reads as "the server has no strings".
  contractFor('RemoteI18nApi.getBundle', (d) => RemoteI18nApi(d).getBundle('ar'));

  // ── The one client that must do the OPPOSITE ────────────────────────────
  //
  // `AppUpdateApi` is the sole exception to everything above, and it was the
  // sole client with no entry in this file — which is the wrong way round.
  // A client that swallows every error looks exactly like the bug the rest of
  // this file exists to prevent, so it is the one most likely to be "fixed"
  // by someone reading it cold. Nothing was watching, so the fix would have
  // shipped.
  //
  // What it protects: `GET /api/v1/app/version/` **does not exist on the
  // backend yet**. Every call is a 404 today. The gate's whole contract is
  // that an unavailable version check is indistinguishable from "nothing to
  // report" — so if this client ever starts propagating, the app puts a
  // failure in front of a user who simply opened it, on every launch, until
  // the endpoint ships.
  //
  // Asserted as `isNull` rather than merely "did not throw": returning a
  // default `AppUpdateStatus` would also not throw, and would silently feed
  // the decision table a verdict the server never gave — the same invented
  // answer, one layer up.
  group('AppUpdateApi.fetch (must never surface a failure)', () {
    for (final c in _cases) {
      test('${c.name} → null, not an exception', () async {
        final status = await AppUpdateApi(_dio(c)).fetch(DevicePlatform.android);
        expect(
          status,
          isNull,
          reason: 'AppUpdateApi turned ${c.name} into $status. The version '
              'check is advisory: any answer it cannot read must degrade to '
              '"no opinion", because the alternative is blocking or nagging a '
              'user on the strength of a response the server never sent.',
        );
      });
    }
  });

  // The only client that uploads. `MultipartFile.fromFile` reads from disk, so
  // this needs a real file rather than the pure-in-memory stub the others use.
  // Worth the extra setup: the multipart path is the one place a client can
  // fail before the interceptor ever sees the response.
  // Unique per run: the name used to be fixed, so a leftover file from an
  // interrupted run — or a second copy of this suite — met a path that was
  // already there.
  final audio = File(
    '${Directory.systemTemp.path}/saqqar_hostile_probe_'
    '${DateTime.now().microsecondsSinceEpoch}.m4a',
  )..writeAsBytesSync(const [0, 0, 0, 32, 102, 116, 121, 112]);
  // `tearDownAll`, not `addTearDown`: the latter is only legal inside a
  // running test, and this file is one long declaration block.
  tearDownAll(() {
    // Best effort. `MultipartFile.fromFile` opens the file to stream it, and
    // on Windows a handle that has not closed yet makes the delete throw —
    // which failed the whole suite from the cleanup step of a run whose
    // every assertion had passed. A stray byte in the temp directory is not
    // worth a red release gate.
    try {
      if (audio.existsSync()) audio.deleteSync();
    } on FileSystemException catch (_) {
      // Left for the OS to reap.
    }
  });
  contractFor(
    'TranscribeApi.transcribe',
    (d) => TranscribeApi(d).transcribe(audio: audio, language: 'ar'),
  );
}
