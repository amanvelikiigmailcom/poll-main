import 'package:flutter/material.dart';
import '../../services/university_catalog.dart';

class UniversityPickerField extends StatelessWidget {
  const UniversityPickerField(
      {super.key, required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  Future<void> _pick(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.9,
        child: _UniversityPicker(selected: controller.text),
      ),
    );
    if (!context.mounted || selected == null) return;
    controller.text = selected;
    onChanged(selected);
  }

  @override
  Widget build(BuildContext context) => TextFormField(
        key: const Key('university-picker-field'),
        controller: controller,
        readOnly: true,
        onTap: () => _pick(context),
        decoration: InputDecoration(
          labelText: 'University (optional)',
          hintText: 'Select your university',
          suffixIcon: const Icon(Icons.expand_more_rounded),
          filled: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
}

class _UniversityPicker extends StatefulWidget {
  const _UniversityPicker({required this.selected});
  final String selected;
  @override
  State<_UniversityPicker> createState() => _UniversityPickerState();
}

class _UniversityPickerState extends State<_UniversityPicker> {
  final _search = TextEditingController();
  late Future<List<UsUniversity>> _catalog;

  @override
  void initState() {
    super.initState();
    _catalog = UniversityCatalog.load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          children: [
            ListTile(
              title: const Text('Choose your university',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              trailing: IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                key: const Key('university-search'),
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search name, city or state',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, ''),
              child: const Text('No university selected'),
            ),
            Expanded(
              child: FutureBuilder<List<UsUniversity>>(
                future: _catalog,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('Couldn’t load universities.'),
                      TextButton(
                          onPressed: () => setState(
                              () => _catalog = UniversityCatalog.load()),
                          child: const Text('Try again')),
                    ]));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final results = snapshot.data!
                      .where((item) => item.matches(_search.text))
                      .toList();
                  if (results.isEmpty) {
                    return const Center(
                        child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                          'No universities found. Try a different name, city or state.',
                          textAlign: TextAlign.center),
                    ));
                  }
                  return ListView.builder(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final item = results[index];
                      return ListTile(
                        key: ValueKey(item.id),
                        title: Text(item.name),
                        subtitle: Text('${item.city}, ${item.state}'),
                        trailing: item.name == widget.selected
                            ? const Icon(Icons.check)
                            : null,
                        onTap: () => Navigator.pop(context, item.name),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
}
