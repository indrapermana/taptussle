# M23.6 release build and store-preparation results

Audit date: 12 October 2026  
App version audited: `1.0.0+1`  
Git revision audited: `5fdc5a9`

## Artifact and device evidence

| Platform | Result | Evidence |
| --- | --- | --- |
| Android | Release build, install, and launch passed | `flutter build apk --release` produced a 105.6 MB APK. It installed and became the resumed activity on the connected Android 15/API 35 device (`23021RAA2Y`). No recent AndroidRuntime or Flutter error appeared after launch. SHA-256: `01d37dfa508dec5bcbdfeaaa3d2cb27ae19bf240320422248178db75b1da1aa3`. |
| iOS | Release compilation passed; physical launch blocked by local signing trust | `flutter build ios --release` produced a 77.0 MB `Runner.app`. SHA-256 of the Runner executable: `b4d400b5e2d4d62c116aa0292e955562104a7f48e51872a91a9ef88051a6a257`. Device launch failed with `invalid code signature, inadequate entitlements or its profile has not been explicitly trusted`. macOS reported no valid code-signing identities and `CSSMERR_TP_NOT_TRUSTED`. This is a signing environment blocker, not an observed app crash. |

The Android smoke APK above was built before release signing was hardened and
used the debug key for local installation. It must never be uploaded. The Gradle
configuration now reads a private `android/key.properties`, never falls back to
the debug key, and leaves release output unsigned until an upload key is supplied.
A second `flutter build apk --release` passed after hardening; Android's
`apksigner verify` correctly rejected that artifact as unsigned. This proves the
configuration compiles and cannot masquerade as a distributable signed build.

## Platform configuration audit

- Android application ID: `com.indesyakaryadigital.tap_tussle`
- Android minimum SDK: Flutter default for the installed toolchain (24)
- Android compile and target SDK: 36
- Android release manifest requests no Internet permission.
- iOS bundle ID: `com.indesyakaryadigital.tapTussle`
- iOS minimum version: 13.0
- iOS signing style: automatic; configured team: `ZFKPMMVU35`
- iOS and Android launcher icons and native launch artwork are present.

## Remaining blockers

1. Create and securely back up an Android upload keystore, copy
   `android/key.properties.example` to `android/key.properties`, and build the
   signed Android App Bundle.
2. Restore a valid Apple Development/Distribution identity and provisioning
   profile, repeat the physical iPhone launch, and later archive with the paid
   Apple Developer account used for App Store submission.
3. Publish the privacy policy and support page at stable public URLs. The
   confirmed publisher, PT INDESYA KARYA DIGITAL, and support email,
   support@indesyakaryadigital.com, are now present in the in-app legal pages.
4. Capture final store screenshots from the signed candidate and complete the
   store questionnaires using the declaration draft.
5. Complete deferred M23.3 profiling before declaring the release candidate
   final, unless the project owner explicitly accepts that release risk.

M23.6 therefore remains in progress. Compilation and Android physical launch are
proven; distribution signing and public support/privacy URLs still gate final
artifacts.
