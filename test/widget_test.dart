import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rn_ready/core/theme/app_theme.dart';
import 'package:rn_ready/features/home/home_dashboard.dart';

void main() {
  testWidgets('Dashboard renders core sections', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: const HomeDashboard(),
      ),
    ));

    expect(find.text('Ready to pass the PNLE?'), findsOneWidget);
    expect(find.text('Practice Quizzes'), findsOneWidget);
    expect(find.text('Nursing Practice Sections'), findsOneWidget);
  });
}
