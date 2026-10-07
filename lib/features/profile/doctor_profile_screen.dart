import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/router.dart';
import '../../core/api/api_error.dart';
import '../../core/errors/error_messages.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/form_fields.dart';
import '../../l10n/app_localizations.dart';
import '../doctors/models.dart';
import '../doctors/providers.dart';
import '../doctors/widgets/doctor_card_tile.dart';
import '../doctors/widgets/doctor_rating.dart';
import '../home/home_style.dart';
import '../management/management_widgets.dart';
import 'doctor_profile_models.dart';
import 'doctor_profile_providers.dart';

/// The label for one of the profile's fields.
String profileFieldLabel(L l, String key) => switch (key) {
  'full_name_ar' => l.dpField_full_name_ar,
  'full_name_en' => l.dpField_full_name_en,
  'display_title' => l.dpField_display_title,
  'gender' => l.dpField_gender,
  'city' => l.dpField_city,
  'area' => l.dpField_area,
  'professional_title_ar' => l.dpField_professional_title_ar,
  'professional_title_en' => l.dpField_professional_title_en,
  'academic_degree_ar' => l.dpField_academic_degree_ar,
  'years_of_experience' => l.dpField_years_of_experience,
  'default_consultation_fee' => l.dpField_default_consultation_fee,
  'bio_ar' => l.dpField_bio_ar,
  'bio_en' => l.dpField_bio_en,
  'vision_ar' => l.dpField_vision_ar,
  'current_positions_ar' => l.dpField_current_positions_ar,
  'past_positions_ar' => l.dpField_past_positions_ar,
  'certifications_ar' => l.dpField_certifications_ar,
  'fellowships_ar' => l.dpField_fellowships_ar,
  'phone' => l.dpField_phone,
  'whatsapp' => l.dpField_whatsapp,
  'website' => l.dpField_website,
  'external_booking_url' => l.dpField_external_booking_url,
  'google_maps_url' => l.dpField_google_maps_url,
  'facebook' => l.dpField_facebook,
  'instagram' => l.dpField_instagram,
  'linkedin' => l.dpField_linkedin,
  'youtube' => l.dpField_youtube,
  'tiktok' => l.dpField_tiktok,
  'seo_title' => l.dpField_seo_title,
  'seo_description' => l.dpField_seo_description,
  _ => key,
};

String _sectionTitle(L l, ProfileSection s) => switch (s) {
  ProfileSection.basic => l.dpSectionBasic,
  ProfileSection.professional => l.dpSectionProfessional,
  ProfileSection.biography => l.dpSectionBio,
  ProfileSection.experience => l.dpSectionExperience,
  ProfileSection.qualifications => l.dpSectionQualifications,
  ProfileSection.contact => l.dpSectionContact,
  ProfileSection.links => l.dpSectionLinks,
  ProfileSection.search => l.dpSectionSearch,
};

/// The approved doctor's own professional profile.
///
/// Everything shown comes from `GET /doctor/profile/` (plus the doctor's own
/// education, certificates and services lists). A field the response does not
/// carry, or carries empty, is not shown — and not offered for editing unless the
/// server lists it in `editable_fields`.
class DoctorProfileScreen extends ConsumerWidget {
  const DoctorProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final profile = ref.watch(doctorOwnProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(l.dpTitle)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(doctorOwnProfileProvider)
            ..invalidate(doctorEducationProvider)
            ..invalidate(doctorCertificatesProvider)
            ..invalidate(doctorServicesProvider)
            ..invalidate(doctorRejectionReasonProvider);
          await ref.read(doctorOwnProfileProvider.future).then((_) {}, onError: (_) {});
        },
        child: AsyncValueView<DoctorOwnProfile>(
          value: profile,
          onRetry: () => ref.invalidate(doctorOwnProfileProvider),
          loading: const _Loading(),
          // Re-keyed when the server's data changes, so a save (or a refresh that
          // picked up an edit made elsewhere) resets the form to what is stored.
          data: (p) => _ProfileBody(key: ValueKey(p.json.toString().hashCode), profile: p),
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => ListView(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(AppSpacing.gutter),
    children: const [
      Skeleton(height: 150, radius: homeCardRadius),
      SizedBox(height: HomeSpacing.card),
      Skeleton(height: 200, radius: homeCardRadius),
      SizedBox(height: HomeSpacing.card),
      Skeleton(height: 120, radius: homeCardRadius),
    ],
  );
}

class _ProfileBody extends ConsumerStatefulWidget {
  const _ProfileBody({super.key, required this.profile});

  final DoctorOwnProfile profile;

  @override
  ConsumerState<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends ConsumerState<_ProfileBody> {
  late final Map<String, TextEditingController> _controllers = {
    for (final f in profileFields)
      if (isEditable(widget.profile, f)) f.key: TextEditingController(text: widget.profile.valueOf(f.key)),
  };

  bool _editing = false;
  bool _busy = false;
  String? _error;
  Map<String, String> _errors = const {};

  DoctorOwnProfile get _p => widget.profile;

  /// Whether there is anything to edit at all.
  bool get _canEdit => _controllers.isNotEmpty;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _cancel() {
    for (final e in _controllers.entries) {
      e.value.text = _p.valueOf(e.key);
    }
    setState(() {
      _editing = false;
      _errors = const {};
      _error = null;
    });
  }

  Future<void> _save() async {
    final l = L.of(context);
    final drafts = {for (final e in _controllers.entries) e.key: e.value.text};

    final local = validateProfileDrafts(drafts);
    if (local.isNotEmpty) {
      setState(() => _errors = {for (final k in local.keys) k: l.dpInvalidNumber});
      return;
    }
    final patch = buildProfilePatch(_p, drafts);
    if (patch.isEmpty) {
      setState(() => _editing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.dpNothingChanged)));
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context);
    final repo = ref.read(doctorProfileRepositoryProvider);
    final staged = profileFields.any((f) => patch.containsKey(f.key) && isCredential(_p, f));

    setState(() {
      _busy = true;
      _error = null;
      _errors = const {};
    });
    try {
      await repo.update(patch);
      // The response body is undeclared; read the profile back instead.
      await container.refresh(doctorOwnProfileProvider.future);
      await container.read(authControllerProvider.notifier).refreshUser();
      messenger.showSnackBar(SnackBar(content: Text(staged ? '${l.dpSaved}. ${l.dpSentForReview}' : l.dpSaved)));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errors = e.fieldErrors;
        _error = e.fieldErrors.isEmpty ? messageForError(context, e) : null;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, HomeSpacing.top, AppSpacing.gutter, AppSpacing.xl),
      children: [
        _Header(profile: _p),
        const SizedBox(height: HomeSpacing.card),
        if (_canEdit)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: _editing
                ? TextButton.icon(
                    onPressed: _busy ? null : _cancel,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: Text(l.actionCancel),
                  )
                : FilledButton.icon(
                    onPressed: () => setState(() => _editing = true),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text(l.dpEdit),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      textStyle: HomeType.button,
                    ),
                  ),
          ),
        if (_error != null) ...[
          const SizedBox(height: HomeSpacing.card),
          FormErrorBanner(message: _error),
        ],
        for (final section in ProfileSection.values) ..._section(context, section),
        const _ExtraLists(),
        const SizedBox(height: HomeSpacing.card),
        _AccountTile(),
        if (_editing) ...[
          const SizedBox(height: HomeSpacing.section),
          MgmtSaveButton(label: l.actionSave, saving: _busy, onPressed: _save),
        ],
      ],
    );
  }

  /// One section's card, or nothing when it has nothing to show.
  List<Widget> _section(BuildContext context, ProfileSection section) {
    final l = L.of(context);
    final rows = <Widget>[];

    for (final f in profileFields.where((f) => f.section == section)) {
      final controller = _controllers[f.key];
      final value = _p.valueOf(f.key);
      if (_editing && controller != null) {
        rows.add(_EditField(
          field: f,
          label: profileFieldLabel(l, f.key),
          controller: controller,
          enabled: !_busy,
          errorText: _errors[f.key],
          reviewNote: isCredential(_p, f) ? l.dpReviewNote : null,
        ));
      } else if (value.isNotEmpty) {
        rows.add(_ReadRow(field: f, label: profileFieldLabel(l, f.key), value: value));
      }
    }

    // Read-only facts that belong to a section but are not editable.
    rows.addAll(_extras(context, section));
    if (rows.isEmpty) return const [];

    return [
      const SizedBox(height: HomeSpacing.section),
      _SectionCard(title: _sectionTitle(l, section), children: rows),
    ];
  }

  List<Widget> _extras(BuildContext context, ProfileSection section) {
    final l = L.of(context);
    final english = Localizations.localeOf(context).languageCode == 'en';
    final out = <Widget>[];

    if (section == ProfileSection.basic) {
      final gender = switch (_p.gender) {
        'male' => l.doctorsFilterMale,
        'female' => l.doctorsFilterFemale,
        _ => '',
      };
      if (gender.isNotEmpty) out.add(_ReadRow(label: profileFieldLabel(l, 'gender'), value: gender));

      // City and area arrive as ids; show them only once they can be named.
      final cities = ref.watch(citiesProvider).valueOrNull ?? const <City>[];
      final city = cities.where((c) => c.id == _p.cityId).firstOrNull;
      final area = city?.areas.where((a) => a.id == _p.areaId).firstOrNull;
      if (city != null) {
        out.add(_ReadRow(label: profileFieldLabel(l, 'city'), value: english && city.nameEn.isNotEmpty ? city.nameEn : city.nameAr));
      }
      if (area != null) {
        out.add(_ReadRow(label: profileFieldLabel(l, 'area'), value: english && area.nameEn.isNotEmpty ? area.nameEn : area.nameAr));
      }
    }

    if (section == ProfileSection.professional) {
      final specs = _p.specializations;
      if (specs.isNotEmpty) {
        out.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.dpSpecializations, style: HomeType.meta),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in specs)
                      MgmtBadge(
                        label: (english && s.nameEn.isNotEmpty ? s.nameEn : s.nameAr) +
                            (s.isPrimary == true ? ' · ${l.dpPrimarySpec}' : ''),
                        color: s.isPrimary == true ? AppColors.primary : AppColors.muted,
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      }
    }
    return out;
  }
}

// ---------------------------------------------------------------------------
// Header and status
// ---------------------------------------------------------------------------

class _Header extends ConsumerWidget {
  const _Header({required this.profile});

  final DoctorOwnProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final english = Localizations.localeOf(context).languageCode == 'en';
    final nameAr = profile.text('full_name_ar');
    final nameEn = profile.text('full_name_en');
    final showEnglishName = english && nameEn.isNotEmpty;
    final name = showEnglishName ? nameEn : (nameAr.isNotEmpty ? nameAr : nameEn);
    final title = profile.text('display_title');
    final job = english && profile.text('professional_title_en').isNotEmpty
        ? profile.text('professional_title_en')
        : profile.text('professional_title_ar');
    final status = profile.verificationStatus;

    final (statusLabel, statusColor) = switch (status) {
      'approved' => (l.dpStatusApproved, AppColors.success),
      'pending_review' => (l.dpStatusPending, AppColors.star),
      'rejected' => (l.dpStatusRejected, AppColors.danger),
      'draft' => (l.dpStatusDraft, AppColors.muted),
      _ => ('', AppColors.muted),
    };
    final rejection = status == 'rejected' ? ref.watch(doctorRejectionReasonProvider).valueOrNull : null;

    return MgmtCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DoctorAvatar(photo: profile.photo, name: name, size: 76, radius: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (name.isNotEmpty)
                      Text(
                        // `display_title` is the Arabic prefix ("د."); it only belongs
                        // with the Arabic name.
                        showEnglishName || title.isEmpty || name.startsWith(title) ? name : '$title $name',
                        style: HomeType.doctorName.copyWith(fontSize: 17),
                      ),
                    if (job.isNotEmpty) Text(job, style: HomeType.doctorSpecialty),
                    const SizedBox(height: 4),
                    DoctorRating.values(avgRating: profile.avgRating, reviewsCount: profile.reviewsCount),
                  ],
                ),
              ),
            ],
          ),
          if (statusLabel.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                MgmtBadge(label: statusLabel, color: statusColor),
                Text(
                  profile.isPublished ? l.dashboardPublished : l.dashboardNotPublished,
                  style: HomeType.meta,
                ),
              ],
            ),
          ],
          if (rejection != null) ...[
            const SizedBox(height: 8),
            Text('${l.dpRejectionReason}: $rejection', style: HomeType.meta.copyWith(color: AppColors.danger)),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rows and cards
// ---------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => MgmtCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: HomeType.sectionTitle),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );
}

/// A label and its value. Web addresses are tappable.
class _ReadRow extends StatelessWidget {
  const _ReadRow({this.field, required this.label, required this.value});

  final ProfileField? field;
  final String label;
  final String value;

  Uri? get _link {
    if (field?.kind != ProfileFieldKind.url) return null;
    final u = Uri.tryParse(value);
    return u != null && u.host.isNotEmpty && (u.scheme == 'https' || u.scheme == 'http') ? u : null;
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final link = _link;
    final latin = field?.isLatin ?? false;

    Widget text = Text(
      value,
      textDirection: latin ? TextDirection.ltr : null,
      style: HomeType.doctorSpecialty.copyWith(
        fontSize: 14,
        color: link != null ? AppColors.primary : AppColors.ink,
      ),
    );
    if (link != null) {
      text = InkWell(
        onTap: () async {
          final messenger = ScaffoldMessenger.of(context);
          var opened = false;
          try {
            opened = await launchUrl(link, mode: LaunchMode.externalApplication);
          } catch (_) {}
          if (!opened) messenger.showSnackBar(SnackBar(content: Text(l.dpLinkFailed)));
        },
        child: Semantics(link: true, hint: l.dpOpenLink, child: text),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: HomeType.meta),
          const SizedBox(height: 2),
          Align(alignment: AlignmentDirectional.centerStart, child: text),
        ],
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  const _EditField({
    required this.field,
    required this.label,
    required this.controller,
    required this.enabled,
    this.errorText,
    this.reviewNote,
  });

  final ProfileField field;
  final String label;
  final TextEditingController controller;
  final bool enabled;
  final String? errorText;
  final String? reviewNote;

  @override
  Widget build(BuildContext context) {
    final multiline = field.kind == ProfileFieldKind.multiline;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppTextField(
        label: label,
        controller: controller,
        enabled: enabled,
        errorText: errorText,
        helper: reviewNote,
        forceLtr: field.isLatin,
        maxLines: multiline ? 6 : 1,
        minLines: multiline ? 3 : null,
        keyboardType: switch (field.kind) {
          ProfileFieldKind.integer => TextInputType.number,
          ProfileFieldKind.money => const TextInputType.numberWithOptions(decimal: true),
          ProfileFieldKind.phone => TextInputType.phone,
          ProfileFieldKind.url => TextInputType.url,
          ProfileFieldKind.multiline => TextInputType.multiline,
          ProfileFieldKind.text => TextInputType.text,
        },
        inputFormatters: [
          if (field.kind == ProfileFieldKind.integer) FilteringTextInputFormatter.digitsOnly,
          if (field.kind == ProfileFieldKind.money) FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          if (field.maxLength != null) LengthLimitingTextInputFormatter(field.maxLength),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The doctor's own lists (read-only)
// ---------------------------------------------------------------------------

class _ExtraLists extends ConsumerWidget {
  const _ExtraLists();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final english = Localizations.localeOf(context).languageCode == 'en';
    String pick(String ar, String en) => english && en.isNotEmpty ? en : (ar.isNotEmpty ? ar : en);

    final education = ref.watch(doctorEducationProvider);
    final certificates = ref.watch(doctorCertificatesProvider);
    final services = ref.watch(doctorServicesProvider);

    return Column(
      children: [
        _AsyncCard<EducationItem>(
          title: l.dpEducationTitle,
          value: education,
          onRetry: () => ref.invalidate(doctorEducationProvider),
          rowBuilder: (e) {
            final degree = pick(e.degreeAr, e.degreeEn);
            final place = pick(e.institutionAr, e.institutionEn);
            return _ListEntry(
              title: degree,
              subtitle: [place, if (e.year != null) '${e.year}'].where((s) => s.isNotEmpty).join(' · '),
            );
          },
        ),
        _AsyncCard<CertificateItem>(
          title: l.dpCertificatesTitle,
          value: certificates,
          onRetry: () => ref.invalidate(doctorCertificatesProvider),
          rowBuilder: (c) => _ListEntry(
            title: pick(c.titleAr, c.titleEn),
            subtitle: [c.issuer, if (c.year != null) '${c.year}'].where((s) => s.isNotEmpty).join(' · '),
            badge: c.isPublic ? l.dpCertPublic : null,
          ),
        ),
        _AsyncCard<ServiceItem>(
          title: l.dpSectionServices,
          value: services,
          onRetry: () => ref.invalidate(doctorServicesProvider),
          rowBuilder: (s) => _ListEntry(
            title: pick(s.nameAr, s.nameEn),
            subtitle: s.price == null ? '' : l.homeFeeAmount(s.price!),
            badge: s.isActive ? null : l.dpServiceInactive,
          ),
        ),
      ],
    );
  }
}

/// A list card that appears only when the list has entries. While loading it is a
/// placeholder; if the request fails it says so and can be retried, rather than
/// quietly vanishing.
class _AsyncCard<T> extends StatelessWidget {
  const _AsyncCard({
    required this.title,
    required this.value,
    required this.onRetry,
    required this.rowBuilder,
  });

  final String title;
  final AsyncValue<List<T>> value;
  final VoidCallback onRetry;
  final Widget Function(T) rowBuilder;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return value.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: HomeSpacing.section),
        child: Skeleton(height: 72, radius: homeCardRadius),
      ),
      error: (_, __) => Padding(
        padding: const EdgeInsets.only(top: HomeSpacing.section),
        child: _SectionCard(
          title: title,
          children: [
            Text(l.homeSectionError, style: HomeType.meta),
            TextButton(onPressed: onRetry, child: Text(l.actionRetry)),
          ],
        ),
      ),
      data: (items) => items.isEmpty
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(top: HomeSpacing.section),
              child: _SectionCard(title: title, children: [for (final i in items) rowBuilder(i)]),
            ),
    );
  }
}

class _ListEntry extends StatelessWidget {
  const _ListEntry({required this.title, this.subtitle = '', this.badge});

  final String title;
  final String subtitle;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    if (title.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: HomeType.cardTitle),
                if (subtitle.isNotEmpty) Text(subtitle, style: HomeType.meta),
              ],
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 8),
            MgmtBadge(label: badge!, color: AppColors.muted),
          ],
        ],
      ),
    );
  }
}

/// The account's own details (first and last name, email), which live on a
/// different record and keep their existing editor.
class _AccountTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return MgmtCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.manage_accounts_outlined, color: AppColors.primary),
        title: Text(l.dpAccountTile, style: HomeType.cardTitle),
        subtitle: Text(l.dpAccountTileHint, style: HomeType.meta),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: () => context.push(Routes.editAccount),
      ),
    );
  }
}
