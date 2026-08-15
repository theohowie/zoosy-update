import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoosy/generated/l10n/app_localizations.dart';
import 'package:zoosy/generated/l10n/l10n_ext.dart';

void main() {
  test('lookupAppLocalizations returns zh translations', () {
    final l = lookupAppLocalizations(const Locale('zh'));
    expect(l.save, '保存');
    expect(l.cancel, '取消');
    expect(l.delete_selected_count('3'), '确定要删除选中的 3 条记录吗？');
    // 转义回归：\n 应为换行，无多余反斜杠，'下' 不应丢失
    expect(l.guest_login_desc, '游客模式下记录的思考不会保存到账号，\n下次打开 App 仍然需要重新登录。\n\n游客登录仅供体验。');
  });

  test('lookupAppLocalizations returns en translations', () {
    final l = lookupAppLocalizations(const Locale('en'));
    expect(l.save, 'Save');
    expect(l.delete_selected_count('3'), 'Delete 3 selected records?');
    expect(l.guest_login_desc, "Thoughts recorded as guest won't be saved to an account.\nYou'll need to log in again next time.\n\nGuest login is for trial only.");
  });

  test('lookupAppLocalizations returns zh_TW translations', () {
    final l = lookupAppLocalizations(const Locale('zh', 'TW'));
    expect(l.save, '保存');
  });

  test('unsupported locale throws in lookup (MaterialApp resolves first)', () {
    expect(() => lookupAppLocalizations(const Locale('xx')), throwsFlutterError);
  });

  test('supportedLocales contains all 9 locales', () {
    expect(AppLocalizations.supportedLocales, hasLength(9));
    expect(AppLocalizations.supportedLocales, contains(const Locale('zh')));
    expect(AppLocalizations.supportedLocales, contains(const Locale('zh', 'TW')));
    expect(AppLocalizations.supportedLocales, contains(const Locale('th')));
  });

  testWidgets('delegates + context.l10n resolve zh locale', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Builder(builder: (ctx) => Text(ctx.l10n.save)),
    ));
    expect(find.text('保存'), findsOneWidget);
  });

  testWidgets('delegates + context.l10n resolve en locale', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Builder(builder: (ctx) => Text(ctx.l10n.save)),
    ));
    expect(find.text('Save'), findsOneWidget);
  });
}
