import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

Future<String> appVersionLabel() async {
  final info = await PackageInfo.fromPlatform();
  final build = info.buildNumber.isEmpty ? '' : '+${info.buildNumber}';
  return 'v${info.version}$build';
}

String platformLabel() {
  if (kIsWeb) return 'Web';
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'Android',
    TargetPlatform.iOS => 'iOS',
    TargetPlatform.windows => 'Windows',
    TargetPlatform.macOS => 'macOS',
    TargetPlatform.linux => 'Linux',
    TargetPlatform.fuchsia => 'Fuchsia',
  };
}