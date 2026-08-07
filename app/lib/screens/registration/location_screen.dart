import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/city.dart';
import '../../providers/service_providers.dart';
import '../../providers/user_provider.dart';
import '../../router/app_router.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Provider: city search
// ---------------------------------------------------------------------------

final _citySearchProvider =
    StateNotifierProvider<_CitySearchNotifier, _CitySearchState>((ref) {
  return _CitySearchNotifier(ref.watch(apiServiceProvider));
});

class _CitySearchState {
  final List<City> cities;
  final bool isLoading;
  final String? error;

  const _CitySearchState({
    this.cities = const [],
    this.isLoading = false,
    this.error,
  });

  _CitySearchState copyWith({
    List<City>? cities,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      _CitySearchState(
        cities: cities ?? this.cities,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error ?? this.error,
      );
}

class _CitySearchNotifier extends StateNotifier<_CitySearchState> {
  final ApiService _api;
  Timer? _debounce;

  _CitySearchNotifier(this._api) : super(const _CitySearchState()) {
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _api.get<List<dynamic>>('/api/cities');
      final cities = (response.data ?? [])
          .map((e) => City.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(cities: cities, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Ошибка загрузки городов');
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
        '/api/cities',
        queryParameters: {'q': query},
      );
      final cities = (response.data ?? [])
          .map((e) => City.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(cities: cities, isLoading: false);
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

final _selectedCityProvider = StateProvider<City?>((ref) => null);

// ---------------------------------------------------------------------------
// LocationScreen
// ---------------------------------------------------------------------------

class LocationScreen extends ConsumerStatefulWidget {
  const LocationScreen({super.key});

  @override
  ConsumerState<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends ConsumerState<LocationScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final city = ref.read(_selectedCityProvider);
    if (city == null) return;

    final ok = await ref.read(userNotifierProvider.notifier).saveProfile({
      'cityId': city.id,
      'cityName': city.name,
    });

    if (ok && mounted) {
      context.go(AppRoutes.school);
    } else if (mounted) {
      final err = ref.read(userNotifierProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err ?? 'Ошибка. Попробуйте снова.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(_citySearchProvider);
    final selectedCity = ref.watch(_selectedCityProvider);
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
                    'Выберите ваш город',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Мы покажем школы и друзей поблизости',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),

            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: _searchController,
                onChanged: ref.read(_citySearchProvider.notifier).search,
                style: const TextStyle(
                    fontSize: 16, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Поиск города...',
                  hintStyle: const TextStyle(color: AppColors.textHint),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppColors.textSecondary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded,
                              color: AppColors.textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(_citySearchProvider.notifier).search('');
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

            // City list
            Expanded(child: _buildList(searchState, selectedCity)),

            // Bottom section
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      // TODO: open support
                    },
                    child: const Text(
                      'Нет вашей локации? Написать в поддержку',
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
                    onPressed: selectedCity != null && !isUserLoading
                        ? _save
                        : null,
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

  Widget _buildList(_CitySearchState state, City? selected) {
    if (state.isLoading) {
      return _SkeletonList();
    }

    if (state.error != null) {
      return Center(
          child: Text(state.error!,
              style: const TextStyle(color: AppColors.error)));
    }

    if (state.cities.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_outlined,
                size: 56, color: AppColors.textHint),
            SizedBox(height: 12),
            Text(
              'Город не найден',
              style: TextStyle(fontSize: 17, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      itemCount: state.cities.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AppColors.divider),
      itemBuilder: (context, index) {
        final city = state.cities[index];
        final isSelected = selected?.id == city.id;
        return InkWell(
          onTap: () =>
              ref.read(_selectedCityProvider.notifier).state = city,
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
                        city.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? AppColors.primaryBlue
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (city.region.isNotEmpty)
                        Text(
                          city.region,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ),
                Radio<City>(
                  value: city,
                  groupValue: selected,
                  onChanged: (v) =>
                      ref.read(_selectedCityProvider.notifier).state = v,
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
// Skeleton loader
// ---------------------------------------------------------------------------

class _SkeletonList extends StatefulWidget {
  @override
  State<_SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<_SkeletonList>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _animation =
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) {
        final color = Color.lerp(
            AppColors.shimmerBase, AppColors.shimmerHighlight, _animation.value)!;
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          itemCount: 8,
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
                        width: 140,
                        decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(8))),
                    const SizedBox(height: 6),
                    Container(
                        height: 12,
                        width: 100,
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
