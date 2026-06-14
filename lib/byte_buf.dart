class ByteBuf {

  final List<int> buffer;
  var readerIndex = 0;

  ByteBuf(this.buffer);

  void reset() {
    readerIndex = 0;
  }

  int get readableBytes {
    return buffer.length - readerIndex;
  }

  int readUnsignedByte() {
    return buffer[readerIndex++];
  }

  void writeUnsignedByte(int value) {
    buffer.add(value & 0xFF);
  }

  bool readBoolean() {
    return readUnsignedByte() != 0;
  }

  int readUnsignedMedium() {
    var first = readUnsignedByte();
    var second = readUnsignedByte();
    var third = readUnsignedByte();

    return (first << 16) | (second << 8) | third;
  }

  int readVarInt() {
    var value = 0;
    var position = 0;

    while (true) {
      var currentByte = readUnsignedByte();
      value += (currentByte & 0x7F) << position;

      if ((currentByte & 0x80) == 0) break;

      position += 7;

      if (position >= 32) {
        throw ByteBufParseException('VarInt too long: Position exceeds 32 bits');
      }
    }

    return value.toInt();
  }

  int readNegativeOptimizedVarInt() {
    var value = readVarInt();
    var sign = value & 0x01;
    return (value >> 1) * (sign == 1 ? -1 : 1);
  }

  int readVarLong() {
    var value = 0;
    var position = 0;

    while (true) {
      var currentByte = readUnsignedByte();
      value += (currentByte & 0x7F) << position;

      if ((currentByte & 0x80) == 0) break;

      position += 7;

      if (position >= 64) {
        throw ByteBufParseException('VarLong too long: Position exceeds 64 bits');
      }
    }

    return value;
  }

  void writeInt32(int value) {
    writeUnsignedByte(value >> 24);
    writeUnsignedByte(value >> 16);
    writeUnsignedByte(value >> 8);
    writeUnsignedByte(value);
  }

  int readInt32({required bool signed}) {
    var a = readUnsignedByte();
    var b = readUnsignedByte();
    var c = readUnsignedByte();
    var d = readUnsignedByte();

    var value = (a << 24) | (b << 16) | (c << 8) | d;
    if (signed) {
      value <<= 32;
      value >>= 32;
    }

    return value.toInt();
  }

  int readInt64() {
    var a = readUnsignedByte();
    var b = readUnsignedByte();
    var c = readUnsignedByte();
    var d = readUnsignedByte();
    var e = readUnsignedByte();
    var f = readUnsignedByte();
    var g = readUnsignedByte();
    var h = readUnsignedByte();

    var value = (a << 56) | (b << 48) | (c << 40) | (d << 32) | (e << 24) | (f << 16) | (g << 8) | h;

    return value.toInt();
  }

  void writeInt64(int value) {
    writeUnsignedByte(value >> 56);
    writeUnsignedByte(value >> 48);
    writeUnsignedByte(value >> 40);
    writeUnsignedByte(value >> 32);
    writeUnsignedByte(value >> 24);
    writeUnsignedByte(value >> 16);
    writeUnsignedByte(value >> 8);
    writeUnsignedByte(value);
  }

}

class ByteBufParseException implements Exception {

  final String message;

  ByteBufParseException(this.message);

  @override
  String toString() {
    return 'ByteBufParseException{message: $message}';
  }


}
