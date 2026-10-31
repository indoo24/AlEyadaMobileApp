import 'dart:async';

import 'package:aleyada_mobile/core/auth/token_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Secure storage in memory, whose writes can be held to line up a race.
class _HeldStorage extends Fake implements FlutterSecureStorage {
  final data = <String, String>{};

  /// While set, every write waits for it.
  Completer<void>? writeGate;

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => data[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    final gate = writeGate;
    if (gate != null) await gate.future;
    if (value == null) {
      data.remove(key);
    } else {
      data[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    data.remove(key);
  }
}

void main() {
  late _HeldStorage storage;
  late TokenStore store;

  setUp(() {
    storage = _HeldStorage();
    store = TokenStore(storage: storage);
  });

  /// What the next launch would read back.
  Future<TokenStore> relaunch() async {
    final next = TokenStore(storage: storage);
    await next.load();
    return next;
  }

  test('a sign-out during a save that is still writing leaves nothing on disk', () async {
    await store.save(access: 'a1', refresh: 'r1');
    storage.writeGate = Completer<void>();

    // A refreshed pair starts persisting; the user signs out before it lands.
    final saving = store.updateTokens(access: 'a2', refresh: 'r2');
    final clearing = store.clear();
    storage.writeGate!.complete();
    await Future.wait([saving, clearing]);

    expect(store.hasSession, isFalse);
    expect(storage.data, isEmpty, reason: 'the stale pair must not outlive the sign-out');
    expect((await relaunch()).hasSession, isFalse);
  });

  test('a sign-in during a save that is still writing keeps the new account on disk', () async {
    await store.save(access: 'a1', refresh: 'r1');
    storage.writeGate = Completer<void>();

    final saving = store.updateTokens(access: 'a2', refresh: 'r2');
    final signingIn = store.save(access: 'b-access', refresh: 'b-refresh');
    storage.writeGate!.complete();
    await Future.wait([saving, signingIn]);

    final next = await relaunch();
    expect(next.accessToken, 'b-access');
    expect(next.refreshToken, 'b-refresh');
  });

  test('writes still land in order when nothing races them', () async {
    await store.save(access: 'a1', refresh: 'r1');
    await store.clear();
    await store.save(access: 'a3', refresh: 'r3');

    final next = await relaunch();
    expect(next.accessToken, 'a3');
    expect(next.refreshToken, 'r3');
  });
}
