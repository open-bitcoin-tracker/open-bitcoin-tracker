import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api.dart';
import '../data/data.dart';
import '../services/stacks_auth_service.dart';
import '../services/stacks_crypto_service.dart';
import '../services/stacks_unlock_orchestrator.dart';
import '../state/state.dart';

/// Owns the app's dependency lifetimes independently of widget rebuilds.
class AppProviders extends StatelessWidget {
  const AppProviders({super.key, required this.prefs, required this.child});

  final SharedPreferences prefs;
  final Widget child;

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      Provider(create: (_) => StacksCryptoService()),
      Provider(create: (_) => StacksAuthService()),
      Provider(
        create: (ctx) =>
            AppStateRepository(prefs, crypto: ctx.read<StacksCryptoService>()),
      ),
      Provider(create: (_) => BtcRatesCache(prefs)),
      Provider(create: (_) => BtcHistoryCache()),
      ChangeNotifierProvider(
        create: (ctx) => AppStateNotifier(ctx.read<AppStateRepository>()),
      ),
      ChangeNotifierProvider(
        create: (ctx) =>
            StacksLockController(app: ctx.read<AppStateNotifier>())..start(),
      ),
      Provider(
        create: (ctx) => StacksUnlockOrchestrator(
          app: ctx.read<AppStateNotifier>(),
          auth: ctx.read<StacksAuthService>(),
          crypto: ctx.read<StacksCryptoService>(),
        ),
      ),
      ChangeNotifierProvider(
        create: (ctx) => ConverterState(app: ctx.read<AppStateNotifier>()),
      ),
      ChangeNotifierProvider(
        create: (ctx) {
          final app = ctx.read<AppStateNotifier>();
          return LivePriceController(
            stream: KrakenStreamService(),
            ohlc: KrakenOhlcClient(),
            cache: ctx.read<BtcRatesCache>(),
            historyCache: ctx.read<BtcHistoryCache>(),
            cadence: app.livePriceCadence,
            app: app,
          )..start();
        },
      ),
    ],
    child: child,
  );
}
