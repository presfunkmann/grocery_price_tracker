import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/currency_converter.dart';
import '../../providers/database_provider.dart';
import '../../providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _exchangeRateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize with current exchange rate
    final settings = ref.read(displaySettingsProvider);
    _exchangeRateController.text = settings.exchangeRate.toStringAsFixed(4);
  }

  @override
  void dispose() {
    _exchangeRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(displaySettingsProvider);
    final settingsNotifier = ref.read(displaySettingsProvider.notifier);
    final db = ref.read(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Currency Settings
          _buildSectionHeader(context, 'Currency'),
          ListTile(
            title: const Text('Display Currency'),
            subtitle: Text(settings.displayCurrency.name),
            trailing: SegmentedButton<Currency>(
              segments: const [
                ButtonSegment(value: Currency.MXN, label: Text('MXN')),
                ButtonSegment(value: Currency.USD, label: Text('USD')),
              ],
              selected: {settings.displayCurrency},
              onSelectionChanged: (selection) {
                settingsNotifier.setCurrency(selection.first);
              },
            ),
          ),
          ListTile(
            title: const Text('Exchange Rate (MXN to USD)'),
            subtitle: Text(
              '1 MXN = ${settings.exchangeRate.toStringAsFixed(4)} USD\n'
              '1 USD = ${(1 / settings.exchangeRate).toStringAsFixed(2)} MXN',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showExchangeRateDialog(context, db, settingsNotifier),
            ),
          ),

          const Divider(),

          // Unit Settings
          _buildSectionHeader(context, 'Units'),
          ListTile(
            title: const Text('Weight Unit'),
            subtitle: Text(settings.displayWeightUnit == 'kg' ? 'Kilograms' : 'Pounds'),
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'kg', label: Text('kg')),
                ButtonSegment(value: 'lb', label: Text('lb')),
              ],
              selected: {settings.displayWeightUnit},
              onSelectionChanged: (selection) {
                settingsNotifier.setWeightUnit(selection.first);
              },
            ),
          ),
          ListTile(
            title: const Text('Volume Unit'),
            subtitle: Text(settings.displayVolumeUnit == 'L' ? 'Liters' : 'Gallons'),
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'L', label: Text('L')),
                ButtonSegment(value: 'gal', label: Text('gal')),
              ],
              selected: {settings.displayVolumeUnit},
              onSelectionChanged: (selection) {
                settingsNotifier.setVolumeUnit(selection.first);
              },
            ),
          ),

          const Divider(),

          // Data Management
          _buildSectionHeader(context, 'Data'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            subtitle: const Text('Grocery Price Tracker v1.0.0'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  void _showExchangeRateDialog(
    BuildContext context,
    dynamic db,
    DisplaySettingsNotifier notifier,
  ) {
    final controller = TextEditingController(
      text: ref.read(displaySettingsProvider).exchangeRate.toStringAsFixed(4),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Exchange Rate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter MXN to USD rate:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '1 MXN = ? USD',
                helperText: 'e.g., 0.05 means 20 MXN = 1 USD',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final rate = double.tryParse(controller.text);
              if (rate != null && rate > 0) {
                notifier.saveExchangeRate(db, rate);
                Navigator.of(context).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
