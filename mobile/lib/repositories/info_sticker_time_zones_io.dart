// ABOUTME: Native and test builds: the time zone database is compiled in, so
// ABOUTME: it is initialised without loading a library first.

import 'package:timezone/data/latest.dart' as tz_data;

/// Initialises the time zone database, which holds each zone's whole history.
///
/// A native build ships it in the binary, so a deferred library would save
/// nothing here. Waiting on one also stalled the two sun time tests for their
/// full ten minutes in CI's merged test isolate, while the same tests passed at
/// once on their own.
Future<void> loadTimeZoneDatabase() async => tz_data.initializeTimeZones();
