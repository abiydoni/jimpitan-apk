import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jimpitan/widgets/custom_gradient_app_bar.dart';

void main() {
  testWidgets('CustomGradientAppBar renders title properly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          appBar: CustomGradientAppBar(
            titleText: 'Jimpitan Digital',
          ),
        ),
      ),
    );

    expect(find.text('Jimpitan Digital'), findsOneWidget);
  });
}

