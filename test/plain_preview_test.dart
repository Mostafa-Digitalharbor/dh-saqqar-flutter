import 'package:flutter_test/flutter_test.dart';

import 'package:saqqar_app/core/format/plain_preview.dart';

void main() {
  group('plainPreview', () {
    test('drops bold markers and keeps the words', () {
      expect(
        plainPreview('**Saqqar Apps · WhatsApp integration**\n_Guided setup_'),
        'Saqqar Apps · WhatsApp integration Guided setup',
      );
    });

    test('keeps a link label and drops the url', () {
      expect(
        plainPreview('See [the guide](https://x.test/a) now'),
        'See the guide now',
      );
    });

    test('strips headings, bullets and code ticks', () {
      expect(plainPreview('# Title\n- one\n- `two`'), 'Title one two');
    });

    test('leaves plain text and snake_case alone', () {
      expect(
        plainPreview('sale_order moved to done'),
        'sale_order moved to done',
      );
    });

    test('collapses whitespace and handles empty', () {
      expect(plainPreview('  a \n\n b  '), 'a b');
      expect(plainPreview(''), '');
    });
  });
}
