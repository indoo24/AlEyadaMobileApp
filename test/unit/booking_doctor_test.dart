import 'package:aleyada_mobile/core/utils/media_url.dart';
import 'package:aleyada_mobile/features/bookings/models.dart';
import 'package:aleyada_mobile/features/bookings/widgets/booking_tile.dart';
import 'package:aleyada_mobile/features/doctors/models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/api_fixtures.dart';
import '../fixtures/doctor_detail_fixtures.dart' as dd;

/// The captured booking, with its nested `doctor` replaced.
PatientBooking bookingWith(Object? doctor, {Map<String, dynamic> top = const {}}) =>
    PatientBooking.fromJson({...bookingData, 'doctor': doctor, ...top});

DoctorDetail profile({Map<String, dynamic> overrides = const {}}) =>
    DoctorDetail.fromJson(dd.publicDoctor(overrides: overrides));

void main() {
  const host = 'https://aleyada.scenariomnchnl.tech';

  group('the doctor in the captured booking payload', () {
    test('slug, display_name and photo parse as before', () {
      final b = PatientBooking.fromJson(bookingData);
      expect(b.doctorName, 'احمد رضا');
      expect(b.doctorSlug, 'ahmed-reda');
      expect(b.doctorPhoto, isNull, reason: 'the captured doctor has no photo');
    });
  });

  group('the doctor\'s name', () {
    test('display_name wins when it has text', () {
      final b = bookingWith({
        'slug': 's',
        'display_name': 'د/ أحمد جمال',
        'full_name_ar': 'أحمد جمال نافع',
        'full_name_en': 'Ahmed Gamal',
      });
      expect(b.doctorName, 'د/ أحمد جمال');
    });

    test('a BLANK display_name falls through to the Arabic name — the bug', () {
      // `display_name ?? full_name_ar` only skipped null; "" hid every fallback and
      // the booking had no doctor name at all.
      final b = bookingWith({'slug': 's', 'display_name': '', 'full_name_ar': 'أحمد جمال'});
      expect(b.doctorName, 'أحمد جمال');
    });

    test('whitespace-only counts as blank', () {
      final b = bookingWith({
        'slug': 's',
        'display_name': '   ',
        'full_name_ar': '\n',
        'full_name_en': 'Ahmed Gamal',
      });
      expect(b.doctorName, 'Ahmed Gamal');
    });

    test('Arabic-only names — empty English fields — are never lost, whatever the UI language', () {
      // The parser is not locale-dependent: an English UI gets the Arabic name
      // rather than an empty one (the public payload sends full_name_en: '').
      final b = bookingWith({
        'slug': 's',
        'display_name': null,
        'full_name_ar': 'دكتور أحمد جمال الصاوي',
        'full_name_en': '',
      });
      expect(b.doctorName, 'دكتور أحمد جمال الصاوي');
    });

    test('only an English name is still a name', () {
      final b = bookingWith({
        'slug': 's',
        'display_name': '',
        'full_name_ar': '',
        'full_name_en': 'Dr Sara',
      });
      expect(b.doctorName, 'Dr Sara');
    });

    test('the name is trimmed', () {
      expect(bookingWith({'slug': 's', 'display_name': '  د. سارة  '}).doctorName, 'د. سارة');
    });

    test('no names at all is an empty string, never "null"', () {
      expect(bookingWith({'slug': 's'}).doctorName, '');
      expect(bookingWith({'slug': 's', 'display_name': null, 'full_name_ar': null}).doctorName, '');
      expect(bookingWith({'slug': 's', 'display_name': 5}).doctorName, '', reason: 'not text');
    });

    test('the flat shape: doctor_name beside no nested doctor', () {
      final b = bookingWith(null, top: {'doctor_name': 'د. خالد', 'doctor_slug': 'khaled'});
      expect(b.doctorName, 'د. خالد');
      expect(b.doctorSlug, 'khaled');
    });

    test('the nested doctor wins over the flat fields', () {
      final b = bookingWith(
        {'slug': 'nested', 'display_name': 'من الكائن'},
        top: {'doctor_name': 'مسطح', 'doctor_slug': 'flat'},
      );
      expect(b.doctorName, 'من الكائن');
      expect(b.doctorSlug, 'nested');
    });

    test('a blank nested name still reaches the flat one', () {
      final b = bookingWith({'slug': 's', 'display_name': ''}, top: {'doctor_name': 'د. خالد'});
      expect(b.doctorName, 'د. خالد');
    });

    test('a doctor that is not an object does not break parsing', () {
      for (final odd in [null, 'a-doctor-id', 7, <dynamic>[]]) {
        final b = bookingWith(odd);
        expect(b.doctorName, '');
        expect(b.doctorSlug, '');
        expect(b.doctorPhoto, isNull);
        expect(b.clinicName, bookingData['clinic'] is Map ? 'طنطا' : '');
      }
    });
  });

  group('the doctor\'s photo', () {
    test('an absolute URL is kept, as the public doctor payload sends them', () {
      final url = '$host/media/doctors/photos/dr-ahmed.webp';
      expect(bookingWith({'slug': 's', 'photo': url}).doctorPhoto, url);
    });

    test('a relative /media path is resolved against the API host', () {
      expect(
        bookingWith({'slug': 's', 'photo': '/media/doctors/photos/dr-ahmed.webp'}).doctorPhoto,
        '$host/media/doctors/photos/dr-ahmed.webp',
      );
    });

    test('blank, null and non-text photos are no photo', () {
      for (final none in [null, '', '   ', 5, <String, dynamic>{}]) {
        expect(bookingWith({'slug': 's', 'photo': none}).doctorPhoto, isNull, reason: '$none');
      }
    });

    test('a photo that is not an http(s) address is dropped', () {
      for (final bad in [
        'javascript:alert(1)',
        'file:///etc/hosts',
        'data:image/png;base64,AAAA',
      ]) {
        expect(bookingWith({'slug': 's', 'photo': bad}).doctorPhoto, isNull, reason: bad);
      }
    });
  });

  group('resolveMediaUrl', () {
    test('absolute http(s) is left alone', () {
      expect(resolveMediaUrl('https://cdn.example/x.webp'), 'https://cdn.example/x.webp');
      expect(resolveMediaUrl('http://cdn.example/x.webp'), 'http://cdn.example/x.webp');
    });

    test('rooted and unrooted paths go to the host\'s root, not under /api/v1', () {
      expect(resolveMediaUrl('/media/a.webp'), '$host/media/a.webp');
      expect(resolveMediaUrl('media/a.webp'), '$host/media/a.webp');
      expect(resolveMediaUrl('/media/ص ورة.webp'), startsWith('$host/media/'));
    });

    test('a protocol-relative URL takes the API\'s scheme', () {
      expect(resolveMediaUrl('//cdn.example/x.webp'), 'https://cdn.example/x.webp');
    });

    test('a local API (emulator) keeps its host and port', () {
      expect(
        resolveMediaUrl('/media/a.webp', base: 'http://10.0.2.2:8000/api/v1'),
        'http://10.0.2.2:8000/media/a.webp',
      );
    });

    test('query strings survive', () {
      expect(resolveMediaUrl('/media/a.webp?v=3'), '$host/media/a.webp?v=3');
    });

    test('nothing, blank, and unsafe schemes resolve to null', () {
      for (final bad in [
        null,
        '',
        '  ',
        'javascript:alert(1)',
        'ftp://x/y.png',
        'file:///a',
        'mailto:a@b.c',
      ]) {
        expect(resolveMediaUrl(bad), isNull, reason: '$bad');
      }
    });

    test('an unusable base resolves nothing relative', () {
      expect(resolveMediaUrl('/media/a.webp', base: 'not a url'), isNull);
      expect(resolveMediaUrl('https://ok.example/a.webp', base: 'not a url'), isNull);
    });
  });

  group('falling back to the doctor\'s public profile', () {
    test('the booking\'s own name is used when it has one', () {
      final b = bookingWith({'slug': 's', 'display_name': 'اسم الحجز'});
      expect(doctorNameOf(b, profile()), 'اسم الحجز');
    });

    test('a blank booking name takes the profile\'s display_name', () {
      final b = bookingWith({'slug': dd.slug, 'display_name': ''});
      expect(doctorNameOf(b, profile()), 'د. سارة محمود');
    });

    test('then the profile\'s Arabic, then English full name', () {
      final b = bookingWith({'slug': dd.slug, 'display_name': ''});
      expect(
        doctorNameOf(b, profile(overrides: {'display_name': '', 'full_name_ar': 'سارة محمود'})),
        'سارة محمود',
      );
      expect(
        doctorNameOf(
          b,
          profile(
            overrides: {'display_name': '', 'full_name_ar': '', 'full_name_en': 'Sara Mahmoud'},
          ),
        ),
        'Sara Mahmoud',
      );
    });

    test('no booking name and no profile is empty — not null, not a placeholder', () {
      final b = bookingWith({'slug': 's'});
      expect(doctorNameOf(b, null), '');
      expect(
        doctorNameOf(
          b,
          profile(overrides: {'display_name': '', 'full_name_ar': '', 'full_name_en': ''}),
        ),
        '',
      );
    });

    test('the photo: the booking\'s, else the profile\'s, else none', () {
      final own = bookingWith({'slug': 's', 'photo': '/media/own.webp'});
      expect(
        doctorPhotoOf(own, profile(overrides: {'photo': '$host/media/theirs.webp'})),
        '$host/media/own.webp',
      );

      final bare = bookingWith({'slug': 's', 'photo': ''});
      expect(
        doctorPhotoOf(bare, profile(overrides: {'photo': '$host/media/theirs.webp'})),
        '$host/media/theirs.webp',
      );
      expect(
        doctorPhotoOf(bare, profile(overrides: {'photo': '/media/rel.webp'})),
        '$host/media/rel.webp',
      );
      expect(doctorPhotoOf(bare, profile()), isNull);
      expect(doctorPhotoOf(bare, null), isNull);
    });
  });
}
