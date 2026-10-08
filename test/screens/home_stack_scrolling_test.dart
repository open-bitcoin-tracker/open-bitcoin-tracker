import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_bitcoin_tracker/screens/home/home_screen.dart';
import 'package:open_bitcoin_tracker/widgets/stack_card.dart';

import '../support/app_test_host.dart';
import '../support/test_viewport.dart';

void main() {
  testWidgets('a large portfolio builds visible rows and scrolls to the end', (
    tester,
  ) async {
    setTestViewport(tester, const Size(400, 850));
    final state = jsonEncode({
      'showPortfolio': true,
      'showChart': false,
      'stacks': [
        for (var i = 0; i < 200; i++)
          {'id': 'stack-$i', 'name': 'Wallet $i', 'sats': 1000000},
      ],
    });
    await tester.pumpWidget(
      await appTestHost(HomeScreen(onAddStack: () {}), initialState: state),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(StackCard).evaluate().length, lessThan(30));
    expect(find.text('Wallet 199'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Wallet 199'),
      600,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 100,
    );
    await tester.pump();
    expect(find.text('Wallet 199'), findsOneWidget);
    expect(find.byType(StackCard).evaluate().length, lessThan(30));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
