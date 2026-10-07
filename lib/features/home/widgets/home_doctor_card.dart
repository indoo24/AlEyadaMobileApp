import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../l10n/app_localizations.dart';
import '../../bookings/booking_sheet.dart';
import '../../doctors/doctor_detail_logic.dart';
import '../../doctors/models.dart';
import '../../doctors/providers.dart';
import '../../doctors/widgets/doctor_card_tile.dart';
import '../../doctors/widgets/doctor_rating.dart';
import '../../favorites/widgets/favorite_button.dart';
import '../home_style.dart';
import 'pressable.dart';

/// A doctor in a horizontal strip: who, how they are rated, where, from how
/// much, and one clear action.
///
/// Everything comes from the doctor list (`GET /doctors/`): no availability
/// times, because the list carries none and fetching them per card would be a
/// request per doctor. The heart is the shared [FavoriteButton], so it stays in
/// step with Search, the profile and Favorites.
class HomeDoctorCard extends StatelessWidget {
  const HomeDoctorCard({super.key, required this.doctor, this.width = 248});

  final DoctorCard doctor;
  final double width;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final d = doctor;
    final specialty = d.primarySpecialization?.nameAr.trim().isNotEmpty ?? false
        ? d.primarySpecialization!.nameAr
        : d.professionalTitleAr;
    void open() => context.push(Routes.doctorPath(d.slug));

    return SizedBox(
      width: width,
      child: Pressable(
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(homeCardRadius),
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.soft,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: open,
              borderRadius: BorderRadius.circular(homeCardRadius),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Photo(doctor: d),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d.displayName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: HomeType.doctorName.copyWith(fontSize: 14.5),
                              ),
                              if (specialty.isNotEmpty)
                                Text(
                                  specialty,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: HomeType.doctorSpecialty.copyWith(color: AppColors.muted),
                                ),
                              const SizedBox(height: 4),
                              DoctorRating(doctor: d, fontSize: 12),
                            ],
                          ),
                        ),
                        FavoriteButton(doctorId: d.id, slug: d.slug, size: 21),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (d.locationLabel.isNotEmpty) ...[
                      _Meta(icon: Icons.location_on_outlined, text: d.locationLabel),
                    ],
                    const SizedBox(height: 4),
                    _Meta(
                      icon: d.bookingEnabled
                          ? Icons.event_available_rounded
                          : Icons.phone_in_talk_outlined,
                      text: d.bookingEnabled ? l.hmOnlineBooking : l.hmPhoneBooking,
                      // Green is the tokens' availability colour; the words say
                      // it too, so it is never colour alone.
                      color: d.bookingEnabled ? AppColors.success : null,
                    ),
                    const Spacer(),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1, color: AppColors.border),
                    ),
                    Row(
                      children: [
                        if (d.minFee != null)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l.ddStatFee, maxLines: 1, style: HomeType.feeLabel),
                                Text(
                                  l.ddMoney(d.minFee!),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: HomeType.feeAmount,
                                ),
                              ],
                            ),
                          )
                        else
                          const Spacer(),
                        const SizedBox(width: 8),
                        _BookButton(doctor: d, onOpenProfile: open),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.doctor});

  final DoctorCard doctor;

  @override
  Widget build(BuildContext context) =>
      DoctorAvatar(photo: doctor.photo, name: doctor.displayName, size: 60, radius: 16);
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 14, color: color ?? AppColors.muted),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: HomeType.meta.copyWith(
            color: color,
            fontWeight: color == null ? null : FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

/// "Book now" opens the real booking sheet for this doctor; a contact-only
/// doctor gets "View profile" instead.
///
/// The sheet needs the doctor's clinics, so the profile is loaded first through
/// the cached [doctorDetailProvider] (the same request the profile page makes).
/// Booking rules — signing in, phone verification, clinic choice, conflicts —
/// all stay with the sheet. If the doctor turns out to have no bookable clinic,
/// or the profile cannot be loaded, the button opens the profile instead.
class _BookButton extends ConsumerStatefulWidget {
  const _BookButton({required this.doctor, required this.onOpenProfile});

  final DoctorCard doctor;
  final VoidCallback onOpenProfile;

  @override
  ConsumerState<_BookButton> createState() => _BookButtonState();
}

class _BookButtonState extends ConsumerState<_BookButton> {
  bool _loading = false;

  Future<void> _book() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final detail = await ref.read(doctorDetailProvider(widget.doctor.slug).future);
      if (!mounted) return;
      if (bookableClinics(detail).isEmpty) {
        widget.onOpenProfile();
      } else {
        await showBookingSheet(context, detail);
      }
    } catch (_) {
      if (mounted) widget.onOpenProfile();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final bookable = widget.doctor.bookingEnabled;
    final style = FilledButton.styleFrom(
      minimumSize: const Size(0, 40),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: HomeType.button.copyWith(fontSize: 13),
    );
    if (!bookable) {
      return OutlinedButton(
        onPressed: widget.onOpenProfile,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: HomeType.button.copyWith(fontSize: 13),
        ),
        child: Text(l.hmViewProfile, maxLines: 1),
      );
    }
    return FilledButton(
      onPressed: _loading ? null : _book,
      style: style,
      child: _loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            )
          : Text(l.hmBookNow, maxLines: 1),
    );
  }
}

/// A placeholder in the shape of a [HomeDoctorCard].
class HomeDoctorCardSkeleton extends StatelessWidget {
  const HomeDoctorCardSkeleton({super.key, this.width = 248});

  final double width;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(homeCardRadius),
      border: Border.all(color: AppColors.border),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Skeleton(height: 56, width: 56, radius: 16),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(height: 14, width: 120),
                  SizedBox(height: 6),
                  Skeleton(height: 11, width: 80),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 14),
        Skeleton(height: 11, width: 120),
        SizedBox(height: 6),
        Skeleton(height: 11, width: 90),
        SizedBox(height: 18),
        Row(
          children: [
            Expanded(child: Skeleton(height: 26)),
            SizedBox(width: 30),
            Skeleton(height: 40, width: 92, radius: 12),
          ],
        ),
      ],
    ),
  );
}

/// The last tile in the doctor strip: the whole directory, in the Home city.
class SeeAllDoctorsTile extends StatelessWidget {
  const SeeAllDoctorsTile({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 132,
    child: Material(
      color: AppColors.bgSoft,
      borderRadius: BorderRadius.circular(homeCardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(homeCardRadius),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_forward_rounded, color: AppColors.primary),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: HomeType.tileLabel.copyWith(color: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
