import 'dart:typed_data';

import 'package:ledger_flutter/ledger_flutter.dart';
import 'package:ledger_litecoin/src/operations/litecoin_untrusted_hash_sign_operation.dart';

Future<Uint8List> signTransaction(
  Ledger ledger,
  LedgerDevice device,
  LedgerTransformer transformer, {
  required String path,
  required int lockTime,
  required int sigHashType,
}) =>
    ledger.sendOperation(
        device, LitecoinUntrustedHashSignOperation(path, lockTime, sigHashType),
        transformer: transformer);
