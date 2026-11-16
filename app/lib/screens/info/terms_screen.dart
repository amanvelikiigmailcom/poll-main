import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../../widgets/common/legal_document_link.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) => const LegalDocumentLink(
        title: 'Terms of Use',
        url: AppConstants.termsUrl,
      );
}
