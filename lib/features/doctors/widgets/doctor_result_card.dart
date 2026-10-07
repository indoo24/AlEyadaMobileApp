import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../favorites/widgets/favorite_button.dart';
import '../../home/home_style.dart';
import '../models.dart';
import '../providers.dart';
import 'doctor_card_tile.dart';
import 'doctor_rating.dart';

/// A doctor in the search results: who they are and what they cost on top, the
/// place and booking status beneath, and the two actions — call, and book.
///
/// Only fields the list endpoint returns appear. There is no waiting time, no
/// "available today" slot and no favourite heart: the API carries none of them,
/// and a control that does nothing is worse than no control.
class DoctorResultCard extends ConsumerWidget {
  const DoctorResultCard({super.key, required this.doctor, required this.onOpen});

  final DoctorCard doctor;

  /// Opens the profile — which is where booking starts.
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final title = doctor.professionalTitleAr;
    final specialization = doctor.primarySpecialization?.nameAr ?? '';
    final headline = title.isNotEmpty ? title : specialization;
    final years = doctor.yearsOfExperience ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(homeCardRadius),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(HomeSpacing.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Photo(doctor: doctor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                doctor.displayName,
                                style: HomeType.doctorName.copyWith(fontSize: 16),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Its own tap target: favouriting must not open the profile.
                            FavoriteButton(doctorId: doctor.id, slug: doctor.slug),
                          ],
                        ),
                        const SizedBox(height: 2),
                        DoctorRating(doctor: doctor),
                        if (headline.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            headline,
                            style: HomeType.doctorSpecialty,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if ((title.isNotEmpty && specialization.isNotEmpty) || years > 0) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (title.isNotEmpty && specialization.isNotEmpty)
                                _Tag(label: specialization),
                              if (years > 0) _Tag(label: l.searchYearsShort(years)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (doctor.locationLabel.isNotEmpty)
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  child: Text(
                    doctor.locationLabel,
                    style: HomeType.doctorSpecialty,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (doctor.minFee != null)
                _InfoRow(
                  icon: Icons.payments_outlined,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '${l.homeFeeLabel}: ', style: HomeType.feeLabel),
                        TextSpan(text: l.homeFeeAmount(doctor.minFee!), style: HomeType.feeAmount),
                      ],
                    ),
                  ),
                ),
              _InfoRow(
                icon: doctor.bookingEnabled
                    ? Icons.event_available_outlined
                    : Icons.phone_in_talk_outlined,
                color: doctor.bookingEnabled ? AppColors.success : AppColors.muted,
                child: Text(
                  doctor.bookingEnabled ? l.homeBookingAvailable : l.homeContactOnly,
                  style: HomeType.status.copyWith(
                    fontSize: 12,
                    color: doctor.bookingEnabled ? AppColors.success : AppColors.muted,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (doctor.contact.canCall) ...[
                    _CallButton(
                      label: l.searchCall,
                      onPressed: () => _call(ref, doctor.contact.telUrl!),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: FilledButton(
                      onPressed: onOpen,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: HomeType.button.copyWith(fontSize: 13.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              doctor.bookingEnabled ? l.searchBookAppointment : l.homeViewProfile,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Mirrors with the text direction: forward is left in Arabic.
                          const Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Open the `tel:` link the API built, and record the click. Tracking is not
  /// awaited and cannot block the call — the same rule the profile page follows.
  Future<void> _call(WidgetRef ref, String url) async {
    ref
        .read(directoryRepositoryProvider)
        .trackContactClick(doctorId: doctor.id, contactType: 'phone');
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.doctor});

  final DoctorCard doctor;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DoctorAvatar(photo: doctor.photo, name: doctor.displayName, size: 84, radius: 12),
          ),
          // Green when the doctor takes online bookings — the only availability
          // signal the list carries. Labelled for screen readers.
          if (doctor.bookingEnabled)
            PositionedDirectional(
              bottom: 4,
              end: 4,
              child: Semantics(
                label: l.homeBookingAvailable,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: AppColors.bgSoft, borderRadius: AppRadii.pillRadius),
      child: Text(label, style: HomeType.pill.copyWith(color: AppColors.muted, fontSize: 11)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.child, this.color = AppColors.primary});

  final IconData icon;
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgSoft,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Tooltip(
          message: label,
          child: Semantics(
            button: true,
            label: label,
            excludeSemantics: true,
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(Icons.phone_outlined, size: 20, color: AppColors.primary),
            ),
          ),
        ),
      ),
    );
  }
}
