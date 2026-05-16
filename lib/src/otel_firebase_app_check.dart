// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_firebase_app_check_suppression.dart';

const _tracerName = 'dartastic_otel_libs_firebase_app_check';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class FirebaseAppCheckResult {
  const FirebaseAppCheckResult({
    this.providerKind,
    this.tokenIssuedAtSec,
    this.tokenExpiresAtSec,
    this.tokenCached,
    this.tokenForceRefresh,
    this.debugTokenUsed,
    this.tokenAutoRefreshEnabled,
    this.tokenLength,
    this.errorCode,
    this.statusCode,
  });

  /// `play_integrity` (Android), `safety_net` (Android legacy),
  /// `device_check` (Apple), `app_attest` (Apple),
  /// `recaptcha_v3` / `recaptcha_enterprise` (Web), `debug`.
  final String? providerKind;

  final int? tokenIssuedAtSec;
  final int? tokenExpiresAtSec;

  /// Token returned from the in-memory cache (vs newly minted).
  final bool? tokenCached;

  /// `getToken(forceRefresh: true)` flag.
  final bool? tokenForceRefresh;

  /// Debug provider used (development / CI).
  final bool? debugTokenUsed;

  final bool? tokenAutoRefreshEnabled;

  final int? tokenLength;

  /// `appCheck/token-error`, `appCheck/throttled`,
  /// `appCheck/not-activated`, `appCheck/recaptcha-error`.
  final String? errorCode;

  final int? statusCode;
}

class FirebaseAppCheckCallResult<T> {
  const FirebaseAppCheckCallResult({required this.value, this.result});
  final T value;
  final FirebaseAppCheckResult? result;
}

/// Wraps a Firebase App Check call in a CLIENT span. [operation] is one of
/// `activate`, `getToken`, `getLimitedUseAppCheckToken`,
/// `setTokenAutoRefreshEnabled`, `onTokenChange`.
Future<T> tracedFirebaseAppCheck<T>({
  required String operation,
  required Future<FirebaseAppCheckCallResult<T>> Function() invoke,
}) async {
  if (firebaseAppCheckInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'firebase_app_check',
    'rpc.method': operation,
    'firebase_app_check.operation': operation,
  };

  final span = _tracer().startSpan(
    'firebase_app_check $operation',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final res = r.result!;
      final extras = <Attribute<Object>>[];
      if (res.providerKind != null) {
        extras.add(OTel.attributeString(
          'firebase_app_check.provider.kind',
          res.providerKind!,
        ));
      }
      if (res.tokenIssuedAtSec != null) {
        extras.add(OTel.attributeInt(
          'firebase_app_check.token.issued_at_sec',
          res.tokenIssuedAtSec!,
        ));
      }
      if (res.tokenExpiresAtSec != null) {
        extras.add(OTel.attributeInt(
          'firebase_app_check.token.expires_at_sec',
          res.tokenExpiresAtSec!,
        ));
      }
      if (res.tokenCached != null) {
        extras.add(OTel.attributeBool(
          'firebase_app_check.token.cached',
          res.tokenCached!,
        ));
      }
      if (res.tokenForceRefresh != null) {
        extras.add(OTel.attributeBool(
          'firebase_app_check.token.force_refresh',
          res.tokenForceRefresh!,
        ));
      }
      if (res.debugTokenUsed != null) {
        extras.add(OTel.attributeBool(
          'firebase_app_check.debug.token_used',
          res.debugTokenUsed!,
        ));
      }
      if (res.tokenAutoRefreshEnabled != null) {
        extras.add(OTel.attributeBool(
          'firebase_app_check.token.auto_refresh_enabled',
          res.tokenAutoRefreshEnabled!,
        ));
      }
      if (res.tokenLength != null) {
        extras.add(OTel.attributeInt(
          'firebase_app_check.token.length',
          res.tokenLength!,
        ));
      }
      if (res.errorCode != null) {
        extras.add(OTel.attributeString(
          'firebase_app_check.error.code',
          res.errorCode!,
        ));
        span.setStatus(
          SpanStatusCode.Error,
          'Firebase App Check ${res.errorCode}',
        );
      }
      if (res.statusCode != null) {
        extras.add(OTel.attributeInt(
          'http.response.status_code',
          res.statusCode!,
        ));
        if (res.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Firebase App Check HTTP ${res.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
