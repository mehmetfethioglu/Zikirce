import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:organicscore/core/theme/app_theme.dart';
import 'package:organicscore/features/scoring/domain/organic_score_calculator.dart';

void main() {
  testWidgets('AppTheme and OrganicScore visual widget rendering test', (WidgetTester tester) async {
    final scoreResult = OrganicScoreCalculator.calculate(
      riskLevels: ['LOW'],
      sugarGramsPer100g: 2.0,
      satFatGramsPer100g: 1.0,
      sodiumGramsPer100g: 0.1,
      fiberGramsPer100g: 5.0,
      proteinGramsPer100g: 8.0,
      novaGroup: 1,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.amoledDarkTheme,
        home: Scaffold(
          body: Center(
            child: Text('OrganicScore: ${scoreResult.overallScore}'),
          ),
        ),
      ),
    );

    expect(find.textContaining('OrganicScore:'), findsOneWidget);
  });
}
