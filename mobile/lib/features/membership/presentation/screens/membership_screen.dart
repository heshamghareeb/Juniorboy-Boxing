import 'package:flutter/material.dart';
import '../../../../core/resources/app_strings.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/nav_debounce.dart';
import '../../../../core/widgets/page_content.dart';
import '../widgets/membership_plans_section.dart';

class MembershipScreen extends StatelessWidget {
  const MembershipScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.navMembership),
          actions: [
            IconButton(
              tooltip: AppStrings.favorites,
              icon: const Icon(Icons.favorite_rounded, color: Colors.redAccent),
              onPressed: () => context.safeNavigate(AppRoutes.favorites),
            ),
          ],
        ),
        body: const PageContent(
          showHeader: false,
          children: [MembershipPlansSection()],
        ),
      );
}
