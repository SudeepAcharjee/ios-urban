/// Central authentication configuration
///
/// [kRequirePhoneVerification]:
/// Set to `false` during emulator testing because Android/iOS emulators
/// cannot reliably receive Firebase SMS OTPs or pass device integrity checks.
/// Switch back to `true` when building or testing on real physical devices.
const bool kRequirePhoneVerification = false;
