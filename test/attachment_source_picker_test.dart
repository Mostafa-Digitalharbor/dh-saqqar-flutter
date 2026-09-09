// The four outcomes of a trip to a native picker.
//
// These branches used to live inside `_ChatScreenState`, which is why none of
// them were tested: reaching them meant pumping the whole chat screen — its
// cubit, its providers, its 1.5 s poll timer and three platform channels — to
// exercise a `switch` on a plugin's error code. So the camera's
// permission-denied path, the "picker returned a file with no path" case and
// the downscaler's extension rewrite all shipped on inspection alone.
//
// `AttachmentSourcePicker` touches no `BuildContext` and no `setState`, so
// each one is now a direct call against a faked method channel.

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:saqqar_app/features/chat/data/attachment_source_picker.dart';
import 'package:saqqar_app/features/chat/widgets/attachment_source_sheet.dart';

/// `image_picker`'s platform channel, answered by [answer].
///
/// Returning a value stands in for a capture; throwing a [PlatformException]
/// stands in for the OS refusing.
void _stubImagePicker(Object? Function() answer) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/image_picker'),
    (call) async => answer(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('picker_test');
    // `path_provider` has no implementation under `flutter test`, and
    // `_downscale` asks it for a scratch directory before touching a file.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => temp.path,
    );
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/image_picker'),
      null,
    );
    FilePicker.platform = FilePickerIO();
  });

  group('camera', () {
    test('a declined permission is Denied, not Failed', () async {
      // The distinction is the whole point: "try again" is advice that cannot
      // work until the user visits Settings, so this arm has to be reachable
      // separately from a plugin crash.
      _stubImagePicker(() {
        throw PlatformException(code: 'camera_access_denied');
      });

      final result = await const AttachmentSourcePicker()
          .pick(AttachmentPickerSource.camera);

      expect(result, isA<AttachmentPickDenied>());
    });

    test('any other PlatformException is Failed', () async {
      _stubImagePicker(() {
        throw PlatformException(code: 'no_available_camera');
      });

      final result = await const AttachmentSourcePicker()
          .pick(AttachmentPickerSource.camera);

      expect(result, isA<AttachmentPickFailed>());
    });

    test('backing out of the camera is Cancelled, which the UI keeps silent',
        () async {
      _stubImagePicker(() => null);

      final result = await const AttachmentSourcePicker()
          .pick(AttachmentPickerSource.camera);

      expect(result, isA<AttachmentPickCancelled>());
    });
  });

  group('file picker', () {
    test('a dismissed dialog is Cancelled', () async {
      FilePicker.platform = _FakeFilePicker(null);

      for (final source in [
        AttachmentPickerSource.photos,
        AttachmentPickerSource.files,
      ]) {
        expect(
          await const AttachmentSourcePicker().pick(source),
          isA<AttachmentPickCancelled>(),
          reason: '$source',
        );
      }
    });

    test('an empty selection is Cancelled, not an empty Picked', () async {
      // An empty `AttachmentsPicked` would fall through the caller's staging
      // path and do nothing visible — indistinguishable from a bug.
      FilePicker.platform = _FakeFilePicker(const FilePickerResult([]));

      expect(
        await const AttachmentSourcePicker().pick(AttachmentPickerSource.files),
        isA<AttachmentPickCancelled>(),
      );
    });

    test('a file the picker could not give a path to is still carried',
        () async {
      // Some cloud providers hand back metadata with no local path. Dropping
      // it here would lose the file silently; `AttachmentStaging` is what
      // decides such a candidate cannot be uploaded.
      FilePicker.platform = _FakeFilePicker(
        FilePickerResult([
          PlatformFile(name: 'remote.pdf', size: 1024, path: null),
        ]),
      );

      final result = await const AttachmentSourcePicker()
          .pick(AttachmentPickerSource.files);

      expect(result, isA<AttachmentsPicked>());
      final candidates = (result as AttachmentsPicked).candidates;
      expect(candidates, hasLength(1));
      expect(candidates.single.name, 'remote.pdf');
      expect(candidates.single.path, isNull);
      expect(candidates.single.size, 1024);
    });

    test('a non-image passes through the downscaler untouched', () async {
      final pdf = File('${temp.path}/report.pdf')..writeAsBytesSync(
          List<int>.filled(2048, 0),
        );
      FilePicker.platform = _FakeFilePicker(
        FilePickerResult([
          // The extension drives the kind icon and the size cap, so it must
          // survive a trip through `_downscale` unchanged.
          PlatformFile(
            name: 'report.pdf',
            size: pdf.lengthSync(),
            path: pdf.path,
          ),
        ]),
      );

      final result = await const AttachmentSourcePicker()
          .pick(AttachmentPickerSource.files);

      final candidates = (result as AttachmentsPicked).candidates;
      expect(candidates.single.path, pdf.path,
          reason: 'the downscaler must return non-images by identity');
      expect(candidates.single.size, pdf.lengthSync());
    });
  });
}

/// Serves one canned answer to every `pickFiles` call.
class _FakeFilePicker extends FilePicker {
  _FakeFilePicker(this._result);

  final FilePickerResult? _result;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    void Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async =>
      _result;
}
