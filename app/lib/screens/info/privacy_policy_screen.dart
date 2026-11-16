import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../../widgets/common/legal_document_link.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) => const LegalDocumentLink(
        title: 'Privacy Policy',
        url: AppConstants.privacyUrl,
      );
}
