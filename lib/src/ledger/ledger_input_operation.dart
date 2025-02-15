import 'dart:typed_data';

import 'package:ledger_flutter/ledger_flutter.dart';

abstract class LedgerInputOperation<T> extends LedgerOperation<T> {
  final int cla;
  final int ins;

  LedgerInputOperation(this.cla, this.ins);

  int get p1;

  int get p2;

  Future<Uint8List> writeInputData();

  @override
  Future<List<Uint8List>> write(ByteDataWriter writer) async {
    writer
      ..writeUint8(cla)
      ..writeUint8(ins)
      ..writeUint8(p1)
      ..writeUint8(p2);

    final inputData = await writeInputData();
    writer
      ..writeUint8(inputData.length)
      ..write(inputData);

    print("${runtimeType.toString()} Final Sending Data ${writer.toBytes().map((e) => e.toRadixString(16).padLeft(2, "0")).join()}");
    return [writer.toBytes()];
  }
}
