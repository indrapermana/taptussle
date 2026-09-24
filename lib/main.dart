import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const TapTussleBootstrap());
}
