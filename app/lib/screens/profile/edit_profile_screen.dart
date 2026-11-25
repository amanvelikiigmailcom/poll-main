import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/school_regions.dart';
import '../../providers/service_providers.dart';
import '../../services/api_service.dart';
import '../../services/profile_edit_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import 'profile_social_section.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _username = TextEditingController();
  final _year = TextEditingController();
  late final StorageService _storage;
  late final ProfileEditNavigationGuard _guard;
  late final Future<bool> Function() _leaveHandler;
  Map<String, dynamic>? _original, _school;
  String? _gender;
  String _country = 'US';
  String? _token, _error, _availability, _requestId, _requestSignature;
  Timer? _debounce;
  int _generation = 0;
  bool _loading = true, _saving = false, _checking = false;
  bool _taken = false, _invalidSession = false, _allowPop = false;
  bool _dialogOpen = false, _availabilityError = false;

  @override
  void initState() {
    super.initState();
    _storage = ref.read(storageServiceProvider);
    _storage.addListener(_accountChanged);
    _guard = ref.read(profileEditNavigationGuardProvider);
    _leaveHandler = _leave;
    _guard.leave = _leaveHandler;
    for (final c in [_first, _last, _username, _year]) {
      c.addListener(_changed);
    }
    _load();
  }

  Future<void> _accountChanged() async {
    final current = await _storage.getToken();
    if (!mounted || current == _token) return;
    _debounce?.cancel();
    _generation++;
    setState(() {
      _invalidSession = true;
      _saving = false;
      _original = null;
      _school = null;
      _gender = null;
      _error = 'Account changed. Close and reopen Edit profile.';
      _loading = false;
      for (final c in [_first, _last, _username, _year]) {
        c.clear();
      }
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await _storage.getToken();
      if (!mounted) return;
      _token = token;
      if (token == null || token.isEmpty) {
        setState(() => _loading = false);
        return;
      }
      final data = await ref.read(profileEditServiceProvider).request(token);
      if (!mounted || _invalidSession) return;
      if (data['revision'] is! String || data['limits'] is! Map) {
        throw const ApiException('Couldn’t load editing limits. Try again.');
      }
      _first.text = data['firstName'] as String? ?? '';
      _last.text = data['lastName'] as String? ?? '';
      _username.text = data['username'] as String? ?? '';
      _year.text = data['graduationYear']?.toString() ?? '';
      _gender = data['gender'] as String?;
      _country = data['country'] as String? ?? 'US';
      setState(() {
        _original = data;
        _school = data['school'] == null
            ? null
            : Map<String, dynamic>.from(data['school'] as Map);
        _loading = false;
      });
    } catch (error) {
      if (mounted && !_invalidSession) {
        setState(() {
          _loading = false;
          _error = _message(error, 'Couldn’t load your profile. Try again.');
        });
      }
    }
  }

  String _message(Object error, String fallback) =>
      error is ApiException ? error.message : fallback;

  bool _editable(String field) =>
      !_saving &&
      !_invalidSession &&
      (_original?['limits'] as Map?)?[field]?['editable'] == true;

  String _hint(String field) {
    final limit = (_original?['limits'] as Map?)?[field] as Map?;
    if (limit?['editable'] == true) {
      return 'After saving, you can change this again in 90 days.';
    }
    final date = DateTime.tryParse(limit?['nextAllowedAt'] as String? ?? '');
    return date == null
        ? 'Editing is unavailable.'
        : 'Available again on ${MaterialLocalizations.of(context).formatMediumDate(date.toLocal())}.';
  }

  Map<String, dynamic> get _changes {
    final data = _original;
    if (data == null) return {};
    final next = <String, dynamic>{
      if ((_original?['limits'] as Map?)?['country'] != null)
        'country': _country,
      if ((_original?['limits'] as Map?)?['gender'] != null && _gender != null)
        'gender': _gender,
      'firstName': _first.text.trim(),
      'lastName': _last.text.trim(),
      'username': _username.text.trim().toLowerCase(),
      'schoolId': _school?['id'],
      'graduationYear': int.tryParse(_year.text.trim()) ?? _year.text.trim(),
    };
    final originalSchoolId = (data['school'] as Map?)?['id'];
    next.removeWhere(
      (key, value) =>
          value == (key == 'schoolId' ? originalSchoolId : data[key]) ||
          (key == 'graduationYear' && value == '' && data[key] == null),
    );
    return next;
  }

  void _changed() {
    if (!mounted || _loading || _invalidSession) return;
    setState(() => _error = null);
  }

  static String? _nameError(String? value) {
    final name = (value ?? '').trim();
    if (name.runes.length < 2 ||
        name.runes.length > 50 ||
        !RegExp(
          r"^[\p{L}\p{M}][\p{L}\p{M} '\u2019-]*$",
          unicode: true,
        ).hasMatch(name)) {
      return 'Use 2–50 letters, spaces, hyphens or apostrophes.';
    }
    return null;
  }

  static String? _handleError(String? value) =>
      RegExp(r'^[a-zA-Z0-9_]{3,32}$').hasMatch((value ?? '').trim())
      ? null
      : 'Use 3–32 letters, numbers or underscores.';

  void _usernameChanged(String value) {
    _debounce?.cancel();
    final generation = ++_generation;
    final handle = value.trim().toLowerCase();
    setState(() {
      _availability = null;
      _taken = false;
      _checking = false;
      _availabilityError = false;
    });
    if (_handleError(value) != null || handle == _original?['username']) return;
    setState(() => _checking = true);
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final result = await ref
            .read(profileEditServiceProvider)
            .request(_token!, suffix: '/username', query: {'username': handle});
        if (!mounted || generation != _generation || _invalidSession) return;
        setState(() {
          _checking = false;
          _taken = result['available'] != true;
          _availability = _taken
              ? 'This username is taken. Choose another.'
              : 'Username available';
        });
      } catch (_) {
        if (!mounted || generation != _generation || _invalidSession) return;
        setState(() {
          _checking = false;
          _availabilityError = true;
          _availability = 'Couldn’t check availability. Save to try again.';
        });
      }
    });
  }

  Future<void> _chooseCampus() async {
    if (!_editable('schoolId')) return;
    final school = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CampusPicker(country: _country),
    );
    if (!mounted || school == null || _invalidSession) return;
    setState(() {
      _school = school;
      _error = null;
    });
  }

  Future<bool> _save() async {
    if (_saving ||
        _invalidSession ||
        _original == null ||
        !(_form.currentState?.validate() ?? false) ||
        _taken ||
        _checking) {
      return false;
    }
    final changes = _changes;
    if (changes.isEmpty) return true;
    if (_dialogOpen) return false;
    _dialogOpen = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm changes'),
        content: Text(
          'You’re changing:\n${changes.keys.map((key) => '• ${_label(key)}').join('\n')}\n\nYou won’t be able to change these fields again for 90 days.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm and save'),
          ),
        ],
      ),
    );
    _dialogOpen = false;
    if (!mounted || confirmed != true || _invalidSession) return false;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    final signature = jsonEncode(changes);
    if (_requestSignature != signature) {
      _requestSignature = signature;
      _requestId = null;
    }
    _requestId ??= List.generate(
      16,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    try {
      final data = await ref
          .read(profileEditServiceProvider)
          .request(
            _token!,
            method: 'PUT',
            data: {
              'requestId': _requestId,
              'revision': _original!['revision'],
              'changes': changes,
              'confirmed': true,
            },
          );
      if (!mounted || _invalidSession) return false;
      setState(() {
        _original = data;
        _saving = false;
      });
      ref.invalidate(profileIdentityProvider);
      ref.invalidate(socialSummaryProvider);
      // Restore is session-scoped; the API response, not this cache, proves save success.
      unawaited(ref.read(onboardingDetailsProvider).restore());
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
      return true;
    } catch (error) {
      if (mounted && !_invalidSession) {
        setState(() {
          _saving = false;
          _error = _message(error, 'Couldn’t save your profile. Try again.');
        });
      }
      return false;
    }
  }

  Future<bool> _leave() async {
    if (_saving || _dialogOpen) return false;
    if (_changes.isNotEmpty && !_invalidSession) {
      _dialogOpen = true;
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Save changes?'),
          content: const Text('You have unsaved changes.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'keep'),
              child: const Text('Keep editing'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'discard'),
              child: const Text('Discard'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'save'),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      _dialogOpen = false;
      if (!mounted || choice == null || choice == 'keep') return false;
      if (choice == 'save' && !await _save()) return false;
    }
    if (!mounted) return false;
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return false;
    _close();
    return true;
  }

  Future<void> _saveAndClose() async {
    if (!await _save() || !mounted) return;
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) _close();
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home/profile');
    }
  }

  static String _label(String field) => const {
    'country': 'Country of study',
    'gender': 'Gender',
    'firstName': 'First name',
    'lastName': 'Last name',
    'username': 'Username',
    'schoolId': 'Campus',
    'graduationYear': 'Graduation year',
  }[field]!;

  @override
  void dispose() {
    _generation++;
    _debounce?.cancel();
    _storage.removeListener(_accountChanged);
    if (identical(_guard.leave, _leaveHandler)) _guard.leave = null;
    for (final c in [_first, _last, _username, _year]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _field(
    String key,
    TextEditingController controller, {
    String? Function(String?)? validator,
    String? prefix,
    void Function(String)? onChanged,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: TextFormField(
      key: ValueKey('edit-$key'),
      controller: controller,
      enabled: _editable(key),
      keyboardType: keyboard,
      autocorrect: key != 'username',
      enableSuggestions: key != 'username',
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (value) =>
          _changes.containsKey(key) ? validator?.call(value) : null,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: _label(key),
        prefixText: prefix,
        helperText: _hint(key),
        helperMaxLines: 3,
        errorMaxLines: 3,
        suffixIcon: _editable(key)
            ? null
            : const Icon(Icons.lock_outline, size: 18),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) unawaited(_leave());
    },
    child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Edit profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          onPressed: _saving ? null : _leave,
          icon: const Icon(Icons.close),
        ),
      ),
      body: _loading
          ? const Padding(padding: EdgeInsets.all(24), child: ProfileSkeleton())
          : _original == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircleAvatar(
                      radius: 46,
                      backgroundColor: Color(0xFFEFF1FE),
                      child: Text('🙂', style: TextStyle(fontSize: 50)),
                    ),
                    const SizedBox(height: 20),
                    Text(_error ?? 'Sign in to edit your profile.'),
                    if (_error != null && !_invalidSession)
                      TextButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                children: [
                  const Center(
                    child: CircleAvatar(
                      radius: 46,
                      backgroundColor: Color(0xFFEFF1FE),
                      child: Text('🙂', style: TextStyle(fontSize: 50)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PERSONAL INFORMATION',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _field('firstName', _first, validator: _nameError),
                          _field('lastName', _last, validator: _nameError),
                          _field(
                            'username',
                            _username,
                            prefix: '@',
                            validator: _handleError,
                            onChanged: _usernameChanged,
                          ),
                          if (_checking || _availability != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(
                                _checking
                                    ? 'Checking availability…'
                                    : _availability!,
                                style: TextStyle(
                                  color: _taken
                                      ? AppColors.error
                                      : _availabilityError || _checking
                                      ? AppColors.textSecondary
                                      : AppColors.success,
                                ),
                              ),
                            ),
                          if ((_original!['limits'] as Map)['gender'] != null)
                            DropdownButtonFormField<String>(
                              key: const Key('edit-gender'),
                              isExpanded: true,
                              initialValue: _gender,
                              decoration: const InputDecoration(
                                labelText: 'Gender',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'female',
                                  child: Text(
                                    'Female',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'male',
                                  child: Text(
                                    'Male',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'nonbinary',
                                  child: Text(
                                    'Non-binary',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                              onChanged: _editable('gender')
                                  ? (value) => setState(() {
                                      _gender = value;
                                      _error = null;
                                    })
                                  : null,
                            )
                          else
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Gender'),
                              subtitle: Text(
                                '${const {'male': 'Male', 'female': 'Female', 'nonbinary': 'Non-binary'}[_original!['gender']] ?? 'Not set'}\nGender can’t be changed.',
                              ),
                              trailing: const Icon(Icons.lock_outline),
                            ),
                          const Divider(height: 32),
                          const Text(
                            'CAMPUS',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if ((_original!['limits'] as Map)['country'] !=
                              null) ...[
                            DropdownButtonFormField<String>(
                              key: const Key('edit-country'),
                              isExpanded: true,
                              initialValue: _country,
                              decoration: const InputDecoration(
                                labelText: 'Country of study',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'US',
                                  child: Text(
                                    'United States',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'CA',
                                  child: Text(
                                    'Canada',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'GB',
                                  child: Text(
                                    'United Kingdom',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'NZ',
                                  child: Text(
                                    'New Zealand',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'SG',
                                  child: Text(
                                    'Singapore',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'HK',
                                  child: Text(
                                    'Hong Kong',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                              onChanged: _editable('country')
                                  ? (value) {
                                      if (value == null || value == _country)
                                        return;
                                      setState(() {
                                        _country = value;
                                        _school = null;
                                        _year.clear();
                                      });
                                    }
                                  : null,
                            ),
                            const SizedBox(height: 16),
                          ],
                          ListTile(
                            key: const Key('edit-campus'),
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              _school?['name'] as String? ??
                                  'Choose your campus',
                            ),
                            subtitle: Text(_hint('schoolId')),
                            trailing: Icon(
                              _editable('schoolId')
                                  ? Icons.chevron_right
                                  : Icons.lock_outline,
                            ),
                            onTap: _editable('schoolId') ? _chooseCampus : null,
                          ),
                          const SizedBox(height: 16),
                          _field(
                            'graduationYear',
                            _year,
                            keyboard: TextInputType.number,
                            validator: (value) {
                              final year = int.tryParse(value ?? '');
                              final current =
                                  DateTime.tryParse(
                                    _original!['serverNow'] as String? ?? '',
                                  )?.year ??
                                  DateTime.now().year;
                              return year != null &&
                                      year >= current - 80 &&
                                      year <= current + 15
                                  ? null
                                  : 'Choose a valid graduation year.';
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _original == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    FilledButton(
                      onPressed:
                          _saving || _checking || _taken || _changes.isEmpty
                          ? null
                          : _saveAndClose,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    ),
  );
}

/// Draft-only selection: no onboarding writes, rewards or limits are consumed.
class _CampusPicker extends ConsumerStatefulWidget {
  const _CampusPicker({required this.country});
  final String country;
  @override
  ConsumerState<_CampusPicker> createState() => _CampusPickerState();
}

class _CampusPickerState extends ConsumerState<_CampusPicker> {
  final _query = TextEditingController();
  late final StorageService _storage;
  late final Future<String?> _owner;
  Timer? _timer;
  int _generation = 0;
  String _cursor = '', _region = '';
  List<Map<String, dynamic>> _schools = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _storage = ref.read(storageServiceProvider);
    _owner = _storage.getToken();
    _storage.addListener(_accountChanged);
  }

  Future<void> _accountChanged() async {
    final expected = await _owner;
    final current = await _storage.getToken();
    if (mounted && expected != current) Navigator.of(context).pop();
  }

  void _changed(String value) {
    _timer?.cancel();
    final generation = ++_generation;
    setState(() {
      _schools = [];
      _cursor = '';
      _error = null;
      _loading = false;
    });
    if (value.trim().length < 3) return;
    _timer = Timer(
      const Duration(milliseconds: 300),
      () => _search(generation),
    );
  }

  void _regionChanged(String? value) {
    _timer?.cancel();
    final generation = ++_generation;
    setState(() {
      _region = value ?? '';
      _schools = [];
      _cursor = '';
      _error = null;
      _loading = false;
    });
    if (_query.text.trim().length >= 3) _search(generation);
  }

  Future<void> _search(int generation, {bool more = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final owner = await _owner;
    try {
      if (owner != await _storage.getToken()) return;
      final data = await ref
          .read(onboardingDetailsProvider)
          .search(
            _query.text.trim(),
            countryOverride: widget.country,
            cursor: more ? _cursor : '',
            region: _region,
          );
      if (!mounted ||
          generation != _generation ||
          owner != await _storage.getToken()) {
        return;
      }
      setState(() {
        _schools = [
          if (more) ..._schools,
          ...(data['schools'] as List? ?? []).map(
            (s) => Map<String, dynamic>.from(s as Map),
          ),
        ];
        _cursor = data['nextCursor'] as String? ?? '';
        _loading = false;
        if (data['available'] == false) {
          _error = 'Campus search is unavailable. Try again.';
        }
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _error = 'Couldn’t load campuses. Try again.';
        });
      }
    }
  }

  void _pick(Map<String, dynamic> school) {
    Navigator.pop(context, school);
  }

  @override
  void dispose() {
    _generation++;
    _storage.removeListener(_accountChanged);
    _timer?.cancel();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .72,
      child: Column(
        children: [
          ListTile(
            title: const Text('Choose your campus'),
            trailing: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ),
          if (SchoolRegions.hasRegions(widget.country))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DropdownButtonFormField<String>(
                key: const Key('campus-pick-region'),
                initialValue: _region,
                isExpanded: true,
                menuMaxHeight: 320,
                decoration: const InputDecoration(
                  labelText: 'State / region (optional)',
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('All regions')),
                  for (final entry in SchoolRegions.forCountry(widget.country))
                    DropdownMenuItem(
                      value: entry.value,
                      child: Text(entry.label, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: _regionChanged,
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _query,
              onChanged: _changed,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Search campuses',
                helperText: 'Enter at least 3 characters',
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            TextButton(
              onPressed: () => _search(_generation, more: _schools.isNotEmpty),
              child: Text('$_error Retry'),
            ),
          Expanded(
            child: ListView(
              children: [
                if (!_loading &&
                    _error == null &&
                    _query.text.trim().length >= 3 &&
                    _schools.isEmpty)
                  const ListTile(title: Text('No campuses found')),
                for (final school in _schools)
                  ListTile(
                    title: Text(school['name'] as String? ?? ''),
                    subtitle: Text(
                      [
                        school['city'],
                        school['region'],
                      ].whereType<String>().join(' · '),
                    ),
                    onTap: () => _pick(school),
                  ),
                if (_cursor.isNotEmpty)
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => _search(_generation, more: true),
                    child: const Text('See more'),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
