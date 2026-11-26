import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/school_regions.dart';
import '../../providers/auth_provider.dart';
import '../../providers/service_providers.dart';
import '../../router/app_router.dart';
import '../../services/content_service.dart';
import '../../services/api_service.dart';
import '../../services/local_game_service.dart';
import '../../services/onboarding_details_service.dart';
import 'profile_details_screen.dart';

class SchoolSetupScreen extends ConsumerStatefulWidget {
  const SchoolSetupScreen({
    super.key,
    this.profileCampus,
    this.campusSessionKey,
  });
  final Map<String, dynamic>? profileCampus;
  final String? campusSessionKey;
  @override
  ConsumerState<SchoolSetupScreen> createState() => _SchoolSetupScreenState();
}

class _SchoolSetupScreenState extends ConsumerState<SchoolSetupScreen> {
  final query = TextEditingController(), year = TextEditingController();
  final form = GlobalKey<FormState>();
  Timer? debounce;
  int generation = 0;
  String country = 'US', cursor = '', regionFilter = '';
  bool loading = true, searching = false, saving = false, available = true;
  String? error;
  List<Map<String, dynamic>> schools = [];
  Map<String, dynamic>? selected;
  final _yearAnchor = GlobalKey();
  int? _confirmedYear;
  Map? get _previous => widget.profileCampus?['school'] as Map?;
  bool get _editing => widget.profileCampus != null;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data =
        widget.profileCampus ??
        await ref.read(onboardingDetailsProvider).read();
    if (!mounted) return;
    final savedYear = data['graduationYear'] as int?;
    final confirmed =
        !_editing &&
        await ref
            .read(onboardingDetailsProvider)
            .isConfirmedCampus(
              (data['school'] as Map?)?['id'] as String?,
              year: savedYear,
            );
    if (!mounted) return;
    setState(() {
      _confirmedYear = confirmed || _editing ? savedYear : null;
      country = data['country'] as String? ?? 'US';
      final hasDraft = !_editing && data['schoolDraftCountry'] == country;
      final draftSchool = hasDraft ? data['schoolDraft'] : data['school'];
      selected = !_editing && draftSchool is Map
          ? Map<String, dynamic>.from(draftSchool)
          : null;
      year.text =
          (hasDraft ? data['schoolYearDraft'] : data['graduationYear'])
              ?.toString() ??
          '';
      if (hasDraft) {
        query.text = data['schoolQueryDraft'] as String? ?? '';
        regionFilter = data['schoolRegionDraft'] as String? ?? '';
      }
      loading = false;
    });
  }

  Future<void> _back() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_editing) {
      Navigator.of(context).pop();
      return;
    }
    await ref.read(onboardingDetailsProvider).draft({
      'schoolDraftCountry': country,
      'schoolDraft': selected,
      'schoolYearDraft': int.tryParse(year.text),
      'schoolQueryDraft': query.text,
      'schoolRegionDraft': regionFilter,
    });
    if (mounted) context.go(AppRoutes.profileDetails);
  }

  void _changed(String value) {
    debounce?.cancel();
    generation++;
    setState(() {
      schools = [];
      cursor = '';
      error = null;
      searching = false;
      selected = null;
    });
    if (value.trim().length < 3) return;
    final expected = generation;
    debounce = Timer(
      const Duration(milliseconds: 300),
      () => _search(expected),
    );
  }

  void _regionChanged(String? value) {
    if (saving) return;
    debounce?.cancel();
    generation++;
    setState(() {
      regionFilter = value ?? '';
      schools = [];
      cursor = '';
      error = null;
      searching = false;
      selected = null;
    });
    // A new region invalidates the list, like a new query does; re-run an
    // existing query immediately instead of waiting for more typing.
    if (query.text.trim().length >= 3) _search(generation);
  }

  void _select(Map<String, dynamic> school) {
    FocusManager.instance.primaryFocus?.unfocus();
    debounce?.cancel();
    generation++;
    setState(() {
      selected = school;
      schools = [];
      cursor = '';
      searching = false;
      error = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final anchor = _yearAnchor.currentContext;
      if (mounted && anchor != null) {
        Scrollable.ensureVisible(
          anchor,
          duration: const Duration(milliseconds: 250),
          alignment: 0.4,
        );
      }
    });
  }

  Future<void> _search(int expected, {bool more = false}) async {
    if (!mounted || expected != generation) return;
    final term = query.text.trim();
    if (term.length < 3) return;
    final storage = ref.read(storageServiceProvider);
    setState(() => searching = true);
    try {
      final owner = await storage.getToken();
      if (!mounted || expected != generation) return;
      final data = await ref
          .read(onboardingDetailsProvider)
          .search(
            term,
            cursor: more ? cursor : '',
            countryOverride: _editing ? country : null,
            region: regionFilter,
          );
      final currentOwner = await storage.getToken();
      if (!mounted || expected != generation || owner != currentOwner) {
        return;
      }
      setState(() {
        schools = [
          if (more) ...schools,
          ...(data['schools'] as List? ?? []).map(
            (e) => Map<String, dynamic>.from(e as Map),
          ),
        ];
        cursor = data['nextCursor'] as String? ?? '';
        available = data['available'] != false;
        searching = false;
        error = null;
      });
    } catch (_) {
      if (mounted && expected == generation) {
        setState(() {
          searching = false;
          error = 'Couldn’t load campuses. Try again.';
        });
      }
    }
  }

  Future<void> _next({bool skip = false}) async {
    if (saving) return;
    if (!skip &&
        (selected == null || !(form.currentState?.validate() ?? false))) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final service = ref.read(onboardingDetailsProvider);
      if (_editing) {
        final campus = selected!;
        final previous = _previous;
        if (previous?['id'] == campus['id']) {
          throw const ApiException(
            'This is already your campus. Choose a different one.',
          );
        }
        final confirmed =
            previous == null ||
            await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Use your one campus change?'),
                    content: Text(
                      'From ${previous['name']}\nTo ${campus['name']}\n\nYou won’t be able to change it again.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Confirm change'),
                      ),
                    ],
                  ),
                ) ==
                true;
        if (!mounted) return;
        if (!confirmed) {
          setState(() => saving = false);
          return;
        }
        await service.changeCampus(
          campusId: campus['id'] as String,
          year: int.parse(year.text),
          countryCode: country,
          confirmChange: previous != null,
          expectedCampusId: previous?['id'] as String?,
          sessionKey: widget.campusSessionKey!,
        );
        if (mounted) Navigator.of(context).pop(true);
        return;
      }
      if (skip) {
        await service.skipSchool();
      } else {
        await service.selectSchool(selected!, int.parse(year.text));
      }
      if ((await service.read())['status'] == 'waiting') {
        if (mounted) context.go(AppRoutes.schoolWaiting);
        return;
      }
      await service.draft({
        'schoolDraftCountry': null,
        'schoolDraft': null,
        'schoolYearDraft': null,
        'schoolQueryDraft': null,
        'schoolRegionDraft': null,
      });
      final schoolReady =
          !skip && (await service.read())['stage'] == 'username';
      final hasNames = await LocalGameService.instance.hasEnoughNames();
      final pendingUsername = await LocalGameService.instance
          .isUsernameSetupPending();
      if (!mounted) return;
      if (hasNames && !pendingUsername) {
        await service.finish();
        if (mounted) context.go(AppRoutes.home);
      } else {
        context.go(schoolReady ? AppRoutes.username : AppRoutes.namesEntry);
      }
    } catch (failure) {
      if (mounted) {
        setState(() {
          saving = false;
          error = failure is ApiException
              ? failure.message
              : 'Couldn’t save your campus. Please try again.';
        });
      }
    }
  }

  Future<void> _missing() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await ref.read(onboardingDetailsProvider).draft({
      'missingSchool': query.text.trim(),
      'graduationYear': int.tryParse(year.text),
    });
    if (mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MissingSchoolScreen(country: country),
        ),
      );
    }
  }

  @override
  void dispose() {
    generation++;
    debounce?.cancel();
    query.dispose();
    year.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: ContentService.instance,
    builder: (context, _) => SetupFormPage(
      title: _editing && _previous != null
          ? 'Change campus'
          : 'Choose your campus',
      subtitle:
          '${['US', 'CA'].contains(country)
              ? 'United States & Canada'
              : country == 'GB'
              ? 'United Kingdom · England directory'
              : country}\nChoose your campus and graduation year.',
      back: saving ? null : _back,
      children: [
        if (loading)
          const Center(child: CircularProgressIndicator(color: Colors.white))
        else ...[
          if (SchoolRegions.hasRegions(country))
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: DropdownButtonFormField<String>(
                key: const Key('school-region'),
                initialValue: regionFilter,
                isExpanded: true,
                menuMaxHeight: 320,
                decoration: setupInput('State / region (optional)'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('All regions')),
                  for (final entry in SchoolRegions.forCountry(country))
                    DropdownMenuItem(
                      value: entry.value,
                      child: Text(entry.label, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: saving ? null : _regionChanged,
              ),
            ),
          TextField(
            key: const Key('school-search'),
            controller: query,
            enabled: !saving,
            onChanged: _changed,
            style: const TextStyle(fontSize: 16),
            decoration: setupInput(
              'Search campuses',
            ).copyWith(hintText: 'Name, city or region', hintMaxLines: 2),
          ),
          const SizedBox(height: 12),
          if (searching)
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          if (query.text.trim().length < 3 && selected == null)
            const Text(
              'Enter at least 3 characters.',
              style: TextStyle(color: Colors.white70),
            ),
          if (!searching &&
              selected == null &&
              schools.isEmpty &&
              query.text.trim().length >= 3 &&
              error == null)
            Text(
              available
                  ? 'No matching campuses. Try another name or region.'
                  : 'The campus directory for this country is not available yet.',
              style: const TextStyle(color: Colors.white),
            ),
          for (final school in schools)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                onPressed: saving ? null : () => _select(school),
                style: OutlinedButton.styleFrom(
                  foregroundColor: selected?['id'] == school['id']
                      ? onboardingBlue
                      : Colors.white,
                  backgroundColor: selected?['id'] == school['id']
                      ? Colors.white
                      : Colors.transparent,
                  side: const BorderSide(color: Colors.white70),
                  padding: const EdgeInsets.all(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(school['name'] as String),
                    Text(
                      [
                        school['city'],
                        school['region'],
                        school['country'],
                      ].where((s) => s != null && s != '').join(' · '),
                    ),
                  ],
                ),
              ),
            ),
          if (cursor.isNotEmpty)
            TextButton(
              onPressed: searching
                  ? null
                  : () => _search(generation, more: true),
              child: const Text(
                'Load more',
                style: TextStyle(color: Colors.white),
              ),
            ),
          if (selected != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(Icons.check_circle, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    selected!['name'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [selected!['city'], selected!['region']]
                        .whereType<String>()
                        .where((s) => s.isNotEmpty)
                        .join(' · '),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: saving ? null : () => _changed(query.text),
                      child: const Text(
                        'Change',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Form(
            key: form,
            child: SizedBox(
              key: _yearAnchor,
              child: GraduationYearPicker(
                controller: year,
                enabled: !saving,
                existingYear: _confirmedYear,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (error != null)
            Semantics(
              liveRegion: true,
              child: Text(error!, style: const TextStyle(color: Colors.white)),
            ),
          if (error == 'Couldn’t load campuses. Try again.')
            TextButton(
              onPressed: searching
                  ? null
                  : () => _search(generation, more: cursor.isNotEmpty),
              child: const Text(
                'Retry search',
                style: TextStyle(color: Colors.white),
              ),
            ),
          if (!_editing)
            TextButton(
              onPressed: saving ? null : _missing,
              child: const Text(
                'I can’t find my campus',
                style: TextStyle(color: Colors.white),
              ),
            ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: saving || selected == null ? null : () => _next(),
            style: setupButton(),
            child: Text(
              saving
                  ? 'Please wait…'
                  : _editing
                  ? 'Save campus'
                  : 'Continue',
            ),
          ),
          if (!_editing &&
              ContentService.instance.flag('school_skip_enabled') &&
              ref.read(storageServiceProvider).reviewerSkipsAllowed)
            TextButton(
              key: const Key('skip-school'),
              onPressed: saving ? null : () => _next(skip: true),
              child: const Text(
                'Skip for now',
                style: TextStyle(color: Colors.white),
              ),
            ),
          if (!_editing)
            Text(
              ref.read(storageServiceProvider).reviewerSkipsAllowed
                  ? 'Quiz play opens after you choose a campus. Skipping lets you finish setting up your profile.'
                  : 'Quiz play opens after you choose a campus.',
              style: const TextStyle(color: Colors.white70, height: 1.4),
            ),
        ],
      ],
    ),
  );
}

class MissingSchoolScreen extends ConsumerStatefulWidget {
  const MissingSchoolScreen({super.key, required this.country});
  final String country;
  @override
  ConsumerState<MissingSchoolScreen> createState() =>
      _MissingSchoolScreenState();
}

String campusRegionLabel(String country) => switch (country) {
  'US' || 'AU' => 'State / territory',
  'CA' => 'Province / territory',
  'GB' => 'County / region',
  'SG' => 'District',
  'HK' => 'District',
  _ => 'Region',
};

class _MissingSchoolScreenState extends ConsumerState<MissingSchoolScreen> {
  final name = TextEditingController(),
      city = TextEditingController(),
      region = TextEditingController(),
      year = TextEditingController();
  final form = GlobalKey<FormState>();
  String? error;
  bool saving = false, loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await ref.read(onboardingDetailsProvider).read();
    if (!mounted) return;
    setState(() {
      name.text = data['missingSchool'] as String? ?? '';
      city.text = data['missingCity'] as String? ?? '';
      region.text = data['missingRegion'] as String? ?? '';
      year.text = data['graduationYear']?.toString() ?? '';
      loading = false;
    });
  }

  Future<void> _email() async {
    if (saving || !(form.currentState?.validate() ?? false)) return;
    setState(() {
      saving = true;
      error = null;
    });
    FocusManager.instance.primaryFocus?.unfocus();
    final service = ref.read(onboardingDetailsProvider);
    try {
      await service.draft({
        'missingSchool': name.text.trim(),
        'missingCity': city.text.trim(),
        'missingRegion': region.text.trim(),
        'graduationYear': int.tryParse(year.text),
      });
      await service.requestSchool(
        name: name.text,
        city: city.text,
        region: region.text,
        year: int.parse(year.text),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = 'Couldn’t save your campus request. Try again.';
        });
      }
      return;
    }
    if (!mounted) return;
    final uri = OnboardingDetailsService.schoolEmail(
      email: ContentService.instance.text('support_email'),
      name: name.text,
      country: widget.country,
      city: city.text,
      region: region.text,
      year: year.text,
    );
    try {
      if (!await launchUrl(uri)) throw StateError('Mail unavailable');
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Couldn’t open Mail. You can email ${ContentService.instance.text('support_email')} with the campus details below.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    name.dispose();
    city.dispose();
    region.dispose();
    year.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SetupFormPage(
    title: 'Add your campus',
    subtitle:
        'Send the campus details to our team. Quiz play will be available after your campus is added and you select it. Opening Mail does not send the request.',
    back: () => Navigator.of(context).pop(),
    children: [
      if (loading)
        const Center(child: CircularProgressIndicator(color: Colors.white))
      else
        Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Country: ${widget.country}',
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              for (final field in [
                (name, 'Campus name', 'Enter the campus name.', 256),
                (city, 'City', 'Enter the city.', 128),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    controller: field.$1,
                    enabled: !saving,
                    maxLength: field.$4,
                    style: const TextStyle(fontSize: 16),
                    decoration: setupInput(field.$2),
                    validator: (v) {
                      final value = v?.trim() ?? '';
                      if (value.isEmpty) return field.$3;
                      if (value.length > field.$4) {
                        return 'Use ${field.$4} characters or fewer.';
                      }
                      if (RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
                        return 'Remove line breaks or tabs.';
                      }
                      return null;
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SchoolRegions.hasRegions(widget.country)
                    ? _RegionPicker(
                        country: widget.country,
                        controller: region,
                        enabled: !saving,
                      )
                    : TextFormField(
                        controller: region,
                        enabled: !saving,
                        maxLength: 128,
                        style: const TextStyle(fontSize: 16),
                        decoration: setupInput(
                          campusRegionLabel(widget.country),
                        ),
                        validator: (v) {
                          final value = v?.trim() ?? '';
                          if (value.isEmpty) {
                            return 'Enter the state or region.';
                          }
                          if (value.length > 128) {
                            return 'Use 128 characters or fewer.';
                          }
                          if (RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
                            return 'Remove line breaks or tabs.';
                          }
                          return null;
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: GraduationYearPicker(controller: year, enabled: !saving),
              ),
              if (error != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ElevatedButton(
                onPressed: saving ? null : _email,
                style: setupButton(),
                child: Text(saving ? 'Preparing…' : 'Prepare email'),
              ),
            ],
          ),
        ),
    ],
  );
}

/// Canonical region dropdown for the missing-campus request.
///
/// The controller holds the exact server value (`TEXAS`), not the display
/// label, so the stored request matches `school_directory.region` verbatim.
class _RegionPicker extends StatelessWidget {
  const _RegionPicker({
    required this.country,
    required this.controller,
    required this.enabled,
  });
  final String country;
  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final entries = SchoolRegions.forCountry(country);
    final current = controller.text;
    return DropdownButtonFormField<String>(
      key: const Key('missing-region'),
      initialValue: entries.any((e) => e.value == current) ? current : null,
      isExpanded: true,
      menuMaxHeight: 320,
      decoration: setupInput(campusRegionLabel(country)),
      items: [
        for (final entry in entries)
          DropdownMenuItem(
            value: entry.value,
            child: Text(entry.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: enabled ? (value) => controller.text = value ?? '' : null,
      validator: (value) => value == null
          ? 'Enter the ${campusRegionLabel(country).toLowerCase()}.'
          : null,
    );
  }
}

class SchoolWaitingScreen extends ConsumerStatefulWidget {
  const SchoolWaitingScreen({super.key});
  @override
  ConsumerState<SchoolWaitingScreen> createState() =>
      _SchoolWaitingScreenState();
}

class _SchoolWaitingScreenState extends ConsumerState<SchoolWaitingScreen> {
  Map<String, dynamic> data = {};
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool online = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    final service = ref.read(onboardingDetailsProvider);
    try {
      if (online && !await service.restore(requireOnline: true)) {
        throw const ApiException('Sign in again to check availability.');
      }
      final next = await service.read();
      if (mounted) setState(() => data = next);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Couldn’t check availability. Your request is still saved. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _support() async {
    final email = ContentService.instance.text('support_email');
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': 'Flyprox campus launch request',
        'body':
            'Hello Flyprox,\n\nI would like Flyprox to open at my campus.\nCampus: ${(data['school'] as Map?)?['name'] ?? data['requestedSchool'] ?? ''}\nRegion: ${data['requestedRegion'] ?? ''}\nCountry: ${data['country'] ?? ''}\n\nThank you!',
      },
    );
    try {
      if (email.isNotEmpty && await launchUrl(uri)) return;
    } catch (_) {
      /* Show the address without claiming the email was sent. */
    }
    if (mounted) {
      setState(
        () => error = email.isEmpty
            ? 'Support is temporarily unavailable. Please try again.'
            : 'Email our team at $email.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final waiting = data['status'] == 'waiting';
    final campus =
        (data['school'] as Map?)?['name'] ??
        data['requestedSchool'] ??
        'your campus';
    return SetupFormPage(
      title: waiting
          ? 'Your campus isn’t available yet'
          : 'Choose your campus to play',
      subtitle: waiting
          ? 'Flyprox hasn’t launched at $campus yet. We’ve saved your request. Contact our support team to register your interest. Demand helps us decide which regions to open next.'
          : 'Voting will be available after you select your campus. If it is missing, send its details to our team.',
      children: [
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(error!, style: const TextStyle(color: Colors.white)),
          ),
        if (waiting) ...[
          ElevatedButton(
            style: setupButton(),
            onPressed: _support,
            child: const Text('Contact support'),
          ),
          const SizedBox(height: 12),
          if (data['campusAvailable'] == true)
            ElevatedButton(
              style: setupButton(),
              onPressed: () => context.go(AppRoutes.schoolSetup),
              child: const Text('Continue with your campus'),
            )
          else
            TextButton(
              onPressed: busy ? null : () => _load(online: true),
              child: Text(
                busy ? 'Checking…' : 'Check availability',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          TextButton(
            onPressed: busy
                ? null
                : () async {
                    await ref.read(authNotifierProvider.notifier).logout();
                    if (context.mounted) context.go(AppRoutes.phone);
                  },
            child: const Text(
              'Sign out',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ] else ...[
          ElevatedButton(
            style: setupButton(),
            onPressed: () => context.go(AppRoutes.schoolSetup),
            child: const Text('Choose your campus'),
          ),
          TextButton(
            onPressed: () => context.go(AppRoutes.home),
            child: const Text(
              'Back to Home',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ],
    );
  }
}

/// Graduation cohorts offered during campus setup, in ascending order.
class GraduationYearPicker extends StatelessWidget {
  const GraduationYearPicker({
    super.key,
    required this.controller,
    this.enabled = true,
    this.existingYear,
  });
  final TextEditingController controller;
  final bool enabled;
  final int? existingYear;
  static List<int> choices([int? current]) {
    return List.generate(16, (index) => 2026 + index);
  }

  @override
  Widget build(BuildContext context) {
    final selected = int.tryParse(controller.text);
    final years = choices();
    if (existingYear != null &&
        OnboardingDetailsService.validYear(existingYear!) &&
        !years.contains(existingYear)) {
      years.add(existingYear!);
      years.sort();
    }
    return DropdownButtonFormField<int>(
      key: const Key('graduation-year'),
      initialValue: years.contains(selected) ? selected : null,
      isExpanded: true,
      menuMaxHeight: 320,
      decoration: setupInput('Graduation year'),
      items: [
        for (final value in years)
          DropdownMenuItem(value: value, child: Text('$value')),
      ],
      onChanged: enabled
          ? (value) {
              controller.text = value?.toString() ?? '';
            }
          : null,
      validator: (value) =>
          value == null ? 'Choose your graduation year.' : null,
    );
  }
}
