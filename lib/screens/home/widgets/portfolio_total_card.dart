import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/app_enums.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../services/app_haptics.dart';
import '../../../state/state.dart';
import '../../../widgets/stack_card.dart';
import '../../../widgets/avatar_sheet.dart';
import '../../stack_detail/total_detail_screen.dart';

class PortfolioTotalCard extends StatelessWidget {
  const PortfolioTotalCard({
    super.key,
    required this.app,
    required this.totalSats,
    required this.currency,
  });
  final AppStateNotifier app;
  final int totalSats;
  final Currency currency;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Builder(
      // Selecting the rate here (not in the screen build) confines the
      // per-tick rebuild to this card's subtree.
      builder: (cardContext) => StackCard(
        name: l10n.totalCardName,
        sats: totalSats,
        currency: currency,
        btcRate: cardContext.select<LivePriceController, double?>(
          (c) => c.rates.forCurrency(currency),
        ),
        btcDisplayMode: app.btcDisplayMode,
        imageData: app.state.totalImageData,
        colorKey: app.state.totalColorKey ?? 'grey',
        position: StackCardPosition.last,
        onTap: () {
          AppHaptics.light();
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => const TotalDetailScreen()),
          );
        },
        onAvatarTap: () {
          AppHaptics.light();
          _showTotalAvatarSheet(cardContext, app);
        },
      ),
    );
  }

  Future<void> _showTotalAvatarSheet(
    BuildContext iconContext,
    AppStateNotifier app,
  ) {
    final l10n = AppLocalizations.of(iconContext);
    return showAvatarSheet(
      iconContext,
      title: l10n.totalCardName,
      currentImageData: app.state.totalImageData,
      currentColorKey: app.state.totalColorKey ?? 'grey',
      onColorSet: (key) => app.setTotalColorKey(key ?? 'orange'),
      onImageSet: app.setTotalImageData,
      onImageCleared: () => app.setTotalImageData(null),
    );
  }
}
