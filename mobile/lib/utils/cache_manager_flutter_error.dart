import 'package:material_ui/material_ui.dart';
import 'package:openvine/utils/disk_full_error.dart';

/// Whether an error flutter_cache_manager reported is worth a Crashlytics
/// report.
///
/// The cache manager reports both a cache index it cannot read and one it
/// cannot write. A write that failed because the disk is full is not a defect
/// the app can fix, so it is only logged. Every other failure is reported.
bool shouldReportCacheManagerError(FlutterErrorDetails details) =>
    !isDiskFullFileSystemError(details.exception);
