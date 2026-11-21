import 'package:flutter/material.dart';
import '../../services/content_service.dart';
import '../../widgets/common/legal_document_link.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) => LegalDocumentLink(
        title: 'Terms of Use',
        url: ContentService.instance.text('url_terms'),
      );
}
