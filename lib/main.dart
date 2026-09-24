import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app_bootstrap.dart';
import 'app/font_licenses.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerBundledFontLicenses();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const TapTussleBootstrap());
}
