import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../router/app_router.dart';

class BeforeVoteScreen extends StatelessWidget {
  const BeforeVoteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              _IllustrationSection(),
              const SizedBox(height: 40),
              const Text(
                'Жди друзей!',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'В твоей школе пока мало участников. Пригласи друзей чтобы начать голосовать',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                decoration: BoxDecoration(
                  color: AppColors.accentRed.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.accentRed.withOpacity(0.25)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('👥', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 10),
                    Text(
                      'В школе: 3 из 5 участников',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentRed,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => context.push(AppRoutes.invite),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                  textStyle: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Пригласить'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.go(AppRoutes.beforeVote2),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppColors.border, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  foregroundColor: AppColors.textSecondary,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: const Text('Продолжить без друзей'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _IllustrationSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withOpacity(0.06),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '🏫',
            style: TextStyle(fontSize: 56),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _EmojiAvatar(emoji: '😊', color: AppColors.primaryBlue),
              const SizedBox(width: 8),
              _EmojiAvatar(emoji: '🙂', color: AppColors.accentRed),
              const SizedBox(width: 8),
              const _EmojiAvatar(emoji: '', color: AppColors.border, isPlaceholder: true),
              const SizedBox(width: 8),
              const _EmojiAvatar(emoji: '', color: AppColors.border, isPlaceholder: true),
              const SizedBox(width: 8),
              const _EmojiAvatar(emoji: '', color: AppColors.border, isPlaceholder: true),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '3 / 5 участников',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textHint,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmojiAvatar extends StatelessWidget {
  final String emoji;
  final Color color;
  final bool isPlaceholder;

  const _EmojiAvatar({
    required this.emoji,
    required this.color,
    this.isPlaceholder = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isPlaceholder ? Colors.transparent : color.withOpacity(0.15),
        shape: BoxShape.circle,
        border: Border.all(
          color: isPlaceholder ? AppColors.border : color.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Center(
        child: isPlaceholder
            ? const Icon(Icons.add, color: AppColors.textHint, size: 18)
            : Text(emoji, style: const TextStyle(fontSize: 22)),
      ),
    );
  }
}
