import 'dart:typed_data';

import 'package:ledger_flutter/ledger_flutter.dart';
import 'package:ledger_litecoin/src/utils/string_uint8list_extension.dart';

class LitecoinTransformer extends LedgerTransformer {
  const LitecoinTransformer();

  @override
  Future<Uint8List> onTransform(List<Uint8List> transform) async {
    print('Response ${transform.map((e) => e.toHexString())}');
    if (transform.isEmpty) {
      throw LedgerException(message: 'No response data from Ledger.');
    }

    final lastItem = transform.last;
    if (lastItem.length == 2) {
      final errorCode = ByteData.sublistView(lastItem).getInt16(0);

      if (lastItem.first == 0x90 && lastItem.last == 0x00) {
        return Uint8List.fromList([]);
      }

      throw LedgerException(errorCode: errorCode);
    }

    final output = <Uint8List>[];

    for (final data in transform) {
      final offset = (data.length >= 2) ? 2 : 0;
      output.add(data.sublist(0, data.length - offset));
    }

    return Uint8List.fromList(output.expand((e) => e).toList());
  }
}
