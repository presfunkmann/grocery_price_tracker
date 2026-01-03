import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/currency_converter.dart';
import '../../core/services/receipt_parser_service.dart';
import '../../providers/database_provider.dart';
import '../../providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _exchangeRateController = TextEditingController();
  final _parserService = ReceiptParserService();
  bool _hasApiKey = false;

  @override
  void initState() {
    super.initState();
    // Initialize with current exchange rate
    final settings = ref.read(displaySettingsProvider);
    _exchangeRateController.text = settings.exchangeRate.toStringAsFixed(4);
    _checkApiKey();
  }

  Future<void> _checkApiKey() async {
    final hasKey = await _parserService.hasApiKey();
    if (mounted) {
      setState(() {
        _hasApiKey = hasKey;
      });
    }
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

          // Receipt Scanning / AI
          _buildSectionHeader(context, 'Receipt Scanning'),
          ListTile(
            leading: Icon(
              _hasApiKey ? Icons.check_circle : Icons.warning,
              color: _hasApiKey ? Colors.green : Colors.orange,
            ),
            title: const Text('Claude API Key'),
            subtitle: Text(_hasApiKey
                ? 'API key configured'
                : 'Required for AI receipt parsing'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_hasApiKey)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _showRemoveApiKeyDialog(context),
                  ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showApiKeyDialog(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'The API key is stored securely on your device and used to parse receipts with Claude AI. '
              'Get your API key from console.anthropic.com',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
          const SizedBox(height: 8),

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

  void _showApiKeyDialog(BuildContext context) {
    final controller = TextEditingController();
    bool isLoading = false;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Claude API Key'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter your Claude API key:'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'API Key',
                  hintText: 'sk-ant-...',
                  border: const OutlineInputBorder(),
                  errorText: errorMessage,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Get your API key from console.anthropic.com',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final key = controller.text.trim();
                      if (key.isEmpty) {
                        setDialogState(() {
                          errorMessage = 'Please enter an API key';
                        });
                        return;
                      }

                      setDialogState(() {
                        isLoading = true;
                        errorMessage = null;
                      });

                      // Test the API key
                      final (isValid, error) = await _parserService.testApiKey(key);

                      if (isValid) {
                        await _parserService.setApiKey(key);
                        await _checkApiKey();
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                                content: Text('API key saved successfully!')),
                          );
                        }
                      } else {
                        setDialogState(() {
                          isLoading = false;
                          errorMessage = error ?? 'Invalid API key. Please check and try again.';
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRemoveApiKeyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove API Key?'),
        content: const Text(
          'This will remove your stored API key. You will need to enter it again to use receipt scanning.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              await _parserService.clearApiKey();
              await _checkApiKey();
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('API key removed')),
                );
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
