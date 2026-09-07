// ABOUTME: Tests for AnalyticsConsentCubit — the Settings analytics toggle.
// ABOUTME: Covers the stored-preference read, the write, and post-close safety.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/analytics_consent/analytics_consent_cubit.dart';
import 'package:openvine/blocs/analytics_consent/analytics_consent_state.dart';
import 'package:openvine/services/analytics_service.dart';

class _MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  group(AnalyticsConsentCubit, () {
    late _MockAnalyticsService service;
    late bool storedPreference;
    late bool initialized;

    setUp(() {
      service = _MockAnalyticsService();
      // The service reports its pre-load default until initialize() has read
      // SharedPreferences, exactly as the real one does.
      storedPreference = false;
      initialized = false;
      when(
        () => service.analyticsEnabled,
      ).thenAnswer((_) => !initialized || storedPreference);
      when(service.initialize).thenAnswer((_) async {
        initialized = true;
      });
      when(() => service.setAnalyticsEnabled(any())).thenAnswer((
        invocation,
      ) async {
        storedPreference = invocation.positionalArguments.first as bool;
        return true;
      });
    });

    group('load', () {
      test('starts loading with the switch value unknown', () {
        final cubit = AnalyticsConsentCubit(service: service);
        addTearDown(cubit.close);

        expect(cubit.state.status, AnalyticsConsentStatus.loading);
      });

      test('waits for the stored preference before reporting ready', () async {
        final cubit = AnalyticsConsentCubit(service: service);
        addTearDown(cubit.close);

        await cubit.load();

        // Reading analyticsEnabled without awaiting initialize() would report
        // the pre-load default and render a stored opt-out as consent.
        expect(cubit.state.status, AnalyticsConsentStatus.ready);
        expect(cubit.state.isEnabled, isFalse);
        verify(service.initialize).called(1);
      });

      test('reports a stored opt-in as enabled', () async {
        storedPreference = true;
        final cubit = AnalyticsConsentCubit(service: service);
        addTearDown(cubit.close);

        await cubit.load();

        expect(cubit.state.isEnabled, isTrue);
      });

      test('drops the result when the cubit closed while loading', () async {
        final cubit = AnalyticsConsentCubit(service: service);

        final pending = cubit.load();
        await cubit.close();

        await expectLater(pending, completes);
        expect(cubit.state.status, AnalyticsConsentStatus.loading);
      });
    });

    group('setEnabled', () {
      test('persists an opt-out through the service', () async {
        storedPreference = true;
        final cubit = AnalyticsConsentCubit(service: service);
        addTearDown(cubit.close);
        await cubit.load();
        expect(cubit.state.isEnabled, isTrue);

        await cubit.setEnabled(false);

        verify(() => service.setAnalyticsEnabled(false)).called(1);
        expect(cubit.state.isEnabled, isFalse);
      });

      test('persists an opt-in through the service', () async {
        final cubit = AnalyticsConsentCubit(service: service);
        addTearDown(cubit.close);
        await cubit.load();
        expect(cubit.state.isEnabled, isFalse);

        await cubit.setEnabled(true);

        verify(() => service.setAnalyticsEnabled(true)).called(1);
        expect(cubit.state.isEnabled, isTrue);
      });

      test('mirrors the service rather than the requested value', () async {
        // A write the service refuses must not leave the switch lying about
        // what was stored.
        when(
          () => service.setAnalyticsEnabled(any()),
        ).thenAnswer((_) async => true);
        final cubit = AnalyticsConsentCubit(service: service);
        addTearDown(cubit.close);
        await cubit.load();

        await cubit.setEnabled(true);

        expect(cubit.state.isEnabled, isFalse);
      });

      test('reports a write that never reached storage', () async {
        // The switch is a promise about the next launch. A write that failed
        // has to say so rather than render as a saved decision.
        storedPreference = true;
        when(
          () => service.setAnalyticsEnabled(any()),
        ).thenAnswer((_) async => false);
        final cubit = AnalyticsConsentCubit(service: service);
        addTearDown(cubit.close);
        await cubit.load();

        await cubit.setEnabled(false);

        expect(cubit.state.saveStatus, AnalyticsConsentSaveStatus.failure);
      });

      test('a stored write leaves no failure behind', () async {
        final cubit = AnalyticsConsentCubit(service: service);
        addTearDown(cubit.close);
        await cubit.load();

        await cubit.setEnabled(true);

        expect(cubit.state.saveStatus, AnalyticsConsentSaveStatus.idle);
      });

      test('marks the write in flight before it resolves', () async {
        // The tile locks while saving, so a second flip cannot land on top of
        // an answer that has not come back yet.
        final pending = Completer<bool>();
        when(
          () => service.setAnalyticsEnabled(any()),
        ).thenAnswer((_) => pending.future);
        final cubit = AnalyticsConsentCubit(service: service);
        addTearDown(cubit.close);
        await cubit.load();

        final write = cubit.setEnabled(true);
        await pumpEventQueue();
        expect(cubit.state.saveStatus, AnalyticsConsentSaveStatus.saving);

        pending.complete(true);
        await write;

        expect(cubit.state.saveStatus, AnalyticsConsentSaveStatus.idle);
      });
    });
  });
}
