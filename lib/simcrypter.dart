import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

final List<String> b64Chars =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/='
        .split('');
final int minMsgLength = 1;
final int maxMsgLength = 4096;
final int keyLength = 6;

class InvalidKeyException implements Exception {
  final String _errMsg;

  const InvalidKeyException([this._errMsg = 'Invalid key.']);

  @override
  String toString() => _errMsg;
}

class InvalidInputException implements Exception {
  final String _errMsg;

  const InvalidInputException([this._errMsg = 'Invalid input.']);

  @override
  String toString() => _errMsg;
}

class QRCodeException implements Exception {
  final String _errMessage;

  const QRCodeException([this._errMessage = 'QR Code error.']);

  @override
  String toString() => _errMessage;
}

class FatalException implements Exception {
  final String _errMsg;

  const FatalException(this._errMsg);

  @override
  String toString() => _errMsg + '\nA fatal error has happened.';
}

/// Converts a message into an encrypted string based on [key] and vice versa.
String _convert(List<String> message, List<int> key, int action) {
  final List<String> keyHash = sha512.convert(key).toString().split('');
  List<String> cipher = List<String>.of(b64Chars);

  // A cipher is created by shuffling characters from b64Chars a 128 times,
  // based on the sha512 hash of the provided key.
  keyHash.forEach((element) {
    int charInt = int.parse(element, radix: 16);
    int charPos = (65 * (charInt / 15)).toInt();
    if (charPos == 0) charPos = cipher.length;

    // The character to be repositioned is popped and inserted at index 0.
    cipher.insert(0, cipher.removeAt(charPos - 1));

    // The cipher is reversed to make shuffling more effective.
    cipher = cipher.reversed.toList();
  });

  // For encryption, convMap entries: (key, value) => (char, cipher char)
  Map<String, String> convMap = {};
  for (int i = 0; i < b64Chars.length; i++) {
    convMap[b64Chars[i]] = cipher[i];
  }

  // For decryption, convMap entries: (key, value) => (cipher char, char)
  if (action == 1) convMap = convMap.map((key, value) => MapEntry(value, key));

  // Replace all characters based on convMap.
  for (int i = 0; i < message.length; i++) {
    message[i] = convMap[message[i]]!;
  }
  return message.join('');
}

class Encrypter {
  late final Random _random;
  String? _key;

  Encrypter() {
    try {
      _random = Random.secure();
    } on UnsupportedError catch (e) {
      throw FatalException(
          'A secure key could not be generated in your device:\n' +
              (e.message ?? ''));
    }
  }

  /// Returns the current [_key] as a [String].
  String? get key => _key;

  /// Generates a [keyLength] digit random key.
  void generateKey() {
    _key = List<int>.generate(keyLength, (int i) => _random.nextInt(10)).join();
  }

  /// Encrypts [message] and generates a key via [generateKey].
  ///
  /// Throws an [InvalidInputException] if [message] does not meet prerequisites.
  String encrypt(String message) {
    if (message.length < minMsgLength || message.length > maxMsgLength)
      throw InvalidInputException(
          'Message has ${message.length} characters, must have between $minMsgLength and $maxMsgLength characters.');
    generateKey();
    List<String> msg = base64.encode(utf8.encode(message)).split('');
    return _convert(msg, utf8.encode(_key!), 0);
  }
}

class Decrypter {
  late List<int> _key;

  /// Encodes key into utf-8.
  /// 
  /// Throws [InvalidKeyException] if key is not 6 characters.
  void parseKey(String key) {
    if (key.length != 6)
      throw InvalidKeyException('Key must have 6 characters.');
    _key = utf8.encode(key);
  }

  /// Attempts to decrypt [encrypted] with [key].
  /// 
  /// Throws [InvalidKeyException] if [key] is not right for [encrypted].
  String decrypt(String encrypted, String key) {
    parseKey(key);
    try {
      String msg = _convert(encrypted.split(''), _key, 1);
      return utf8.decode(base64.decode(msg));
    } on FormatException {
      throw InvalidKeyException('Could not decrypt: invalid key or message.');
    }
  }
}

void main() {}
