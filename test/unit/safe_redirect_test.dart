import 'package:aleyada_mobile/app/safe_redirect.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('safeNextLocation', () {
    test('accepts the app\'s own locations, query strings included', () {
      for (final ok in [
        '/',
        '/bookings',
        '/bookings/b1',
        '/bookings/3f2a9c1e-0000-4000-8000-000000000001',
        '/doctors/dr-sara',
        '/doctors?focus=1',
        '/account/edit',
        '/doctors/%D8%B3%D8%A7%D8%B1%D8%A9', // an encoded Arabic slug
      ]) {
        expect(safeNextLocation(ok), ok, reason: ok);
      }
    });

    test('rejects anything that leaves the app', () {
      for (final bad in [
        'https://evil.example/x',
        'http://evil.example',
        'javascript:alert(1)',
        'tel:+201000000000',
        'intent://x#Intent;end',
        '//evil.example/x', // protocol-relative
        '///evil.example',
        r'/\evil.example', // a backslash is a slash to many URL parsers
        r'\\evil.example',
        r'/doctors\..\x',
      ]) {
        expect(safeNextLocation(bad), isNull, reason: bad);
      }
    });

    test('rejects relative, empty and malformed values', () {
      for (final bad in [
        null,
        '',
        'bookings/b1', // no leading slash
        ' /bookings', // leading whitespace
        '/bookings /b1',
        '/bookings\n/b1',
        '/bookings\t',
        '/bookings\u0000',
        '/bookings#frag',
        '/a%zz', // broken escape
        '/${'a' * 600}', // absurdly long
      ]) {
        expect(safeNextLocation(bad), isNull, reason: '$bad');
      }
    });

    test('rejects dot segments, encoded or not', () {
      for (final bad in [
        '/bookings/../account',
        '/./bookings',
        '/bookings/%2e%2e/x',
        '/bookings/%2E%2E',
        '/a/%2F/b',
      ]) {
        expect(safeNextLocation(bad), isNull, reason: bad);
      }
    });

    test('never resumes into the sign-in flow itself', () {
      for (final loop in [
        '/sign-in',
        '/sign-in/',
        '/sign-in?next=%2Fbookings',
        '/sign-up',
        '/verify?phone=1',
        '/splash',
        '/consent',
      ]) {
        expect(safeNextLocation(loop), isNull, reason: loop);
      }
    });
  });

  group('resumeLocation', () {
    test('a guest who was never signed in resumes their own destination', () {
      expect(
        resumeLocation('/bookings', endedAccountId: null, signedInAccountId: 'B'),
        '/bookings',
      );
    });

    test('the account whose session ended resumes it', () {
      expect(
        resumeLocation('/bookings/b1', endedAccountId: 'A', signedInAccountId: 'A'),
        '/bookings/b1',
      );
    });

    test('a different account does not inherit it', () {
      expect(resumeLocation('/bookings/b1', endedAccountId: 'A', signedInAccountId: 'B'), isNull);
      expect(resumeLocation('/bookings/b1', endedAccountId: 'A', signedInAccountId: null), isNull);
    });

    test('an unsafe value is refused whoever signs in', () {
      expect(
        resumeLocation('//evil.example', endedAccountId: null, signedInAccountId: 'A'),
        isNull,
      );
      expect(
        resumeLocation('https://evil.example', endedAccountId: 'A', signedInAccountId: 'A'),
        isNull,
      );
    });
  });
}
