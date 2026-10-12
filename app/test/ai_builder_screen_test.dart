import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pc_forge_mobile/features/build_pc/presentation/screens/ai_pc_builder_screen.dart';

void main() {
  testWidgets('AiPcBuilderScreen renders title, preset chips, and input bar', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AiPcBuilderScreen(),
      ),
    );

    // Initial frame
    await tester.pump();

    // Verify Title & Subtitle
    expect(find.text('Tell us what you need'), findsOneWidget);
    expect(find.text('AI Requirement Discovery • Step 1'), findsOneWidget);

    // Verify Quick Chips
    expect(find.text('🎮 Gaming PC for LKR 400,000'), findsOneWidget);
    expect(find.text('🎬 Video Editing (LKR 750,000)'), findsOneWidget);

    // Verify Input Field & Send Button
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
  });
}
