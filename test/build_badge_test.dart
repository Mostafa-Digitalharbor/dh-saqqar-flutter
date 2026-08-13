// The build label shown at the top of the sign-in screen.
//
// It exists to answer one question on a real device — "which build is this
// phone actually running?" — so the thing worth pinning is that it never
// answers it WRONGLY. An empty or half-read `PackageInfo` must produce no
// badge at all, never `1.2.6 ()` or a bare `(203)`, because a tester
// comparing it against the Play Console listing would read a malformed
// string as a mismatch and chase a rollout problem that does not exist.

import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/app_build_info.dart';

void main() {
  setUp(() {
    AppBuildInfo.version = '';
    AppBuildInfo.buildNumber = '';
  });

  tearDown(() {
    AppBuildInfo.version = '';
    AppBuildInfo.buildNumber = '';
  });

  test('reads back exactly what the Play Console shows', () {
    AppBuildInfo.version = '1.2.6';
    AppBuildInfo.buildNumber = '203';
    // Character for character: the console lists "1.2.6" with version code
    // 203, and a tester matches the two by eye.
    expect(AppBuildInfo.label, '1.2.6 (203)');
  });

  test('drops the parenthesis when the build code is unknown', () {
    AppBuildInfo.version = '1.2.6';
    expect(AppBuildInfo.label, '1.2.6');
  });

  test('says nothing at all when PackageInfo failed', () {
    // `main()` guards the PackageInfo read and leaves both empty on failure.
    // The badge collapses rather than rendering an orphan build code.
    expect(AppBuildInfo.label, isEmpty);

    AppBuildInfo.buildNumber = '203';
    expect(
      AppBuildInfo.label,
      isEmpty,
      reason: 'a build code with no version is not a version string',
    );
  });
}
