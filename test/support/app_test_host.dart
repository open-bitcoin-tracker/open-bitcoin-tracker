import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:open_bitcoin_tracker/api/api.dart';
import 'package:open_bitcoin_tracker/data/data.dart';
import 'package:open_bitcoin_tracker/l10n/generated/app_localizations.dart';
import 'package:open_bitcoin_tracker/state/state.dart';
import 'package:open_bitcoin_tracker/theme/theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A deterministic app host without sockets or filesystem residue.
Future<Widget> appTestHost(Widget screen, {String initialState = '{}'}) async {
  SharedPreferences.setMockInitialValues({
    AppStateRepository.storageKey: initialState,
    BtcRatesCache.storageKey: '{"USD":100000,"GBP":80000,"EUR":90000}',
  });
  final prefs = await SharedPreferences.getInstance();
  final directory = Directory.systemTemp.createTempSync('btc_visual_');
  addTearDown(() => directory.delete(recursive: true));
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => AppStateNotifier(AppStateRepository(prefs)),
      ),
      ChangeNotifierProvider(
        create: (ctx) =>
            StacksLockController(app: ctx.read<AppStateNotifier>()),
      ),
      ChangeNotifierProvider(
        create: (ctx) => ConverterState(app: ctx.read<AppStateNotifier>()),
      ),
      ChangeNotifierProvider(
        create: (_) => LivePriceController(
          stream: KrakenStreamService(),
          ohlc: KrakenOhlcClient(
            httpClient: MockClient((_) async => http.Response('', 503)),
          ),
          cache: BtcRatesCache(prefs),
          historyCache: BtcHistoryCache(directory: directory),
        ),
      ),
    ],
    child: MaterialApp(
      theme: AppThemes.light(),
      locale: const Locale('en', 'GB'),
      supportedLocales: const [Locale('en', 'GB')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: screen,
    ),
  );
}
