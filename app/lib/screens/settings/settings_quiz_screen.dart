import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/service_providers.dart';
import '../../router/app_router.dart';
import '../../services/api_service.dart';
import '../../services/quiz_preferences_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';

Future<void> showQuizPreferences(
  BuildContext context,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  // Closing is handled by the sheet so an in-flight save cannot be dismissed.
  isDismissible: false,
  enableDrag: false,
  backgroundColor: Colors.transparent,
  builder: (_) => FractionallySizedBox(
    heightFactor: .85,
    child: ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: const SettingsQuizScreen(modal: true),
    ),
  ),
);

class SettingsQuizScreen extends ConsumerStatefulWidget {
  const SettingsQuizScreen({super.key, this.modal = false});
  final bool modal;

  @override
  ConsumerState<SettingsQuizScreen> createState() => _SettingsQuizScreenState();
}

class _SettingsQuizScreenState extends ConsumerState<SettingsQuizScreen> {
  late final StorageService _storage;
  late final QuizPreferencesService _service;
  String? _token;
  QuizPreferencesData? _data;
  String? _selected;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  bool _opened = false;
  bool _accountChanged = false;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _storage = ref.read(storageServiceProvider);
    _service = ref.read(quizPreferencesServiceProvider);
    _storage.addListener(_onAccountChanged);
    _initialize();
  }

  Future<void> _initialize() async {
    final token = await _storage.getToken();
    if (!mounted || _accountChanged) return;
    _token = token;
    if (token == null || token.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    await _load();
  }

  void _onAccountChanged() {
    if (!mounted) return;
    setState(() {
      _accountChanged = true;
      _data = null;
      _selected = null;
      _loading = false;
      _error = 'Account changed. Close and reopen Quiz preferences.';
    });
  }

  @override
  void dispose() {
    _storage.removeListener(_onAccountChanged);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.load(_token!);
      if (!mounted || _accountChanged) return;
      setState(() {
        _data = data;
        _selected = data.genderFilter;
      });
    } on ApiException catch (error) {
      if (mounted && !_accountChanged) setState(() => _error = error.message);
    } finally {
      if (mounted && !_accountChanged) setState(() => _loading = false);
    }
  }

  void _close() {
    if (!_saving) Navigator.of(context).pop();
  }

  Future<void> _save() async {
    if (_selected == null || _saving || _accountChanged) return;
    final selected = _selected!;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await _service.save(_token!, selected);
      if (saved.genderFilter != selected) {
        throw const ApiException(
          'Couldn’t confirm your preference. Please try again.',
        );
      }
      if (mounted && !_accountChanged) Navigator.of(context).pop();
    } on ApiException catch (error) {
      // A lost PUT reply does not prove the write failed. Reconcile by reading.
      try {
        final actual = await _service.load(_token!);
        if (mounted && !_accountChanged && actual.genderFilter == selected) {
          Navigator.of(context).pop();
          return;
        }
      } on ApiException catch (_) {
        // Preserve the draft and report the original error.
      }
      if (mounted && !_accountChanged) {
        setState(() => _error = error.message);
        if (_scrollController.hasClients) _scrollController.jumpTo(0);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final guest =
        !_loading && !_accountChanged && (_token == null || _token!.isEmpty);
    final label = data?.options
        .where((option) => option.value == _selected)
        .firstOrNull
        ?.label;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leadingWidth: 80,
          leading: TextButton(
            onPressed: _saving ? null : _close,
            child: const Text('Back'),
          ),
          title: const Text('Quiz preferences'),
          centerTitle: true,
          bottom: widget.modal
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(16),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragEnd: (details) {
                      if ((details.primaryVelocity ?? 0) > 100) _close();
                    },
                    child: const SizedBox(
                      height: 16,
                      width: double.infinity,
                      child: Center(
                        child: SizedBox(
                          width: 40,
                          child: Divider(thickness: 4),
                        ),
                      ),
                    ),
                  ),
                )
              : null,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    if (_loading)
                      const Center(child: CircularProgressIndicator()),
                    if (guest) ...[
                      const Text(
                        'Sign in to manage Quiz preferences. Your settings are saved to your account.',
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          final router = GoRouter.of(context);
                          if (widget.modal) Navigator.of(context).pop();
                          router.push(AppRoutes.phone);
                        },
                        child: const Text('Sign in'),
                      ),
                    ],
                    if (_error != null) ...[
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.accentRed),
                        ),
                      ),
                      if (data == null && !_accountChanged && !guest)
                        TextButton(
                          onPressed: _loading ? null : _load,
                          child: const Text('Retry'),
                        ),
                      const SizedBox(height: 16),
                    ],
                    if (data != null) ...[
                      const Text(
                        'Who appears in your quizzes?',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'People from your campus in your graduation year are shown first, followed by other eligible people.',
                      ),
                      const SizedBox(height: 24),
                      Material(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(14),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            ListTile(
                              title: Text(label ?? ''),
                              trailing: Icon(
                                _opened ? Icons.expand_less : Icons.expand_more,
                              ),
                              onTap: _saving
                                  ? null
                                  : () => setState(() => _opened = !_opened),
                            ),
                            if (_opened)
                              RadioGroup<String>(
                                groupValue: _selected,
                                onChanged: (value) {
                                  if (!_saving) {
                                    setState(() => _selected = value);
                                  }
                                },
                                child: Column(
                                  children: [
                                    for (final option in data.options)
                                      RadioListTile<String>(
                                        title: Text(option.label),
                                        value: option.value,
                                        enabled: !_saving,
                                        activeColor: AppColors.primaryBlue,
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Changes apply to your next round. Your current round stays unchanged.',
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed:
                        data == null ||
                            _selected == null ||
                            _loading ||
                            _saving ||
                            _accountChanged
                        ? null
                        : _save,
                    child: Text(_saving ? 'Saving…' : 'Select'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
