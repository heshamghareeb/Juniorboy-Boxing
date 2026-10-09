import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/resources/app_sizes.dart';
import '../../../../core/resources/app_strings.dart';
import '../../../../core/widgets/page_content.dart';
import '../../../../core/widgets/social_links_row.dart';
import '../../../booking/presentation/providers/booking_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../widgets/featured_products_carousel.dart';
import '../widgets/gym_contact_footer.dart';
import '../widgets/home_ads_section.dart';
import '../widgets/home_hero_banner.dart';
import '../../../sessions/presentation/widgets/sessions_section.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(profileProvider).value;
    final settings = ref.watch(settingsProvider).value;
    return PageContent(
      showHeader: false,
      refresh: () async {
        ref.invalidate(profileProvider);
        ref.invalidate(bookingsProvider);
        await ref.read(bookingsProvider.future);
      },
      children: [
        HomeHeroBanner(
          name: ((user?.childName.isNotEmpty ?? false)
                  ? user!.childName
                  : (user?.fullName ?? AppStrings.uiChampion))
              .split(' ')
              .first,
          imageUrl: settings?.heroImageUrl,
        ),
        const SizedBox(height: AppSizes.s14),
        const Center(child: SocialLinksRow()),
        const SizedBox(height: AppSizes.s20),
        const FeaturedProductsCarousel(),
        const SizedBox(height: AppSizes.s20),
        const HomeAdsSection(),
        const SizedBox(height: AppSizes.s20),
        const SessionsSection(),
        const SizedBox(height: AppSizes.s28),
        const GymContactFooter(),
      ],
    );
  }
}
