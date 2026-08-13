import 'package:flutter/material.dart';

import 'main_tab.dart';

/// Home tab only. The Instagram tab bar lives on [AppShell], not here.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const MainTab();
}
