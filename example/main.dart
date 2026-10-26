// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_firebase_app_check/otel_firebase_app_check.dart';

/// Traces Firebase App Check calls with OpenTelemetry.
///
/// `otel_firebase_app_check` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Firebase App Check call in
/// [tracedFirebaseAppCheck]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'firebase-app-check-example');

  // Wraps a Firebase App Check call in a CLIENT span.
  final firebaseAppCheckId = await tracedFirebaseAppCheck<String>(
    operation: 'create',
    invoke: () async {
      // Make the Firebase App Check call here, then report what it returned.
      const id = 'firebase_app_check_8f3a2c';
      return const FirebaseAppCheckCallResult(
          value: id,
          result: FirebaseAppCheckResult(
              providerKind: 'play_integrity',
              tokenIssuedAtSec: 128,
              tokenExpiresAtSec: 128,
              tokenCached: true,
              tokenForceRefresh: true,
              debugTokenUsed: true,
              tokenAutoRefreshEnabled: true,
              tokenLength: 128,
              errorCode: 'appCheck/token-error',
              statusCode: 201));
    },
  );
  OTelLog.info('tracedFirebaseAppCheck create returned $firebaseAppCheckId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutFirebaseAppCheckInstrumentationAsync.
  await runWithoutFirebaseAppCheckInstrumentationAsync(
    () => tracedFirebaseAppCheck<String>(
      operation: 'create',
      invoke: () async {
        const id = 'firebase_app_check_8f3a2c';
        return const FirebaseAppCheckCallResult(
            value: id,
            result: FirebaseAppCheckResult(
                providerKind: 'play_integrity',
                tokenIssuedAtSec: 128,
                tokenExpiresAtSec: 128,
                tokenCached: true,
                tokenForceRefresh: true,
                debugTokenUsed: true,
                tokenAutoRefreshEnabled: true,
                tokenLength: 128,
                errorCode: 'appCheck/token-error',
                statusCode: 201));
      },
    ),
  );

  await OTel.shutdown();
}
