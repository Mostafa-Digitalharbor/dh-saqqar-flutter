/// Every bundled asset path, in one place.
///
/// Paths here must stay in sync with the `assets:` / `fonts:` sections of
/// `pubspec.yaml` — a typo in either place fails at runtime (a missing
/// image falls through to an `errorBuilder`, a missing font silently
/// falls back to the platform face), never at compile time. Keeping the
/// strings named and centralised means a rename is one edit, and
/// `AssetPathsTest` can assert every entry actually exists on disk.
///
/// Font *family* names live in `AppTypography`, not here: those are
/// pubspec-declared identifiers rather than file paths.
class AssetPaths {
  AssetPaths._();

  static const _img = 'assets/img';

  /// Canonical app lockup. Navy artwork — tinted white by `SaqqarLogo`
  /// when it sits on a dark surface, so there is deliberately no separate
  /// dark variant to pick between.
  static const logo = '$_img/logo-light.png';

  static const _design = 'assets/design';

  // ── Redesign (2026-11) artwork ──────────────────────────────────────
  /// Black → electric-blue → grey page glow behind the light screens.
  static const backdropLight = '$_design/bg_light.png';
  static const avatar = '$_design/avatar.png';
  static const orb = '$_design/orb.png';
  static const successCheck = '$_design/success_check.png';
  static const socialApple = '$_design/social_apple.png';
  static const socialGoogle = '$_design/social_google.png';
  static const emptyMailbox = '$_design/empty_mailbox.png';
  static const emptyPiggy = '$_design/empty_piggy.png';
  static const processPlane = '$_design/process_plane.png';
}
