import 'dart:typed_data';

import 'package:ledger_flutter/ledger_flutter.dart';
import 'package:ledger_litecoin/src/ledger/ledger_input_operation.dart';
import 'package:ledger_litecoin/src/ledger/litecoin_instructions.dart';
import 'package:ledger_litecoin/src/utils/bip32_path_helper.dart';
import 'package:ledger_litecoin/src/utils/bip32_path_to_buffer.dart';

/// This command is used to sign a given secure hash using a private key (after
/// re-hashing it following the standard Bitcoin signing process) to finalize a
/// transaction input signing process.
///
/// This command will be rejected if the transaction signing state is not
/// consistent or if a user validation is required and the provided user
/// validation code is not correct.
class LitecoinUntrustedHashSignOperation
    extends LedgerInputOperation<Uint8List> {
  final String derivationPath;

  final int lockTime;

  final int sigHashType;

  LitecoinUntrustedHashSignOperation(
      this.derivationPath, this.lockTime, this.sigHashType)
      : super(btcCLA, untrustedHashSignINS);

  @override
  int get p1 => 0x00;

  @override
  int get p2 => 0x00;

  @override
  Future<Uint8List> read(ByteDataReader reader) async {
    final result = reader.read(reader.remainingLength);

    if(result.length == 2 && result == Uint8List.fromList([0x69, 0x85])) {
      print("SW_CONDITIONS_OF_USE_NOT_SATISFIED: Looser!");
    } else {
      print("Result ${result.map((e) => e.toRadixString(16)).join()}");
    }

    if (result.isNotEmpty) {
      result[0] = 0x30;
      return result.sublist(0, result.length - 2);
    }

    return result;
  }

  @override
  Future<Uint8List> writeInputData() async {
    final writer = ByteDataWriter();

    print(derivationPath);

    final path = BIPPath.fromString(derivationPath).toPathArray();
    writer.write(packDerivationPath(path));
    writer.write([0x00]);
    writer.writeUint32(lockTime);
    writer.write([sigHashType]);

    return writer.toBytes();
  }
}
