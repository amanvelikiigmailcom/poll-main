import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/school.dart';
import '../../providers/service_providers.dart';
import '../../providers/user_provider.dart';
import '../../router/app_router.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _schoolSearchProvider =
    StateNotifierProvider<_SchoolSearchNotifier, _SchoolSearchState>((ref) {
  final cityId = ref.watch(userNotifierProvider).user?.cityId ?? '';
  return _SchoolSearchNotifier(ref.watch(apiServiceProvider), cityId);
});

class _SchoolSearchState {
  final List<School> schools;
  final bool isLoading;
  final String? error;

  const _SchoolSearchState({
    this.schools = const [],
    this.isLoading = false,
    this.error,
  });

  _SchoolSearchState copyWith({
    List<School>? schools,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      _SchoolSearchState(
        schools: schools ?? this.schools,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error ?? this.error,
      );
}

class _SchoolSearchNotifier extends StateNotifier<_SchoolSearchState> {
  final ApiService _api;
  final String _cityId;
  Timer? _debounce;

  _SchoolSearchNotifier(this._api, this._cityId)
      : super(const _SchoolSearchState()) {
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _api.get<List<dynamic>>(
        '/api/schools',
        queryParameters: _cityId.isNotEmpty ? {'cityId': _cityId} : null,
      );
      final schools = (response.data ?? [])
          .map((e) => School.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(schools: schools, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Ошибка загрузки школ');
    }
  }

  void search(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (query.trim().isEmpty) {
        _fetchAll();
      } else {
        _searchRemote(query.trim());
      }
    });
  }

  Future<void> _searchRemote(String query) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _api.get<List<dynamic>>(
        '/api/schools',
        queryParameters: {
          'q': query,
          if (_cityId.isNotEmpty) 'cityId': _cityId,
        },
      );
      final schools = (response.data ?? [])
          .map((e) => School.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(schools: schools, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Ошибка поиска');
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final _selectedSchoolProvider = StateProvider<School?>((ref) => null);

// ---------------------------------------------------------------------------
// SchoolScreen
// ---------------------------------------------------------------------------

class SchoolScreen extends ConsumerStatefulWidget {
  const SchoolScreen({super.key});

  @override
  ConsumerState<SchoolScreen> createState() => _SchoolScreenState();
}

class _SchoolScreenState extends ConsumerState<SchoolScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final school = ref.read(_selectedSchoolProvider);
    if (school == null) return;

    final ok =
        await ref.read(userNotifierProvider.notifier).saveSchool(school.id);
    if (ok && mounted) {
      context.go(AppRoutes.classSelect);
    } else if (mounted) {
      final err = ref.read(userNotifierProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err ?? 'Ошибка. Попробуйте снова.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(_schoolSearchProvider);
    final selectedSchool = ref.watch(_selectedSchoolProvider);
    final isUserLoading = ref.watch(userNotifierProvider).isLoading;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary),
          onPressed: () => context.canPop() ? context.pop() : null,
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Выберите школу',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),

            // Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: _searchController,
                onChanged: ref.read(_schoolSearchProvider.notifier).search,
                style: const TextStyle(
                    fontSize: 16, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Поиск школы...',
                  hintStyle: const TextStyle(color: AppColors.textHint),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppColors.textSecondary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded,
                              color: AppColors.textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            ref
                                .read(_schoolSearchProvider.notifier)
                                .search('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                        color: AppColors.borderFocused, width: 2),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // List
            Expanded(child: _buildList(searchState, selectedSchool)),

            // Bottom
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      // TODO: open support
                    },
                    child: const Text(
                      'Нет вашей школы? Написать в поддержку',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.primaryBlue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _PrimaryButton(
                    label: 'Сохранить',
                    onPressed:
                        selectedSchool != null && !isUserLoading ? _save : null,
                    isLoading: isUserLoading,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(_SchoolSearchState state, School? selected) {
    if (state.isLoading) return _SkeletonList();

    if (state.error != null) {
      return Center(
          child: Text(state.error!,
              style: const TextStyle(color: AppColors.error)));
    }

    if (state.schools.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school_outlined,
                size: 56, color: AppColors.textHint),
            SizedBox(height: 12),
            Text(
              'Школы не найдены',
              style:
                  TextStyle(fontSize: 17, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      itemCount: state.schools.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AppColors.divider),
      itemBuilder: (context, index) {
        final school = state.schools[index];
        final isSelected = selected?.id == school.id;
        return InkWell(
          onTap: () =>
              ref.read(_selectedSchoolProvider.notifier).state = school,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        school.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? AppColors.primaryBlue
                              : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        school.cityName,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Radio<School>(
                  value: school,
                  groupValue: selected,
                  onChanged: (v) =>
                      ref.read(_selectedSchoolProvider.notifier).state = v,
                  activeColor: AppColors.primaryBlue,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton
// ---------------------------------------------------------------------------

class _SkeletonList extends StatefulWidget {
  @override
  State<_SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<_SkeletonList>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final color = Color.lerp(
            AppColors.shimmerBase, AppColors.shimmerHighlight, _anim.value)!;
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          itemCount: 7,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: AppColors.divider),
          itemBuilder: (_, __) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        height: 16,
                        width: 200,
                        decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(8))),
                    const SizedBox(height: 6),
                    Container(
                        height: 12,
                        width: 120,
                        decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(6))),
                  ],
                ),
              ),
              Container(
                  width: 24,
                  height: 24,
                  decoration:
                      BoxDecoration(shape: BoxShape.circle, color: color)),
            ]),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Primary button
// ---------------------------------------------------------------------------

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentRed,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.textHint,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        onPressed: onPressed,
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: AppColors.white, strokeWidth: 2.5))
            : Text(label,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
