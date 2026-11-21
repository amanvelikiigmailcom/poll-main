import 'package:flutter/material.dart';
import '../../services/content_service.dart';
import '../../widgets/common/legal_document_link.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) => LegalDocumentLink(
        title: 'Privacy Policy',
        url: ContentService.instance.text('url_privacy'),
      );
}
