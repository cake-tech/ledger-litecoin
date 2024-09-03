import 'dart:typed_data';

import 'package:ledger_flutter/ledger_flutter.dart';
import 'package:ledger_litecoin/src/ledger/litecoin_instructions.dart';
import 'package:ledger_litecoin/src/tx_utils/constants.dart';
import 'package:ledger_litecoin/src/operations/litecoin_untrusted_hash_tx_input_finalize_operation.dart';

Future<Uint8List> provideOutputFullChangePath(
    Ledger ledger, LedgerDevice device, LedgerTransformer transformer,
    {required String path}) =>
    ledger.sendOperation(device,
        LitecoinUntrustedHashTxInputFinalizeOperation(derivationPath: path),
        transformer: transformer);

Future<Uint8List> hashOutputFull(
    Ledger ledger, LedgerDevice device, LedgerTransformer transformer,
    {required Uint8List outputScript}) async {
  var offset = 0;
  final responses = <Uint8List>[];
  final outputScriptLength = outputScript.length;
  while (offset < outputScriptLength) {
    final blockSize = offset + MAX_SCRIPT_BLOCK >= outputScriptLength
        ? outputScriptLength - offset
        : MAX_SCRIPT_BLOCK;

    final p1 = offset + blockSize == outputScriptLength ? 0x80 : 0x00;
    final data = outputScript.sublist(offset, offset + blockSize);

    final dataWriter = ByteDataWriter()
      ..writeUint8(btcCLA)
      ..writeUint8(untrustedHashTransactionInputFinalizeINS)
      ..writeUint8(p1)
      ..writeUint8(0x00)
      ..writeUint8(data.length)
      ..write(data);

    responses.add(dataWriter.toBytes());
    offset += blockSize;
  }

  var finalRes;
  for (final res in responses) {
    finalRes = await ledger.sendOperation(
        device,
        RawOperation(data: res),
        transformer: transformer);
  }

  return finalRes;
}


class RawOperation
    extends LedgerOperation<Uint8List> {
  final Uint8List data;

  RawOperation(
      {required this.data});

  @override
  Future<Uint8List> read(ByteDataReader reader) async =>
      reader.read(reader.remainingLength);

  @override
  Future<List<Uint8List>> write(ByteDataWriter writer) async => [data];
}
