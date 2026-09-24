import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

void registerBundledFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'Fredoka',
    ], await rootBundle.loadString('assets/fonts/fredoka/OFL.txt'));
    yield LicenseEntryWithLineBreaks(const [
      'Lilita One',
    ], await rootBundle.loadString('assets/fonts/lilita_one/OFL.txt'));
  });
}
