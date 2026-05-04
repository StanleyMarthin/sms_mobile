import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages per-device Ed25519 keypair, payload signing, and registration state.
///
/// Private key never leaves the device.
/// On first launch: devicePublicKey disertakan dalam request agar server bisa pin.
/// Launch berikutnya: hanya signature yang dikirim, public key tidak diulang.
class DeviceSigningService {
  DeviceSigningService();

  static const _privateKeyPref = 'device_ed25519_private_key_b64';
  static const _publicKeyPref  = 'device_ed25519_public_key_b64';
  static const _registeredPref = 'device_ed25519_registered';
  static const _installIdPref = 'device_install_scoped_id';

  final Ed25519 _algorithm = Ed25519();

  Future<_DeviceKeyMaterial> _loadOrCreateKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final privateB64 = prefs.getString(_privateKeyPref);
    final publicB64  = prefs.getString(_publicKeyPref);

    if (privateB64 != null && publicB64 != null) {
      return _DeviceKeyMaterial(
        privateKeyBytes: base64Decode(privateB64),
        publicKeyBytes:  base64Decode(publicB64),
      );
    }

    final keyPair      = await _algorithm.newKeyPair();
    final privateBytes = await keyPair.extractPrivateKeyBytes();
    final publicKey    = await keyPair.extractPublicKey();

    await prefs.setString(_privateKeyPref, base64Encode(privateBytes));
    await prefs.setString(_publicKeyPref,  base64Encode(publicKey.bytes));

    return _DeviceKeyMaterial(
      privateKeyBytes: privateBytes,
      publicKeyBytes:  publicKey.bytes,
    );
  }

  /// True jika server sudah pernah menerima & menyimpan public key device ini.
  Future<bool> isRegistered() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_registeredPref) ?? false;
  }

  /// Panggil setelah server berhasil memverifikasi request pertama.
  Future<void> markRegistered() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_registeredPref, true);
  }

  /// Gunakan saat server merespons DEVICE_NOT_REGISTERED agar request berikutnya
  /// mengirim ulang public key untuk proses pinning.
  Future<void> resetRegistration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_registeredPref, false);
  }

  /// Clear keypair + registration flag. New keys will be generated on next sign.
  Future<void> resetKeyMaterial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_privateKeyPref);
    await prefs.remove(_publicKeyPref);
    await prefs.setBool(_registeredPref, false);
  }

  /// Rotate full device identity for recovery when signature pin is stale.
  ///
  /// This avoids hard lock after app data reset by forcing a fresh deviceId/key pair.
  Future<void> rotateDeviceIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    await resetKeyMaterial();
    await prefs.remove(_installIdPref);
  }

  Future<String> getOrCreateInstallScopedId() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_installIdPref);
    if (stored != null && stored.isNotEmpty) return stored;

    final now = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final rand = Random.secure().nextInt(0x7fffffff).toRadixString(36);
    final generated = '$now$rand';
    await prefs.setString(_installIdPref, generated);
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
      publicKey: SimplePublicKey(keys.publicKeyBytes, type: KeyPairType.ed25519),
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
  const _DeviceKeyMaterial({
    required this.privateKeyBytes,
    required this.publicKeyBytes,
  });

  final List<int> privateKeyBytes;
  final List<int> publicKeyBytes;
}
