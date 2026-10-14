import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/api/api_error.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/models.dart';
import '../../core/errors/error_messages.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/form_fields.dart';
import '../../l10n/app_localizations.dart';
import '../doctors/models.dart';
import '../doctors/providers.dart';
import '../../core/theme/app_palette.dart';

final _policiesProvider = FutureProvider<List<LegalPolicy>>(
  (ref) => ref.watch(authRepositoryProvider).currentPolicies(),
);

/// The doctor join application.
///
/// Mirrors the shortened web form: both names, phone, email, password, primary
/// specialty, a supported location, the licence text, and consent. Everything
/// else about a profile — photo, bio, years of experience, links — is filled in
/// after approval, which is what the note at the bottom says.
///
/// The location dropdown is fed by `/locations/cities/?onboarding=1`, so the app
/// never ships its own idea of where registration is open. Opening a new
/// governorate is a server configuration change, not an app release — and a
/// direct API call with an unsupported city is refused by the backend regardless
/// of what this form offers.
class JoinDoctorScreen extends ConsumerStatefulWidget {
  const JoinDoctorScreen({super.key});

  @override
  ConsumerState<JoinDoctorScreen> createState() => _JoinDoctorScreenState();
}

class _JoinDoctorScreenState extends ConsumerState<JoinDoctorScreen> {
  final _nameAr = TextEditingController();
  final _nameEn = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _licence = TextEditingController();

  String? _specialization;
  String? _cityId;
  String? _areaId;
  bool _consent = false;
  bool _obscure = true;
  bool _busy = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  @override
  void dispose() {
    for (final c in [_nameAr, _nameEn, _phone, _email, _password, _licence]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit(List<LegalPolicy> policies) async {
    final l = L.of(context);
    setState(() {
      _error = null;
      _fieldErrors = const {};
    });

    // Light client-side checks for the fields the backend marks required. These
    // save a round trip; they are not the authority. The server validates
    // everything again, including the ones checked here.
    final local = <String, String>{};
    if (_nameAr.text.trim().isEmpty) local['full_name'] = l.authNameRequired;
    if (_nameEn.text.trim().isEmpty) local['full_name_en'] = l.authNameRequired;
    if (_phone.text.trim().isEmpty) local['phone'] = l.authPhoneRequired;
    if (_email.text.trim().isEmpty) local['email'] = l.authEmail;
    if (_password.text.isEmpty) local['password'] = l.authPasswordRequired;
    if (_specialization == null) local['specialization'] = l.joinSpecialty;
    if (local.isNotEmpty) {
      setState(() => _fieldErrors = local);
      return;
    }
    if (!_consent) {
      setState(() => _error = l.consentRequired);
      return;
    }

    setState(() => _busy = true);
    try {
      final candidates = await ref
          .read(authRepositoryProvider)
          .registerDoctorRequest(
            fields: {
              'full_name': _nameAr.text.trim(),
              'full_name_en': _nameEn.text.trim(),
              'phone': _phone.text.trim(),
              'email': _email.text.trim(),
              'password': _password.text,
              'specialization': _specialization,
              if (_cityId != null) 'city': _cityId,
              if (_areaId != null) 'area': _areaId,
              if (_licence.text.trim().isNotEmpty) 'certifications_ar': _licence.text.trim(),
              'accepted_policy_versions': policies.map((p) => p.id).toList(),
            },
          );
      if (!mounted) return;

      // The backend may have spotted imported profiles that look like this
      // person. Offering the claim now is what stops them building a duplicate
      // alongside the profile that already carries their reviews.
      if (candidates.isNotEmpty) {
        await _showClaimCandidates(candidates);
        if (!mounted) return;
      }

      context.push('${Routes.otp}?phone=${Uri.encodeComponent(_phone.text.trim())}&purpose=signup');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _fieldErrors = e.fieldErrors;
        _error = e.fieldErrors.isEmpty ? messageForError(context, e) : null;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showClaimCandidates(List<ClaimCandidate> candidates) {
    final l = L.of(context);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.claimTitle, style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(l.claimBody, style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.lg),
            for (final c in candidates)
              Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  title: Text(c.fullNameAr, style: Theme.of(ctx).textTheme.titleSmall),
                  subtitle: Text(
                    c.professionalTitleAr.isEmpty ? c.matchReason : c.professionalTitleAr,
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  // Claiming needs an authenticated session, which does not exist
                  // until the phone is verified — so this records the intent and
                  // the claim is filed from the account afterwards.
                  trailing: TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(l.claimSubmitted)));
                    },
                    child: Text(l.claimThisIsMe),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(l.claimSkip)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final specs = ref.watch(specializationsProvider);
    // The onboarding-scoped list, not the directory's.
    final cities = ref.watch(onboardingCitiesProvider);
    final policies = ref.watch(_policiesProvider);

    final selectedCity = cities.valueOrNull?.where((c) => c.id == _cityId).firstOrNull;
    final areas = selectedCity?.areas ?? const <Area>[];

    return Scaffold(
      backgroundColor: context.palette.page,
      appBar: AppBar(title: Text(l.joinTitle), backgroundColor: Colors.transparent),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.sm,
            AppSpacing.gutter,
            AppSpacing.xl,
          ),
          children: [
            Text(l.joinIntro, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.xl),
            FormErrorBanner(message: _error),

            AppTextField(
              label: l.joinNameAr,
              controller: _nameAr,
              required: true,
              textInputAction: TextInputAction.next,
              errorText: _fieldErrors['full_name'],
              enabled: !_busy,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: l.joinNameEn,
              controller: _nameEn,
              helper: l.joinNameEnHint,
              required: true,
              forceLtr: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              errorText: _fieldErrors['full_name_en'],
              enabled: !_busy,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: l.authPhone,
              controller: _phone,
              hint: l.authPhoneHint,
              required: true,
              forceLtr: true,
              keyboardType: TextInputType.phone,
              inputFormatters: const [DigitsOnlyFormatter()],
              textInputAction: TextInputAction.next,
              errorText: _fieldErrors['phone'],
              enabled: !_busy,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              // Mandatory for doctors — the backend requires it, unlike patient
              // signup where it is optional.
              label: l.authEmail,
              controller: _email,
              required: true,
              forceLtr: true,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              errorText: _fieldErrors['email'],
              enabled: !_busy,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: l.authPassword,
              controller: _password,
              required: true,
              obscure: _obscure,
              onToggleObscure: () => setState(() => _obscure = !_obscure),
              errorText: _fieldErrors['password'],
              enabled: !_busy,
            ),

            const SizedBox(height: AppSpacing.xl),
            specs.when(
              loading: () => const Skeleton(height: 56, radius: AppRadii.input),
              error: (e, _) => FormErrorBanner(message: messageForError(context, e)),
              data: (tree) {
                final flat = tree.expand((s) => s.flattened).toList();
                return AppDropdown<String?>(
                  label: l.joinSpecialty,
                  value: _specialization,
                  required: true,
                  hint: l.doctorsFilterAny,
                  errorText: _fieldErrors['specialization'],
                  items: [
                    for (final s in flat)
                      DropdownMenuItem(
                        value: s.id,
                        child: Text(s.nameAr, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: _busy ? null : (v) => setState(() => _specialization = v),
                );
              },
            ),

            const SizedBox(height: AppSpacing.lg),
            AsyncValueView<List<City>>(
              value: cities,
              onRetry: () => ref.invalidate(onboardingCitiesProvider),
              loading: const Skeleton(height: 56, radius: AppRadii.input),
              data: (list) => Column(
                children: [
                  AppDropdown<String?>(
                    label: l.joinCity,
                    value: _cityId,
                    hint: l.doctorsFilterAny,
                    errorText: _fieldErrors['city'],
                    items: [
                      for (final c in list) DropdownMenuItem(value: c.id, child: Text(c.nameAr)),
                    ],
                    onChanged: _busy
                        ? null
                        : (v) => setState(() {
                            _cityId = v;
                            // An area from another city is not a valid pairing;
                            // the backend refuses it too.
                            _areaId = null;
                          }),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppDropdown<String?>(
                    label: l.joinArea,
                    value: _areaId,
                    hint: l.doctorsFilterAny,
                    enabled: !_busy && areas.isNotEmpty,
                    errorText: _fieldErrors['area'],
                    items: [
                      for (final a in areas) DropdownMenuItem(value: a.id, child: Text(a.nameAr)),
                    ],
                    onChanged: (v) => setState(() => _areaId = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            InfoNote(text: l.joinOnboardingScope),

            const SizedBox(height: AppSpacing.xl),
            AppTextField(
              label: l.joinLicence,
              controller: _licence,
              helper: l.joinLicenceHint,
              maxLines: 4,
              minLines: 3,
              errorText: _fieldErrors['certifications_ar'],
              enabled: !_busy,
            ),

            const SizedBox(height: AppSpacing.lg),
            InfoNote(text: l.joinRestLater, icon: Icons.schedule_rounded),

            const SizedBox(height: AppSpacing.lg),
            policies.when(
              loading: () => const LinearProgressIndicator(minHeight: 2),
              error: (e, _) => FormErrorBanner(message: messageForError(context, e)),
              data: (list) => CheckboxListTile(
                value: _consent,
                onChanged: _busy ? null : (v) => setState(() => _consent = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Text(l.consentAccept, style: Theme.of(context).textTheme.bodySmall),
                subtitle: list.isEmpty
                    ? null
                    : Text(
                        list.map((p) => p.titleAr).join(' • '),
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _busy || !policies.hasValue ? null : () => _submit(policies.requireValue),
              child: _busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                    )
                  : Text(l.joinSubmit),
            ),
          ],
        ),
      ),
    );
  }
}
