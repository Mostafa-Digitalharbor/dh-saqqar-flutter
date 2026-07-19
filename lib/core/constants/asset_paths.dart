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
}
