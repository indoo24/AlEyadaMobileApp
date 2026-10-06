import 'package:aleyada_mobile/features/profile/doctor_profile_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/doctor_profile_fixtures.dart';

void main() {
  DoctorOwnProfile profile([Map<String, dynamic> overrides = const {}]) =>
      DoctorOwnProfile(ownProfile(overrides: overrides));

  group('parsing the API response', () {
    test('every API-backed field is read as sent', () {
      final p = profile();
      expect(p.id, 'profile-1');
      expect(p.text('full_name_ar'), 'نرمين أحمد فؤاد');
      expect(p.text('full_name_en'), 'Nermeen Ahmed Fouad');
      expect(p.text('display_title'), 'د.');
      expect(p.gender, 'female');
      expect(p.yearsOfExperience, 10);
      expect(p.defaultFee, '160.00');
      expect(p.text('professional_title_ar'), 'أخصائية أمراض النساء والتوليد وعلاج العقم');
      expect(p.text('academic_degree_ar'), 'ماجستير طب النساء والتوليد');
      expect(p.text('phone'), '+201010636122');
      expect(p.verificationStatus, 'approved');
      expect(p.isPublished, isTrue);
      expect(p.avgRating, '4.60');
      expect(p.reviewsCount, 5);
      expect(p.cityId, cityId);
      expect(p.areaId, areaId);
    });

    test('specialties, with the primary one marked', () {
      final specs = profile().specializations;
      expect(specs.map((s) => s.nameAr), ['أمراض النساء والتوليد', 'علاج العقم']);
      expect(specs.first.isPrimary, isTrue);
      expect(specs.last.isPrimary, isFalse);
    });

    test('social links keep only the networks that have an address', () {
      expect(profile().socialLinks, {
        'facebook': 'https://www.facebook.com/share/18DXiV3Cig/',
        'instagram': 'https://www.instagram.com/nenoelwakeel/',
      });
    });

    test('editable and credential fields come from the server', () {
      final p = profile({
        'editable_fields': ['bio_ar', 'phone'],
        'credential_fields': ['full_name_ar'],
      });
      expect(p.editableFields, {'bio_ar', 'phone'});
      expect(p.credentialFields, {'full_name_ar'});
      expect(p.canEdit('bio_ar'), isTrue);
      expect(p.canEdit('bio_en'), isFalse);
    });

    test('valueOf gives the text a form would show', () {
      final p = profile();
      expect(p.valueOf('years_of_experience'), '10');
      expect(p.valueOf('default_consultation_fee'), '160.00');
      expect(p.valueOf('facebook'), 'https://www.facebook.com/share/18DXiV3Cig/');
      expect(p.valueOf('tiktok'), '');
      expect(p.valueOf('bio_ar'), 'أخصائية أمراض النساء والتوليد والعقم.');
    });
  });

  group('missing, null and empty data', () {
    test('an empty response is all empties — never the word "null"', () {
      const p = DoctorOwnProfile({});
      for (final f in profileFields) {
        expect(p.valueOf(f.key), '', reason: f.key);
      }
      expect(p.photo, isNull);
      expect(p.yearsOfExperience, isNull);
      expect(p.defaultFee, isNull);
      expect(p.socialLinks, isEmpty);
      expect(p.specializations, isEmpty);
      expect(p.editableFields, isEmpty);
      expect(p.credentialFields, isEmpty);
      expect(p.isPublished, isFalse);
      expect(p.reviewsCount, 0);
      expect(p.cityId, isNull);
    });

    test('nulls in nullable fields are empty, not text', () {
      final p = profile({
        'years_of_experience': null,
        'default_consultation_fee': null,
        'photo': null,
        'city': null,
        'area': null,
        'bio_ar': null,
        'social_links': null,
        'specializations': null,
      });
      expect(p.valueOf('years_of_experience'), '');
      expect(p.valueOf('default_consultation_fee'), '');
      expect(p.valueOf('bio_ar'), '');
      expect(p.socialLinks, isEmpty);
      expect(p.specializations, isEmpty);
      expect(p.cityId, isNull);
    });

    test('whitespace-only text counts as empty', () {
      expect(profile({'bio_ar': '   \n '}).valueOf('bio_ar'), '');
    });

    test('social links in an unexpected shape are ignored, not crashed on', () {
      expect(profile({'social_links': 'facebook.com/x'}).socialLinks, isEmpty);
      expect(profile({'social_links': ['a']}).socialLinks, isEmpty);
      expect(profile({'social_links': {'facebook': 5, 'instagram': '  '}}).socialLinks, isEmpty);
    });

    test('a specialty with no name is dropped', () {
      final specs = profile({
        'specializations': [
          {'id': 'x', 'slug': 'x'},
          {'id': 'y', 'slug': 'y', 'name_ar': 'جلدية'},
        ],
      }).specializations;
      expect(specs.map((s) => s.slug), ['y']);
    });
  });

  group('which fields exist', () {
    test('the table is exactly what PATCH /doctor/profile/ accepts — nothing invented', () {
      // Straight from the spec's PatchedDoctorProfileUpdateRequest, less `photo`
      // (a binary upload the app does not offer) and `gender` (the spec allows
      // only a blank value there).
      const specKeys = {
        'academic_degree_ar',
        'bio_ar',
        'bio_en',
        'certifications_ar',
        'current_positions_ar',
        'default_consultation_fee',
        'display_title',
        'external_booking_url',
        'fellowships_ar',
        'full_name_ar',
        'full_name_en',
        'google_maps_url',
        'past_positions_ar',
        'phone',
        'professional_title_ar',
        'professional_title_en',
        'seo_description',
        'seo_title',
        'vision_ar',
        'website',
        'whatsapp',
        'years_of_experience',
        'facebook',
        'instagram',
        'linkedin',
        'youtube',
        'tiktok',
      };
      expect(profileFields.map((f) => f.key).toSet(), specKeys);
      expect(profileFields.map((f) => f.key).toSet().length, profileFields.length, reason: 'no duplicates');
    });

    test('limits are the spec\'s', () {
      int? max(String k) => profileFields.firstWhere((f) => f.key == k).maxLength;
      expect(max('full_name_ar'), 150);
      expect(max('display_title'), 20);
      expect(max('professional_title_ar'), 200);
      expect(max('academic_degree_ar'), 100);
      expect(max('phone'), 20);
      expect(max('seo_title'), 70);
      expect(max('seo_description'), 160);
    });
  });

  group('who may edit what', () {
    final bio = profileFields.firstWhere((f) => f.key == 'bio_ar');
    final facebook = profileFields.firstWhere((f) => f.key == 'facebook');

    test('only what the server lists as editable', () {
      final p = profile({'editable_fields': ['phone']});
      expect(isEditable(p, profileFields.firstWhere((f) => f.key == 'phone')), isTrue);
      expect(isEditable(p, bio), isFalse);
    });

    test('a social network is editable when social_links is', () {
      expect(isEditable(profile({'editable_fields': ['social_links']}), facebook), isTrue);
      expect(isEditable(profile({'editable_fields': ['bio_ar']}), facebook), isFalse);
    });

    test('nothing is editable when the server lists nothing', () {
      final p = profile({'editable_fields': <String>[]});
      expect(profileFields.where((f) => isEditable(p, f)), isEmpty);
    });

    test('credential fields are the ones held for review', () {
      final p = profile({'credential_fields': ['full_name_ar', 'social_links']});
      expect(isCredential(p, profileFields.firstWhere((f) => f.key == 'full_name_ar')), isTrue);
      expect(isCredential(p, bio), isFalse);
      expect(isCredential(p, facebook), isTrue);
    });

    test('a draft profile has no credential fields', () {
      final p = profile({'verification_status': 'draft', 'credential_fields': <String>[]});
      expect(profileFields.where((f) => isCredential(p, f)), isEmpty);
    });
  });

  group('the update body', () {
    final p = profile();

    test('only changed fields are sent', () {
      final body = buildProfilePatch(p, {
        'bio_ar': p.valueOf('bio_ar'),
        'phone': '+201000000000',
        'whatsapp': p.valueOf('whatsapp'),
      });
      expect(body, {'phone': '+201000000000'});
    });

    test('nothing changed, nothing sent', () {
      expect(buildProfilePatch(p, {for (final f in profileFields) f.key: p.valueOf(f.key)}), isEmpty);
    });

    test('text is trimmed, and clearing a text field sends an empty string', () {
      expect(buildProfilePatch(p, {'bio_ar': '  جديد  '}), {'bio_ar': 'جديد'});
      expect(buildProfilePatch(p, {'bio_ar': ''}), {'bio_ar': ''});
    });

    test('numbers go as numbers; clearing one sends null', () {
      expect(buildProfilePatch(p, {'years_of_experience': '12'}), {'years_of_experience': 12});
      expect(buildProfilePatch(p, {'years_of_experience': ''}), {'years_of_experience': null});
      expect(buildProfilePatch(p, {'default_consultation_fee': '200'}), {'default_consultation_fee': '200'});
      expect(buildProfilePatch(p, {'default_consultation_fee': ''}), {'default_consultation_fee': null});
    });

    test('a social network goes under its own key', () {
      expect(buildProfilePatch(p, {'youtube': 'https://youtube.com/x'}), {'youtube': 'https://youtube.com/x'});
      expect(buildProfilePatch(p, {'facebook': ''}), {'facebook': ''});
    });

    test('an unknown field is never sent', () {
      expect(buildProfilePatch(p, {'slug': 'hacked', 'is_published': 'true', 'verification_status': 'approved'}), isEmpty);
    });

    test('typed numbers are checked before anything is sent', () {
      expect(validateProfileDrafts({'years_of_experience': '12'}), isEmpty);
      expect(validateProfileDrafts({'years_of_experience': '1.5'}), {'years_of_experience': ProfileInputError.notANumber});
      expect(validateProfileDrafts({'years_of_experience': 'abc'}), isNotEmpty);
      expect(validateProfileDrafts({'default_consultation_fee': '12.50'}), isEmpty);
      expect(validateProfileDrafts({'default_consultation_fee': '1.2.3'}), isNotEmpty);
      expect(validateProfileDrafts({'default_consultation_fee': ''}), isEmpty, reason: 'blank clears it');
    });
  });

  group('the doctor\'s own lists', () {
    test('education', () {
      final e = EducationItem.fromJson({
        'degree_ar': ' بكالوريوس ',
        'institution_ar': 'جامعة بنها',
        'year': 2012,
      });
      expect((e.degreeAr, e.institutionAr, e.year), ('بكالوريوس', 'جامعة بنها', 2012));
      expect(e.degreeEn, '');
    });

    test('certificates and services', () {
      final c = CertificateItem.fromJson({'title_ar': 'زمالة', 'issuer': 'المجلس', 'year': null, 'is_public': true});
      expect((c.titleAr, c.issuer, c.year, c.isPublic), ('زمالة', 'المجلس', null, true));
      final s = ServiceItem.fromJson({'name_ar': 'متابعة', 'price': '250.00', 'is_active': false});
      expect((s.nameAr, s.price, s.isActive), ('متابعة', '250.00', false));
      expect(ServiceItem.fromJson({'name_ar': 'x', 'price': null}).price, isNull);
    });
  });
}
