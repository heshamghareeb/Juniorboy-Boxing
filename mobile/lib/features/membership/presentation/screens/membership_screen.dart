import 'package:flutter/material.dart';
import '../../../../core/resources/app_strings.dart';
import '../../../../core/widgets/page_content.dart';
import '../widgets/membership_plans_section.dart';

class MembershipScreen extends StatelessWidget {
  const MembershipScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text(AppStrings.navMembership)),
        body: const PageContent(
          showHeader: false,
          children: [MembershipPlansSection()],
        ),
      );
}
