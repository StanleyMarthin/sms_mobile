import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import 'app_secure_storage.dart';

/// Manages per-device Ed25519 keypair, payload signing, and registration state.
///
/// Private key never leaves the device.
/// On first launch: devicePublicKey disertakan dalam request agar server bisa pin.
/// Launch berikutnya: hanya signature yang dikirim, public key tidak diulang.
class DeviceSigningService {
  DeviceSigningService({this.storage = AppSecureStorage.instance});

  static final _privateKeyPref = 'device_ed25519_private_key_b64';
  static final _publicKeyPref = 'device_ed25519_public_key_b64';
  static final _registeredPref = 'device_ed25519_registered';
  static final _installIdPref = 'device_install_scoped_id';

  final Ed25519 _algorithm = Ed25519();
  final dynamic storage;

  Future<_DeviceKeyMaterial> _loadOrCreateKeys() async {
    final privateB64 = await storage.read(key: _privateKeyPref);
    final publicB64 = await storage.read(key: _publicKeyPref);

    if (privateB64 != null && publicB64 != null) {
      return _DeviceKeyMaterial(
        privateKeyBytes: base64Decode(privateB64),
        publicKeyBytes: base64Decode(publicB64),
      );
    }

    final keyPair = await _algorithm.newKeyPair();
    final privateBytes = await keyPair.extractPrivateKeyBytes();
    final publicKey = await keyPair.extractPublicKey();

    await storage.write(
      key: _privateKeyPref,
      value: base64Encode(privateBytes),
    );
    await storage.write(
      key: _publicKeyPref,
      value: base64Encode(publicKey.bytes),
    );

    return _DeviceKeyMaterial(
      privateKeyBytes: privateBytes,
      publicKeyBytes: publicKey.bytes,
    );
  }

  /// True jika server sudah pernah menerima & menyimpan public key device ini.
  Future<bool> isRegistered() async {
    return (await storage.read(key: _registeredPref)) == 'true';
  }

  /// Panggil setelah server berhasil memverifikasi request pertama.
  Future<void> markRegistered() async {
    await storage.write(key: _registeredPref, value: 'true');
  }

  /// Gunakan saat server merespons DEVICE_NOT_REGISTERED agar request berikutnya
  /// mengirim ulang public key untuk proses pinning.
  Future<void> resetRegistration() async {
    await storage.write(key: _registeredPref, value: 'false');
  }

  /// Clear keypair + registration flag. New keys will be generated on next sign.
  Future<void> resetKeyMaterial() async {
    await storage.delete(key: _privateKeyPref);
    await storage.delete(key: _publicKeyPref);
    await storage.write(key: _registeredPref, value: 'false');
  }

  /// Rotate full device identity for recovery when signature pin is stale.
  ///
  /// This avoids hard lock after app data reset by forcing a fresh deviceId/key pair.
  Future<void> rotateDeviceIdentity() async {
    await resetKeyMaterial();
    await storage.delete(key: _installIdPref);
  }

  Future<String> getOrCreateInstallScopedId() async {
    final stored = await storage.read(key: _installIdPref);
    if (stored != null && stored.isNotEmpty) return stored;

    final now = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final rand = Random.secure().nextInt(0x7fffffff).toRadixString(36);
    final generated = '$now$rand';
    await storage.write(key: _installIdPref, value: generated);
    return generated;
  }

  /// Build resilient device identity.
  ///
  /// `androidId` can stay stable across reinstalls, so we append an install-scoped
  /// segment to prevent public-key pin collisions after app data wipe.
  Future<String> buildDeviceIdentity({String? androidId}) async {
    final installId = await getOrCreateInstallScopedId();
    final normalizedAndroidId = (androidId ?? '').trim();
    if (normalizedAndroidId.isEmpty) {
      return 'fallback:$installId';
    }
    return '$normalizedAndroidId:$installId';
  }

  /// Buat payload untuk /auth/device-init.
  /// - Jika belum registered: sertakan devicePublicKey agar server bisa pin.
  /// - Jika sudah: hanya signature.
  Future<Map<String, String?>> buildDeviceInitExtra({
    required String deviceId,
    required String appVersion,
    required String timestamp,
  }) async {
    final keys = await _loadOrCreateKeys();
    final keyPair = SimpleKeyPairData(
      keys.privateKeyBytes,
      type: KeyPairType.ed25519,
      publicKey:
          SimplePublicKey(keys.publicKeyBytes, type: KeyPairType.ed25519),
    );
    final sig = await _algorithm.sign(
      utf8.encode('$deviceId|$appVersion|$timestamp'),
      keyPair: keyPair,
    );

    final registered = await isRegistered();
    return {
      'eddsaSignature': base64Encode(sig.bytes),
      'devicePublicKey': registered ? null : base64Encode(keys.publicKeyBytes),
    };
  }
}

class _DeviceKeyMaterial {
  _DeviceKeyMaterial({
    required this.privateKeyBytes,
    required this.publicKeyBytes,
  });

  final List<int> privateKeyBytes;
  final List<int> publicKeyBytes;
}
