import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zikirce/core/utils/secure_storage_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final Map<String, String> mockStorage = {};
  bool throwBadPaddingOnRead = false;
  String? readReturnValue;

  setUp(() {
    mockStorage.clear();
    throwBadPaddingOnRead = false;
    readReturnValue = null;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'read':
          if (throwBadPaddingOnRead) {
            throw PlatformException(
              code: 'Exception encountered',
              message: 'read, javax.crypto.BadPaddingException: error:1e000065:Cipher functions:OPENSSL_internal:BAD_DECRYPT',
            );
          }
          if (readReturnValue != null) {
            return readReturnValue;
          }
          final key = methodCall.arguments['key'] as String;
          return mockStorage[key];

        case 'write':
          final key = methodCall.arguments['key'] as String;
          final value = methodCall.arguments['value'] as String;
          mockStorage[key] = value;
          return null;

        case 'delete':
          final key = methodCall.arguments['key'] as String;
          mockStorage.remove(key);
          return null;

        case 'deleteAll':
          mockStorage.clear();
          return null;

        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('SecureStorageHelper.read returns null and does not throw on BadPaddingException', () async {
    throwBadPaddingOnRead = true;
    mockStorage['test_key'] = 'corrupt_cipher';

    final result = await SecureStorageHelper.read('test_key');
    expect(result, isNull);
    // Key should have been wiped on failure
    expect(mockStorage.containsKey('test_key'), isFalse);
  });

  test('SecureStorageHelper.read returns null when native plugin returns "Data has been reset"', () async {
    readReturnValue = 'Data has been reset';

    final result = await SecureStorageHelper.read('test_key');
    expect(result, isNull);
  });

  test('SecureStorageHelper.write and read work properly under normal conditions', () async {
    await SecureStorageHelper.write('my_token', 'abc_xyz_123');
    final result = await SecureStorageHelper.read('my_token');
    expect(result, equals('abc_xyz_123'));
  });

  test('SecureStorageHelper.delete removes item without throwing', () async {
    await SecureStorageHelper.write('token_to_delete', 'val');
    expect(await SecureStorageHelper.read('token_to_delete'), equals('val'));

    await SecureStorageHelper.delete('token_to_delete');
    expect(await SecureStorageHelper.read('token_to_delete'), isNull);
  });
}
