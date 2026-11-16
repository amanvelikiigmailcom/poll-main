import 'package:flutter/material.dart';
import '../../services/external_link_service.dart';

class LegalDocumentLink extends StatelessWidget {
  const LegalDocumentLink({super.key, required this.title, required this.url});

  final String title;
  final String url;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            const Text('Read the current document on the Flyprox website.'),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => openExternalLink(context, url),
              icon: const Icon(Icons.open_in_new),
              label: Text('Open $title'),
            ),
            const SizedBox(height: 16),
            SelectableText(url),
          ],
        ),
      );
}
