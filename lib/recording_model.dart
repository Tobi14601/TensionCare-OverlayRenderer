
import 'dart:convert';
import 'dart:math';

import 'package:tc_overlay_renderer/byte_buf.dart';

enum SensorPosition {
  left('assets/left.png', 1),
  right('assets/right.png', 2);

  final String asset;
  final int intValue;

  const SensorPosition(this.asset, this.intValue);

  static SensorPosition? fromIntValue(int value) {
    switch (value) {
      case 1:
        return left;
      case 2:
        return right;
      default:
        return null;
    }
  }

  String get title {
    switch (this) {
      case SensorPosition.left:
        return "Links";
      case SensorPosition.right:
        return "Rechts";
    }
  }

}

class ReplayDataPoint {

  final int timestamp;
  final double value;
  final SensorPosition position;

  ReplayDataPoint({required this.timestamp, required this.value, required this.position});

  @override
  String toString() {
    return 'ReplayDataPoint{timestamp: $timestamp, value: $value, position: $position}';
  }
}


class Recording {
  String description;
  int startTimestamp;
  int endTimestamp;
  int sensorMask;
  List<ReplayDataPoint> replay;
  bool hasVideo;

  Recording({
    required this.description,
    required this.startTimestamp,
    required this.endTimestamp,
    required this.sensorMask,
    required this.replay,
    required this.hasVideo,
  });

  static List<ReplayDataPoint> parseData(List<int> data) {
    var buf = ByteBuf(data);
    var version = buf.readInt32(signed: false);

    var parsed = <ReplayDataPoint>[];

    switch (version) {
      case 1:
        parsed = _parseVersion1(buf);
        break;
      default:
        throw Exception('Unsupported binary replay version $version');
    }

    if (buf.readableBytes > 0) {
      throw Exception('Did not fully consume bytebuf ${buf.readableBytes} remain');
    }

    return parsed;
  }

  static List<ReplayDataPoint> _parseVersion1(ByteBuf buf) {
    var length = buf.readInt32(signed: false);
    var result = <ReplayDataPoint>[];

    for (var i = 0; i < length; i++) {
      var timestamp = buf.readInt64();
      var sensor = buf.readUnsignedByte();
      var tempValue = buf.readInt32(signed: true);
      var value = tempValue / 1000.0;

      result.add(ReplayDataPoint(timestamp: timestamp, value: value, position: SensorPosition.fromIntValue(sensor)!));
    }

    return result;
  }


  @override
  String toString() {
    return 'Recording{description: $description, startTimestamp: $startTimestamp, endTimestamp: $endTimestamp, sensorMask: $sensorMask, replay: ${replay.length}, hasVideo: $hasVideo}';
  }

  static Recording readRecordingFromBuffer(List<int> dataBuffer) {
    var reader = _ByteReader(dataBuffer);

    var header = reader.readBytes(9);
    if (utf8.decode(header) != 'TC-Replay') {
      throw 'invalid tc replay header';
    }

    var format = reader.readBytes(1);
    if (format.firstOrNull != 0x01) {
      throw 'unsupported format $format';
    }

    var startTimestamp = _bytesToInt(reader.readBytes(8));
    var endTimestamp = _bytesToInt(reader.readBytes(8));
    var sensorMask = _bytesToInt(reader.readBytes(1));
    var descriptionLength = _bytesToInt(reader.readBytes(2));
    var description = utf8.decode(reader.readBytes(descriptionLength.toInt()));
    var dataLength = _bytesToInt(reader.readBytes(4));
    var data = reader.readBytes(dataLength.toInt());
    var hasVideo = _bytesToInt(reader.readBytes(1)) == 1;

    return Recording(
      description: description,
      startTimestamp: startTimestamp,
      endTimestamp: endTimestamp,
      sensorMask: sensorMask.toInt(),
      replay: parseData(data),
      hasVideo: hasVideo,
    );
  }

  static int _bytesToInt(List<int> bytes) {
    BigInt result = BigInt.from(0);
    for (int i = 0; i < bytes.length; i++) {
      result += BigInt.from(bytes[i]) << (8 * i);
    }

    return result.toInt();
  }
}


class _ByteReader {

  final List<int> buffer;
  final int length;
  var offset = 0;

  _ByteReader(List<int> data) : buffer = data.toList(growable: true), length = data.length;


  List<int> readBytesOrMax(int amount) {
    var bytesLeft = (length ?? 0) - offset;
    var actualTake = min(amount, bytesLeft);

    return readBytes(actualTake);
  }

  List<int> readBytes(num amount) {

    if (buffer.length >= amount) {
      return _takeByteFromBuffer(amount.toInt());
    }

    var bytesLeft = (length ?? 0) - offset;
    var toRead = amount - buffer.length;
    if (toRead > bytesLeft) {
      //We are attempting to read more than the file allows
      throw 'attempting to read past EOF offset: $offset length: $length amount $amount';
    }

    return _takeByteFromBuffer(amount.toInt());
  }

  bool hasBytesLeft() {
    return offset < length;
  }

  int get bytesLeft => length - offset;

  List<int> _takeByteFromBuffer(int amount) {
    var result = buffer.sublist(0, amount);
    buffer.removeRange(0, amount);
    offset += amount;
    return result;
  }
}