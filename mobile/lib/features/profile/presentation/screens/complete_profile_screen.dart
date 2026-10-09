import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/resources/app_icons.dart';
import '../../../../core/resources/app_colors.dart';
import '../../../../core/utils/address_utils.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/resources/app_sizes.dart';
import '../../../../core/resources/app_strings.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/jbb_button.dart';
import '../providers/profile_provider.dart';

class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});
  @override
  ConsumerState<CompleteProfileScreen> createState() => _CompleteProfileState();
}

class _CompleteProfileState extends ConsumerState<CompleteProfileScreen> {
  final form = GlobalKey<FormState>(),
      houseNumber = TextEditingController(),
      streetName = TextEditingController(),
      city = TextEditingController(),
      country = TextEditingController(),
      zipCode = TextEditingController(),
      phone = TextEditingController(),
      childName = TextEditingController(),
      childAge = TextEditingController();
  bool busy = false,
      loaded = false,
      photoBusy = false,
      termsAccepted = false,
      termsError = false;
  @override
  void dispose() {
    houseNumber.dispose();
    streetName.dispose();
    city.dispose();
    country.dispose();
    zipCode.dispose();
    phone.dispose();
    childName.dispose();
    childAge.dispose();
    super.dispose();
  }

  Future<void> pickPhoto() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: AppSizes.mediaMaxWidth,
      imageQuality: 85,
    );
    if (image == null) return;
    setState(() => photoBusy = true);
    try {
      await ref.read(userRepositoryProvider).uploadAvatar(File(image.path));
      if (mounted) showMessage(context, AppStrings.profilePhotoUpdated);
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => photoBusy = false);
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    if (!termsAccepted) {
      setState(() => termsError = true);
      showMessage(context, AppStrings.mustAcceptTermsToContinue);
      return;
    }
    setState(() => busy = true);
    try {
      await ref.read(userRepositoryProvider).save({
        'address': composeAddress(
          houseNumber: houseNumber.text.trim(),
          streetName: streetName.text.trim(),
          city: city.text.trim(),
          country: country.text.trim(),
        ),
        'zipCode': zipCode.text.trim(),
        'phone': phone.text.trim(),
        'childName': childName.text.trim(),
        'childAge': int.tryParse(childAge.text) ?? 0,
        'termsAccepted': true,
        'termsAcceptedAt': FieldValue.serverTimestamp(),
        'termsVersion': 'v1',
      });
      if (mounted) {
        if (context.canPop()) {
          context.pop(true);
        } else {
          context.go(AppRoutes.home);
        }
      }
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(profileProvider).value;
    if (user != null && !loaded) {
      loaded = true;
      if (user.termsAccepted) {
        termsAccepted = true;
      }
      final parsed = StructuredAddress.parse(user.address);
      houseNumber.text = parsed.houseNumber;
      streetName.text = parsed.streetName;
      city.text = parsed.city;
      country.text = parsed.country;
      if (zipCode.text.isEmpty) zipCode.text = user.zipCode ?? '';
      if (phone.text.isEmpty) phone.text = user.phone ?? '';
      if (childName.text.isEmpty) childName.text = user.childName;
      if (childAge.text.isEmpty && (user.childAge) > 0) {
        childAge.text = '${user.childAge}';
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.completeYourProfile)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.s24),
        child: Form(
          key: form,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppStrings.uiJustAFewMoreDetails,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSizes.s10),
              const Text(AppStrings.uiWeNeedAFewAccountDetailsPlusWho),
              const SizedBox(height: AppSizes.s24),
              Center(
                child: GestureDetector(
                  onTap: photoBusy ? null : pickPhoto,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: AppSizes.avatarRadiusProfile,
                        backgroundColor: context.palette.accentTint,
                        backgroundImage: user?.avatarUrl != null
                            ? CachedNetworkImageProvider(user!.avatarUrl!)
                            : null,
                        child: user?.avatarUrl == null
                            ? AppIcon(
                                AppIcons.user,
                                size: AppSizes.s40,
                                color: context.palette.accent,
                              )
                            : null,
                      ),
                      CircleAvatar(
                        radius: AppSizes.avatarRadiusSmall,
                        backgroundColor: context.palette.accent,
                        child: photoBusy
                            ? const CircularProgressIndicator()
                            : const AppIcon(
                                AppIcons.imagePlus,
                                size: AppSizes.s16,
                                color: AppColors.onAccent,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.s24),
              TextFormField(
                controller: childName,
                decoration: const InputDecoration(
                  labelText: AppStrings.participantNameYourselfOrChildOptional,
                ),
              ),
              const SizedBox(height: AppSizes.s16),
              TextFormField(
                controller: childAge,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: AppStrings.participantAgeOptional,
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? null : Validators.age(v),
              ),
              const SizedBox(height: AppSizes.s16),
              for (final field in [
                (houseNumber, AppStrings.houseNumber),
                (streetName, AppStrings.streetName),
                (city, AppStrings.city),
                (country, AppStrings.country),
              ]) ...[
                TextFormField(
                  controller: field.$1,
                  decoration: InputDecoration(labelText: field.$2),
                  validator: Validators.required,
                ),
                const SizedBox(height: AppSizes.s16),
              ],
              const SizedBox(height: AppSizes.s16),
              TextFormField(
                controller: zipCode,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(
                  labelText: AppStrings.postalZipCode,
                ),
                validator: Validators.zip,
              ),
              const SizedBox(height: AppSizes.s16),
              TextFormField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: AppStrings.phone),
                validator: Validators.phone,
              ),
              const SizedBox(height: AppSizes.s20),
              Container(
                decoration: BoxDecoration(
                  color: termsError
                      ? context.palette.accentTint.withValues(alpha: 0.35)
                      : context.palette.surface,
                  borderRadius: BorderRadius.circular(AppSizes.radiusCard),
                  border: Border.all(
                    color: termsError
                        ? context.palette.accent
                        : (termsAccepted
                            ? context.palette.accent.withValues(alpha: 0.6)
                            : context.palette.separator),
                    width: termsError ? 1.5 : 1.0,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.s12,
                  vertical: AppSizes.s8,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: termsAccepted,
                      activeColor: context.palette.accent,
                      onChanged: (v) {
                        setState(() {
                          termsAccepted = v ?? false;
                          if (termsAccepted) termsError = false;
                        });
                      },
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: AppSizes.s12),
                        child: Text.rich(
                          TextSpan(
                            text: AppStrings.iAgreeToTermsOfParticipation,
                            style: TextStyle(
                              fontSize: AppSizes.font14,
                              color: context.palette.textPrimary,
                            ),
                            children: [
                              TextSpan(
                                text: AppStrings.termsOfParticipationLink,
                                style: TextStyle(
                                  color: context.palette.accent,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () async {
                                    final agreed = await context.push<bool>(
                                      AppRoutes.terms,
                                      extra: {'showAccept': true},
                                    );
                                    if (agreed == true && mounted) {
                                      setState(() {
                                        termsAccepted = true;
                                        termsError = false;
                                      });
                                    }
                                  },
                              ),
                              const TextSpan(text: '.'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (termsError) ...[
                const SizedBox(height: AppSizes.s8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSizes.s8),
                  child: Text(
                    AppStrings.mustAcceptTermsToContinue,
                    style: TextStyle(
                      color: context.palette.accent,
                      fontSize: AppSizes.font12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSizes.s28),
              JbbButton(
                label: AppStrings.continueButton,
                busy: busy,
                onPressed: save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
