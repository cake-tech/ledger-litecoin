import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:ledger_flutter/ledger_flutter.dart';
import 'package:ledger_litecoin/src/tx_utils/constants.dart';
import 'package:ledger_litecoin/src/tx_utils/finalize_input.dart';
import 'package:ledger_litecoin/src/tx_utils/get_trusted_input.dart';
import 'package:ledger_litecoin/src/tx_utils/get_trusted_input_bip143.dart';
import 'package:ledger_litecoin/src/tx_utils/serialize_transaction.dart';
import 'package:ledger_litecoin/src/tx_utils/sign_transaction.dart';
import 'package:ledger_litecoin/src/tx_utils/start_untrusted_hash_tx_input.dart';
import 'package:ledger_litecoin/src/tx_utils/transaction.dart';
import 'package:ledger_litecoin/src/utils/make_xpub.dart';
import 'package:ledger_litecoin/src/utils/string_uint8list_extension.dart'
    as uint_8_list_h;

class TrustedInput {
  final bool trustedInput;
  final Uint8List value;
  final Uint8List sequence;

  const TrustedInput({
    required this.trustedInput,
    required this.value,
    required this.sequence,
  });
}

Future<String> createTransaction(
  Ledger ledger,
  LedgerDevice device,
  LedgerTransformer transformer, {
  required List<LedgerTransaction> inputs,
  required List<TransactionOutput> outputs,
  required int sigHashType,
  bool isSegWit = false,
  bool useTrustedInputForSegwit = true,
  List<String> additionals = const [],
  String? changePath,
  int? lockTime,
}) async {
  final bech32 = isSegWit && additionals.contains("bech32");
  final useBip143 = isSegWit || additionals.contains("bip143");

  final lockTimeBuffer = ByteDataWriter()
    ..writeUint32(lockTime ?? 0, Endian.little);
  final nullScript = Uint8List(0);
  final nullPrevout = Uint8List(0);

  final defaultVersion = ByteDataWriter()..writeUint32(0x01, Endian.little);

  final List<TrustedInput> trustedInputs = [];
  final List<TransactionOutput> regularOutputs = [];
  final List<Uint8List> signatures = [];

  var firstRun = true;
  final resuming = false;
  final targetTransaction = Transaction(version: defaultVersion.toBytes());
  final outputScript = serializeTransactionOutputs(outputs);

  for (final inputData in inputs) {
    final inputTx = Transaction.fromRaw(inputData.rawTx);
    if (!resuming) {
      final trustedInput = useBip143 && !useTrustedInputForSegwit
          ? getTrustedInputBIP143(inputData.outputIndex, inputTx)
          : await getTrustedInput(ledger, device, transformer,
              indexLookup: inputData.outputIndex, transaction: inputTx);

      final sequence = ByteDataWriter()
        ..writeUint32(inputData.sequence ?? 0xffffffff, Endian.little);

      trustedInputs.add(TrustedInput(
        trustedInput: true,
        value: uint_8_list_h.fromHexString(trustedInput),
        sequence: sequence.toBytes(),
      ));
    }

    regularOutputs.add(inputTx.outputs[inputData.outputIndex]);
  }

  targetTransaction.inputs = inputs.map((input) {
    final sequence = ByteDataWriter()
      ..writeUint32(input.sequence ?? 0xffffffff, Endian.little);

    return TransactionInput(nullPrevout, nullScript, sequence.toBytes());
  }).toList();

  if (useBip143) {
    // Do the first run with all inputs
    await startUntrustedHashTransactionInput(
      ledger,
      device,
      transformer,
      isNewTransaction: true,
      transaction: targetTransaction,
      inputs: trustedInputs,
      isBip143: true,
      additionals: additionals,
      useTrustedInputForSegwit: useTrustedInputForSegwit,
    );

    if (!resuming && changePath != null) {
      await provideOutputFullChangePath(ledger, device, transformer,
          path: changePath);
    }

    await hashOutputFull(ledger, device, transformer,
        outputScript: outputScript);
  }

  // Do the second run with the individual transaction
  for (var i = 0; i < inputs.length; i++) {
    final input = inputs[i];
    final script = input.redeemScript ??
        (!isSegWit
            ? regularOutputs[i].script
            : Uint8List.fromList([
                OP_DUP,
                OP_HASH160,
                HASH_SIZE,
                ...hashPublicKey(input.ownerPublicKey),
                OP_EQUALVERIFY,
                OP_CHECKSIG,
              ]));
    final pseudoTX = targetTransaction.clone();
    final pseudoTrustedInputs = useBip143 ? [trustedInputs[i]] : trustedInputs;

    if (useBip143) {
      final onlyInput = pseudoTX.inputs[i];
      onlyInput.script = script;
      pseudoTX.inputs = [onlyInput];
    } else {
      pseudoTX.inputs[i].script = script;
    }

    await startUntrustedHashTransactionInput(
      ledger,
      device,
      transformer,
      isNewTransaction: !useBip143 && firstRun,
      transaction: pseudoTX,
      inputs: pseudoTrustedInputs,
      isBip143: useBip143,
      additionals: additionals,
      useTrustedInputForSegwit: useTrustedInputForSegwit,
    );

    if (!useBip143) {
      if (!resuming && changePath != null) {
        await provideOutputFullChangePath(ledger, device, transformer,
            path: changePath);
      }

      await hashOutputFull(ledger, device, transformer,
          outputScript: outputScript);
    }

    final signature = await signTransaction(
      ledger,
      device,
      transformer,
      path: input.ownerDerivationPath,
      lockTime: lockTime ?? 0,
      sigHashType: sigHashType,
    );

    signatures.add(signature);
    targetTransaction.inputs[i].script = nullScript;
  }

  // Populate the final input scripts
  for (var i = 0; i < inputs.length; i++) {
    if (isSegWit) {
      targetTransaction.witness = [];

      if (!bech32) {
        targetTransaction.inputs[i].script = Uint8List.fromList([
          ...hex.decode("160014"),
          ...hashPublicKey(inputs[i].ownerPublicKey),
        ]);
      }
    } else {
      targetTransaction.inputs[i].script = Uint8List.fromList([
        signatures[i].length,
        ...signatures[i],
        inputs[i].ownerPublicKey.length,
        ...inputs[i].ownerPublicKey,
      ]);
    }

    final offset = useBip143 && !useTrustedInputForSegwit ? 0 : 4;
    targetTransaction.inputs[i].prevout =
        trustedInputs[i].value.sublist(offset, offset + 0x24);
  }

  targetTransaction.locktime = lockTimeBuffer.toBytes();

  var result = Uint8List.fromList([
    ...serializeTransaction(
        targetTransaction, false, additionals.contains("bech32")),
    ...outputScript,
  ]);

  if (isSegWit) {
    var witness = Uint8List(0);

    for (var i = 0; i < inputs.length; i++) {
      final tmpScriptData = Uint8List.fromList([
        0x02,
        signatures[i].length,
        ...signatures[i],
        inputs[i].ownerPublicKey.length,
        ...inputs[i].ownerPublicKey,
      ]);
      witness = Uint8List.fromList([...witness, ...tmpScriptData]);
    }

    result = Uint8List.fromList([...result, ...witness]);
  }

  result = Uint8List.fromList([...result, ...lockTimeBuffer.toBytes()]);

  return hex.encode(result);
}
