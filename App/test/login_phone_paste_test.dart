import 'package:agrhi/controllers/language_controller.dart';
import 'package:agrhi/views/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('login accepts a clipboard paste through the actual phone field', (
    tester,
  ) async {
    var clipboard = '9867534210';
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.getData') return {'text': clipboard};
        if (call.method == 'Clipboard.hasStrings') return {'value': true};
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageController(),
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(1), 'Test1234');

    for (final value in ['9867534210', '\u200E98675\u00A034210\u200B\n']) {
      clipboard = value;
      await tester.enterText(fields.first, '');
      final editor = tester.state<EditableTextState>(
        find.descendant(of: fields.first, matching: find.byType(EditableText)),
      );
      await editor.pasteText(SelectionChangedCause.toolbar);
      await tester.pumpAndSettle();
      expect(editor.widget.controller.text, '9867534210');
      expect(tester.state<FormState>(find.byType(Form)).validate(), isTrue);
      await tester.pump();
      expect(find.text('Phone number should contain only digits'), findsNothing);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 250));
  });
}
