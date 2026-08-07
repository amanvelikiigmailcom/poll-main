import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/user_provider.dart';
import '../../router/app_router.dart';
import '../../theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _selectedGradeProvider = StateProvider<int?>((ref) => null);
final _selectedLetterProvider = StateProvider<String?>((ref) => null);

// ---------------------------------------------------------------------------
// ClassScreen
// ---------------------------------------------------------------------------

class ClassScreen extends ConsumerWidget {
  const ClassScreen({super.key});

  static const List<int> _grades = [8, 9, 10, 11, 12];
  static const List<String> _letters = ['А', 'Б', 'В', 'Г', 'Д'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedGrade = ref.watch(_selectedGradeProvider);
    final selectedLetter = ref.watch(_selectedLetterProvider);
    final isLoading = ref.watch(userNotifierProvider).isLoading;

    final canSave = selectedGrade != null && selectedLetter != null;

    Future<void> save() async {
      if (!canSave) return;
      final ok = await ref
          .read(userNotifierProvider.notifier)
          .saveClass(selectedGrade!, gradeClass: selectedLetter);
      if (ok && context.mounted) {
        context.go(AppRoutes.username);
      } else if (context.mounted) {
        final err = ref.read(userNotifierProvider).errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err ?? 'Ошибка. Попробуйте снова.')),
        );
      }
    }

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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              const Text(
                'Выберите класс',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Укажите номер и букву вашего класса',
                style: TextStyle(
                    fontSize: 15, color: AppColors.textSecondary),
              ),

              const SizedBox(height: 32),

              const Text(
                'Номер класса',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              // Grade chips
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _grades.map((grade) {
                  return _SelectChip(
                    label: '$grade',
                    isSelected: selectedGrade == grade,
                    onTap: () => ref
                        .read(_selectedGradeProvider.notifier)
                        .state = grade,
                  );
                }).toList(),
              ),

              const SizedBox(height: 32),

              const Text(
                'Буква класса',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              // Letter chips
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _letters.map((letter) {
                  return _SelectChip(
                    label: letter,
                    isSelected: selectedLetter == letter,
                    onTap: () => ref
                        .read(_selectedLetterProvider.notifier)
                        .state = letter,
                  );
                }).toList(),
              ),

              // Preview badge
              if (canSave) ...[
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 18, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryBlue, Color(0xFF7B9BFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '$selectedGrade$selectedLetter класс',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ],

              const Spacer(),

              _PrimaryButton(
                label: 'Сохранить',
                onPressed: canSave && !isLoading ? save : null,
                isLoading: isLoading,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Select chip
// ---------------------------------------------------------------------------

class _SelectChip extends StatelessWidget {
  const _SelectChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 64,
        height: 52,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppColors.white : AppColors.textPrimary,
          ),
        ),
      ),
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
