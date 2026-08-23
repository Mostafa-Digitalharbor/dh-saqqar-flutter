import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/i18n/app_strings.dart';

/// Pins the WORDING each plural category renders.
///
/// `i18n_parity_test` guards the SHAPE of the plural tables — that every
/// family defines all six CLDR categories in both locales. That is a
/// necessary check and an insufficient one: six present entries can still be
/// six wrong sentences. This file asserts the sentences.
///
/// The bug that started it was on screen, in the chat's thinking pill, in
/// Arabic: **"1 خطوات"** — the count pasted in front of a fixed plural noun,
/// which is how you write "1 stepS". Arabic inflects the noun on the count
/// and drops the numeral entirely at one and two, so no amount of
/// `'$n $label'` string-building can produce correct copy. Every expectation
/// below is a sentence a native speaker would actually write.
void main() {
  final en = AppStrings(const Locale('en'));
  final ar = AppStrings(const Locale('ar'));

  group('category selection', () {
    // Exercised through `thinkingSteps`, whose Arabic wording differs in
    // every one of the six categories — so the rendered string identifies
    // which category was chosen, without opening `_category` up for test.
    test('Arabic picks zero / one / two / few / many / other', () {
      expect(ar.thinkingSteps(0), 'بدون خطوات');
      expect(ar.thinkingSteps(1), 'خطوة واحدة');
      expect(ar.thinkingSteps(2), 'خطوتان');
      expect(ar.thinkingSteps(3), '3 خطوات');
      expect(ar.thinkingSteps(10), '10 خطوات');
      expect(ar.thinkingSteps(11), '11 خطوة');
      expect(ar.thinkingSteps(99), '99 خطوة');
      expect(ar.thinkingSteps(100), '100 خطوة');
    });

    test('Arabic few/many bands repeat every hundred', () {
      // CLDR keys these off `n % 100`, so 103 inflects exactly as 3 does.
      // Getting this wrong is invisible until a conversation runs long.
      expect(ar.thinkingSteps(103), '103 خطوات');
      expect(ar.thinkingSteps(110), '110 خطوات');
      expect(ar.thinkingSteps(111), '111 خطوة');
    });

    test('Arabic reads the whole number for the dual, not the remainder', () {
      // 102 is `other`, NOT `two` — `_category` tests `n == 2` before it
      // takes any remainder, which is the line that decides this.
      expect(ar.thinkingSteps(102), '102 خطوة');
      expect(ar.thinkingSteps(2), 'خطوتان');
    });

    test('English collapses to one / other', () {
      expect(en.thinkingSteps(0), '0 steps');
      expect(en.thinkingSteps(1), '1 step');
      expect(en.thinkingSteps(2), '2 steps');
      expect(en.thinkingSteps(11), '11 steps');
    });
  });

  group('no category renders a stray placeholder or a raw key', () {
    // `_f` leaves an unknown `{slot}` verbatim and `_t` returns the raw key
    // when nothing resolves. Both failures render quietly, so sweep every
    // family across every category rather than trusting the six spot checks
    // above.
    final families = <String, String Function(AppStrings, int)>{
      'thinkingSteps': (t, n) => t.thinkingSteps(n),
      'shareCountFiles': (t, n) => t.shareCountFiles(n),
      'sentToastFiles': (t, n) => t.sentToastFiles(n),
      'approvalBatchResolved': (t, n) => t.approvalBatchResolved(n),
      'envMultiSelectedCount': (t, n) => t.envMultiSelectedCount(n),
      'relativeDaysAgo': (t, n) => t.relativeDaysAgo('$n', n),
    };

    for (final entry in families.entries) {
      test('${entry.key} is clean in both locales', () {
        for (final n in [0, 1, 2, 3, 10, 11, 99, 100, 102, 103]) {
          for (final tr in [en, ar]) {
            final out = entry.value(tr, n);
            expect(out, isNotEmpty, reason: '${entry.key}($n) rendered empty');
            expect(out, isNot(contains('{')),
                reason: '${entry.key}($n) leaked a placeholder: $out');
            expect(out, isNot(contains('_')),
                reason: '${entry.key}($n) leaked a raw key: $out');
          }
        }
      });
    }
  });

  group('the sentences that were wrong before', () {
    test('the thinking pill no longer says "1 خطوات"', () {
      // The literal string seen on a real device, in a real conversation.
      expect(ar.thinkingSteps(1), isNot('1 خطوات'));
      expect(ar.thinkingSteps(1), 'خطوة واحدة');
    });

    test('two days ago is the dual, with no numeral', () {
      // `AppDateFormat.relative` only reaches the day bucket at 2..6 (48 h
      // and up, under a week), so 2 was the single wrong case here — and
      // the only one whose correct form drops `{n}` altogether.
      expect(ar.relativeDaysAgo('2', 2), 'منذ يومين');
      expect(ar.relativeDaysAgo('3', 3), 'منذ 3 أيام');
      expect(ar.relativeDaysAgo('6', 6), 'منذ 6 أيام');
    });

    test('a single approved request is singular in BOTH locales', () {
      // English was wrong here too: 'Approved {count} requests' rendered
      // "Approved 1 requests" whenever a batch cleared exactly one.
      expect(en.approvalBatchResolved(1), 'Approved 1 request');
      expect(ar.approvalBatchResolved(1), 'تمت الموافقة على طلب واحد');
      expect(ar.approvalBatchResolved(3), 'تمت الموافقة على 3 طلبات');
    });

    test('the env sheet has a zero form, which it can actually reach', () {
      // Deselecting every environment is one tap away, and Arabic used to
      // render "0 بيئة مختارة" there. English keeps "0 selected" — its CLDR
      // rule has no `zero` category at all, which is correct and is the
      // reason the English `_zero` entry has to mirror `_other`.
      expect(ar.envMultiSelectedCount(0), 'لم تُختر أي بيئة');
      expect(en.envMultiSelectedCount(0), '0 selected');
      expect(ar.envMultiSelectedCount(2), 'بيئتان مختارتان');
    });

    test('share and send counts inflect past the English one/many split', () {
      // Both call sites used to branch `count <= 1` in the widget — English's
      // rule, applied to Arabic. It is right at 1 and wrong from 2 onward.
      expect(ar.shareCountFiles(2), 'ملفان من تطبيق آخر');
      expect(ar.shareCountFiles(11), '11 ملفاً من تطبيق آخر');
      expect(ar.sentToastFiles(2), 'تم الإرسال · ملفان مرفقان');
      expect(ar.sentToastFiles(5), 'تم الإرسال · 5 ملفات مرفقة');
    });
  });

  group('the numeral passed in is the one rendered', () {
    test('relativeDaysAgo prints its formatted label, not its raw count', () {
      // The two arguments are deliberately independent: the label has
      // already been through the locale's numbering system, while the int
      // only picks the form. Passing a distinguishable label proves the
      // template substitutes the former.
      expect(ar.relativeDaysAgo('٤', 4), 'منذ ٤ أيام');
      expect(en.relativeDaysAgo('4', 4), '4 d ago');
    });
  });
}
