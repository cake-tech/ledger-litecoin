import 'package:ledger_flutter/ledger_flutter.dart';
import 'package:ledger_litecoin/ledger_litecoin.dart';

Future<void> main() async {
  /// Create a new instance of LedgerOptions.
  final options = LedgerOptions(
    maxScanDuration: const Duration(milliseconds: 5000),
  );

  /// Create a new instance of Ledger.
  final ledger = Ledger(
    options: options,
  );

  /// Create a new Litecoin Ledger Plugin.
  final litecoinApp = LitecoinLedgerApp(ledger);

  /// Scan for devices
  ledger.scan().listen((device) => print(device));

  /// or get a connected one
  final device = ledger.devices.first;

  /// Fetch a list of accounts/public keys from your ledger.
  final accounts = await litecoinApp.getAccounts(device);

  print(accounts);
}
