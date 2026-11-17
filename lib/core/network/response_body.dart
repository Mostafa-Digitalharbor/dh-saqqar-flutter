import 'package:dio/dio.dart';

import 'api_exception.dart';

/// Reads a response body that the caller cannot do without.
///
/// Every client in this app used to write the same line:
///
/// ```dart
/// final data = res.data ?? const <String, dynamic>{};
/// ```
///
/// which is a **false success**. `res.data` is null when the transport
/// delivered no body at all — a 200 with `Content-Length: 0` from a proxy
/// that stripped the payload, a gateway that answered the health check
/// instead of the route, a `204` on an endpoint that is supposed to return
/// a record. In every one of those cases the server did not answer the
/// question, and `?? {}` answers it anyway, with a body it invented.
///
/// What the user sees is the worst possible outcome, because it is not an
/// error screen — it is a *plausible* one:
///
///  * `UsageApi.fetch` rendered a paying account as "Free plan · 0 of 0
///    used". Every number on that screen was manufactured here.
///  * `PlansApi.list` rendered the pricing screen with no plans, which
///    reads as "nothing is for sale".
///  * `ConversationsApi.share` handed back an empty share link.
///  * `ConversationsApi.stop` reported the run as stopped.
///  * `AuthApi.deleteAccount` reported the account as deleted.
///
/// None of them offered a retry, because from the app's point of view
/// nothing had gone wrong.
///
/// [requiredBody] makes the absent body what it actually is: a response the
/// app cannot read. It throws a `parse`-kind [ApiException], which
/// `ApiErrorMapper` classifies as `ParseFailure` → "unexpected response
/// from the server" — deliberately *not* the network copy, because the
/// connection demonstrably worked, and deliberately not "try again later",
/// because a truncating proxy will truncate the retry too.
///
/// Endpoints whose success shape genuinely carries no body (`DELETE`
/// returning 204, logout) must NOT use this — they return `void` and have
/// nothing to read.
extension RequiredResponseBody<T> on Response<T> {
  /// The decoded body, or a `parse` [ApiException] when the server sent none.
  T get requiredBody {
    final value = data;
    if (value == null) throw _missingBody(statusCode);
    return value;
  }
}

/// Same contract for a body that has already been read off a [Response] —
/// used where the client needs the raw `dynamic` before casting.
///
/// Kept beside [RequiredResponseBody] so both paths raise the identical
/// exception; a second spelling of "no body" would classify differently and
/// the user would get different copy for the same server behaviour.
T requireBody<T>(T? value, {int? statusCode}) {
  if (value == null) throw _missingBody(statusCode);
  return value;
}

/// The two request shapes used by clients that hand back raw decoded JSON
/// rather than a typed model.
///
/// `MeetingsApi` and `OdooDataApi` each carried a byte-identical private
/// `_post` helper, and both spelled the body read as `res.data ?? const {}`
/// — so both returned an empty map for a response that never arrived. Two
/// copies of a helper is also two places to fix it. One extension, used by
/// both, means the required-body rule cannot be half-applied.
extension JsonRequests on Dio {
  /// `POST` returning the decoded JSON object. Throws when no body arrives.
  Future<Map<String, dynamic>> postJson(String path, {Object? data}) async {
    final res = await post<Map<String, dynamic>>(path, data: data);
    return res.requiredBody;
  }

  /// `GET` returning the decoded JSON object. Throws when no body arrives.
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final res = await get<Map<String, dynamic>>(
      path,
      queryParameters: queryParameters,
    );
    return res.requiredBody;
  }
}

/// The message is EMPTY on purpose: the server said nothing, so there is
/// nothing of its to quote. `ApiErrorMapper` reads an empty message as
/// "fall back to localized copy", which is how this reaches an Arabic user
/// in Arabic. Seeding an English sentence here would pin it to English.
ApiException _missingBody(int? statusCode) => ApiException(
  kind: ApiExceptionKind.parse,
  message: '',
  statusCode: statusCode,
);
