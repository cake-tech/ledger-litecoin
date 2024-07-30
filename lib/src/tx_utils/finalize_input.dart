import 'dart:typed_data';

import 'package:ledger_flutter/ledger_flutter.dart';
import 'package:ledger_litecoin/src/operations/litecoin_untrusted_hash_tx_input_finalize_operation.dart';

Future<Uint8List> provideOutputFullChangePath(
        Ledger ledger, LedgerDevice device, LedgerTransformer transformer,
        {required String path}) =>
    ledger.sendOperation(device,
        LitecoinUntrustedHashTxInputFinalizeOperation(derivationPath: path),
        transformer: transformer);

Future<Uint8List> hashOutputFull(
        Ledger ledger, LedgerDevice device, LedgerTransformer transformer,
        {required Uint8List outputScript}) =>
    ledger.sendOperation(
        device,
        LitecoinUntrustedHashTxInputFinalizeOperation(
            outputScript: outputScript),
        transformer: transformer);
