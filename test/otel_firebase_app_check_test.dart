// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_firebase_app_check/otel_firebase_app_check.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_firebase_app_check-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('getToken records provider + cache hit', () async {
    await tracedFirebaseAppCheck<String>(
      operation: 'getToken',
      invoke: () async => const FirebaseAppCheckCallResult(
        value: 'ok',
        result: FirebaseAppCheckResult(
          providerKind: 'play_integrity',
          tokenCached: true,
          tokenForceRefresh: false,
          tokenLength: 412,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('firebase_app_check getToken')!);
    expect(a['firebase_app_check.provider.kind'], 'play_integrity');
    expect(a['firebase_app_check.token.cached'], true);
  });

  test('throttled error sets span error', () async {
    await tracedFirebaseAppCheck<String>(
      operation: 'getToken',
      invoke: () async => const FirebaseAppCheckCallResult(
        value: 'ok',
        result: FirebaseAppCheckResult(errorCode: 'appCheck/throttled'),
      ),
    );
    expect(
      spans.findSpanByName('firebase_app_check getToken')!.status,
      SpanStatusCode.Error,
    );
  });

  test('suppression skips spans', () async {
    await runWithoutFirebaseAppCheckInstrumentationAsync(() async {
      await tracedFirebaseAppCheck<String>(
        operation: 'activate',
        invoke: () async => const FirebaseAppCheckCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('firebase_app_check '), isEmpty);
  });
}
