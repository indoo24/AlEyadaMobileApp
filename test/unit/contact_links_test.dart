import 'package:aleyada_mobile/core/utils/contact_links.dart';
import 'package:aleyada_mobile/features/doctors/models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('phone links', () {
    test('plain tel: numbers are allowed, as the API sends them', () {
      for (final ok in [
        'tel:+201014253965',
        'tel:01014253965',
        'tel:16676',
        'tel:+20-101-425-3965',
        'tel:+20.10.1425',
      ]) {
        expect(safePhoneUri(ok)?.toString(), ok, reason: ok);
      }
      expect(safePhoneUri('  tel:+201000000009  ').toString(), 'tel:+201000000009');
    });

    test('other schemes are blocked', () {
      for (final bad in [
        'https://wa.me/201000000009',
        'http://evil.example',
        'javascript:alert(1)',
        'sms:+201000000009',
        'intent://dial#Intent;end',
        'file:///etc/hosts',
        'content://contacts',
        'TELX:+2010',
      ]) {
        expect(safePhoneUri(bad), isNull, reason: bad);
      }
    });

    test('dial codes, extensions, pauses and odd shapes are blocked', () {
      for (final bad in [
        'tel:*#06#', // MMI: shows the IMEI
        'tel:%2A%2306%23', // the same, encoded
        'tel:**21*0100#', // call forwarding
        'tel:+20100;ext=5',
        'tel:+20100,1234',
        'tel:+20100?x=1',
        'tel:+20100#frag',
        'tel://+201000000000',
        'tel:',
        'tel:+',
        'tel:12', // too short to be a number
        'tel:+1234567890123456', // longer than E.164 allows
        'tel:+20 100',
        'tel:-2010',
        'tel:abc',
      ]) {
        expect(safePhoneUri(bad), isNull, reason: bad);
      }
    });

    test('null, empty and garbage are blocked', () {
      for (final bad in [null, '', '   ', ':::', 'tel']) {
        expect(safePhoneUri(bad), isNull, reason: '$bad');
      }
    });
  });

  group('WhatsApp links', () {
    test('https wa.me and api.whatsapp.com are allowed, with their message text', () {
      for (final ok in [
        'https://wa.me/201000000009',
        'https://wa.me/201000000009?text=hi',
        'https://wa.me/01014253965?text=%D8%A7%D9%84%D8%B3%D9%84%D8%A7%D9%85',
        'https://api.whatsapp.com/send?phone=201000000009&text=hi',
        'https://WA.ME/201000000009',
      ]) {
        expect(safeWhatsappUri(ok), isNotNull, reason: ok);
      }
      expect(safeWhatsappUri('https://wa.me/2010?text=hi')!.queryParameters['text'], 'hi');
    });

    test('other schemes, hosts and look-alikes are blocked', () {
      for (final bad in [
        'http://wa.me/201000000009', // not https
        'whatsapp://send?phone=2010',
        'intent://send/2010#Intent;scheme=whatsapp;end',
        'javascript:alert(1)',
        'tel:+201000000009',
        'https://evil.example/wa.me/2010',
        'https://wa.me.evil.example/2010',
        'https://evilwa.me/2010',
        'https://web.whatsapp.com/send?phone=2010',
        'https://whatsapp.com/2010',
        'https://wa.me@evil.example/2010', // the host is evil.example
        'https://user:pass@wa.me/2010',
        'https://wa.me:8443/2010',
        'https://wa.me/2010#frag',
        '//wa.me/2010',
        'wa.me/2010',
        '',
        null,
      ]) {
        expect(safeWhatsappUri(bad), isNull, reason: '$bad');
      }
    });
  });

  test('safeContactUri checks each link for its own channel', () {
    expect(safeContactUri(ContactChannel.phone, 'tel:+201000000009'), isNotNull);
    expect(safeContactUri(ContactChannel.phone, 'https://wa.me/2010'), isNull);
    expect(safeContactUri(ContactChannel.whatsapp, 'https://wa.me/2010'), isNotNull);
    expect(safeContactUri(ContactChannel.whatsapp, 'tel:+201000000009'), isNull);
    expect(ContactChannel.phone.trackingType, 'phone');
    expect(ContactChannel.whatsapp.trackingType, 'whatsapp');
  });

  test('an unsafe link hides the button instead of leaving a dead one', () {
    const unsafe = ContactInfo(telUrl: 'tel:*#06#', whatsappUrl: 'https://evil.example/');
    expect(unsafe.canCall, isFalse);
    expect(unsafe.canWhatsapp, isFalse);
    const safe = ContactInfo(
      telUrl: 'tel:+201000000009',
      whatsappUrl: 'https://wa.me/201000000009',
    );
    expect(safe.canCall, isTrue);
    expect(safe.canWhatsapp, isTrue);
  });

  group('launchContact', () {
    late List<String> launched;

    setUp(() {
      launched = [];
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'launch') launched.add((call.arguments as Map)['url'] as String);
        return true;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    });

    test('opens an allowed link', () async {
      expect(await launchContact(ContactChannel.phone, 'tel:+201000000009'), isTrue);
      expect(await launchContact(ContactChannel.whatsapp, 'https://wa.me/2010?text=hi'), isTrue);
      expect(launched, ['tel:+201000000009', 'https://wa.me/2010?text=hi']);
    });

    test('never hands a blocked link to the system', () async {
      expect(await launchContact(ContactChannel.phone, 'tel:*#06#'), isFalse);
      expect(await launchContact(ContactChannel.phone, 'javascript:alert(1)'), isFalse);
      expect(await launchContact(ContactChannel.whatsapp, 'https://evil.example/x'), isFalse);
      expect(await launchContact(ContactChannel.whatsapp, null), isFalse);
      expect(launched, isEmpty);
    });
  });
}
