import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../router/app_router.dart';
import '../../utils/helpers.dart';

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

class PollOption {
  final String id;
  final String name;
  final String grade;
  final String? avatarUrl;

  const PollOption({
    required this.id,
    required this.name,
    required this.grade,
    this.avatarUrl,
  });
}

class PollQuestion {
  final String id;
  final String question;
  final String emoji;
  final String category; // humor | normal | sympathy
  final List<PollOption> options;

  const PollQuestion({
    required this.id,
    required this.question,
    required this.emoji,
    required this.category,
    required this.options,
  });
}

// ---------------------------------------------------------------------------
// Sample data (replace with API)
// ---------------------------------------------------------------------------

final _sampleQuestions = [
  const PollQuestion(
    id: '1',
    question: 'Кто самый смешной в классе?',
    emoji: '😄',
    category: 'humor',
    options: [
      PollOption(id: 'u1', name: 'Арман Никитенко', grade: '9 класс'),
      PollOption(id: 'u2', name: 'Александр Иванов', grade: '10 класс'),
      PollOption(id: 'u3', name: 'Виталий Магомедов', grade: '11 класс'),
      PollOption(id: 'u4', name: 'Алия Искакова', grade: '10 класс'),
    ],
  ),
  const PollQuestion(
    id: '2',
    question: 'Кто самый умный?',
    emoji: '🧠',
    category: 'normal',
    options: [
      PollOption(id: 'u5', name: 'Мария Петрова', grade: '9 класс'),
      PollOption(id: 'u6', name: 'Денис Козлов', grade: '10 класс'),
      PollOption(id: 'u7', name: 'Айгуль Сейткали', grade: '9 класс'),
      PollOption(id: 'u8', name: 'Роман Сидоров', grade: '11 класс'),
    ],
  ),
  const PollQuestion(
    id: '3',
    question: 'Кто тебе нравится?',
    emoji: '❤️',
    category: 'sympathy',
    options: [
      PollOption(id: 'u5', name: 'Мария Петрова', grade: '9 класс'),
      PollOption(id: 'u7', name: 'Айгуль Сейткали', grade: '9 класс'),
      PollOption(id: 'u4', name: 'Алия Искакова', grade: '10 класс'),
      PollOption(id: 'u10', name: 'Ксения Волкова', grade: '9 класс'),
    ],
  ),
  const PollQuestion(
    id: '4',
    question: 'Кто самый смелый?',
    emoji: '💪',
    category: 'normal',
    options: [
      PollOption(id: 'u1', name: 'Арман Никитенко', grade: '9 класс'),
      PollOption(id: 'u13', name: 'Дария Морозова', grade: '9 класс'),
      PollOption(id: 'u3', name: 'Виталий Магомедов', grade: '11 класс'),
      PollOption(id: 'u6', name: 'Денис Козлов', grade: '10 класс'),
    ],
  ),
  const PollQuestion(
    id: '5',
    question: 'Похож на Илона Маска?',
    emoji: '🚀',
    category: 'humor',
    options: [
      PollOption(id: 'u2', name: 'Александр Иванов', grade: '10 класс'),
      PollOption(id: 'u11', name: 'Максим Яковлев', grade: '11 класс'),
      PollOption(id: 'u9', name: 'Тимур Батрудинов', grade: '10 класс'),
      PollOption(id: 'u8', name: 'Роман Сидоров', grade: '11 класс'),
    ],
  ),
  const PollQuestion(
    id: '6',
    question: 'Кто лучший друг?',
    emoji: '👫',
    category: 'normal',
    options: [
      PollOption(id: 'u12', name: 'Нурлан Асканов', grade: '10 класс'),
      PollOption(id: 'u1', name: 'Арман Никитенко', grade: '9 класс'),
      PollOption(id: 'u13', name: 'Дария Морозова', grade: '9 класс'),
      PollOption(id: 'u6', name: 'Денис Козлов', grade: '10 класс'),
    ],
  ),
  const PollQuestion(
    id: '7',
    question: 'Кто самый красивый?',
    emoji: '😍',
    category: 'sympathy',
    options: [
      PollOption(id: 'u1', name: 'Арман Никитенко', grade: '9 класс'),
      PollOption(id: 'u2', name: 'Александр Иванов', grade: '10 класс'),
      PollOption(id: 'u3', name: 'Виталий Магомедов', grade: '11 класс'),
      PollOption(id: 'u4', name: 'Алия Искакова', grade: '10 класс'),
    ],
  ),
  const PollQuestion(
    id: '8',
    question: 'Кто самый спортивный?',
    emoji: '⚽',
    category: 'normal',
    options: [
      PollOption(id: 'u3', name: 'Виталий Магомедов', grade: '11 класс'),
      PollOption(id: 'u11', name: 'Максим Яковлев', grade: '11 класс'),
      PollOption(id: 'u2', name: 'Александр Иванов', grade: '10 класс'),
      PollOption(id: 'u9', name: 'Тимур Батрудинов', grade: '10 класс'),
    ],
  ),
  const PollQuestion(
    id: '9',
    question: 'Кто станет известным?',
    emoji: '🌟',
    category: 'normal',
    options: [
      PollOption(id: 'u8', name: 'Роман Сидоров', grade: '11 класс'),
      PollOption(id: 'u5', name: 'Мария Петрова', grade: '9 класс'),
      PollOption(id: 'u4', name: 'Алия Искакова', grade: '10 класс'),
      PollOption(id: 'u7', name: 'Айгуль Сейткали', grade: '9 класс'),
    ],
  ),
  const PollQuestion(
    id: '10',
    question: 'Кто лучше всех поёт?',
    emoji: '🎤',
    category: 'humor',
    options: [
      PollOption(id: 'u10', name: 'Ксения Волкова', grade: '9 класс'),
      PollOption(id: 'u13', name: 'Дария Морозова', grade: '9 класс'),
      PollOption(id: 'u1', name: 'Арман Никитенко', grade: '9 класс'),
      PollOption(id: 'u12', name: 'Нурлан Асканов', grade: '10 класс'),
    ],
  ),
  const PollQuestion(
    id: '11',
    question: 'Кто мощный человек?',
    emoji: '💎',
    category: 'sympathy',
    options: [
      PollOption(id: 'u3', name: 'Виталий Магомедов', grade: '11 класс'),
      PollOption(id: 'u8', name: 'Роман Сидоров', grade: '11 класс'),
      PollOption(id: 'u2', name: 'Александр Иванов', grade: '10 класс'),
      PollOption(id: 'u11', name: 'Максим Яковлев', grade: '11 класс'),
    ],
  ),
  const PollQuestion(
    id: '12',
    question: 'Воин в душе?',
    emoji: '⚔️',
    category: 'humor',
    options: [
      PollOption(id: 'u9', name: 'Тимур Батрудинов', grade: '10 класс'),
      PollOption(id: 'u6', name: 'Денис Козлов', grade: '10 класс'),
      PollOption(id: 'u1', name: 'Арман Никитенко', grade: '9 класс'),
      PollOption(id: 'u7', name: 'Айгуль Сейткали', grade: '9 класс'),
    ],
  ),
];

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class VoteScreen extends StatefulWidget {
  const VoteScreen({super.key});

  @override
  State<VoteScreen> createState() => _VoteScreenState();
}

class _VoteScreenState extends State<VoteScreen>
    with SingleTickerProviderStateMixin {
  static const int _totalQuestions = 12;

  int _currentIndex = 0;
  String? _selectedOptionId;
  bool _isAdvancing = false;
  late List<PollOption> _shuffledOptions;

  // Slide transition
  late AnimationController _slideController;
  late Animation<Offset> _slideIn;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideIn = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _fadeAnim = CurvedAnimation(parent: _slideController, curve: Curves.easeOut);
    _shuffledOptions = List.from(_sampleQuestions[_currentIndex].options);
    _slideController.value = 1.0; // start visible
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  PollQuestion get _currentQuestion => _sampleQuestions[_currentIndex];

  void _selectOption(String optionId) {
    if (_selectedOptionId != null || _isAdvancing) return;
    HapticFeedback.lightImpact();
    setState(() => _selectedOptionId = optionId);
    _autoAdvance();
  }

  Future<void> _autoAdvance() async {
    setState(() => _isAdvancing = true);
    // Brief pause to show selection highlight
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    // Slide out
    await _slideController.reverse();
    if (!mounted) return;
    if (_currentIndex >= _totalQuestions - 1) {
      context.go(AppRoutes.starReceived);
    } else {
      setState(() {
        _currentIndex++;
        _selectedOptionId = null;
        _isAdvancing = false;
        _shuffledOptions = List.from(_sampleQuestions[_currentIndex].options);
      });
      await _slideController.forward();
    }
  }

  void _skipQuestion() {
    if (_isAdvancing) return;
    HapticFeedback.lightImpact();
    setState(() {
      _selectedOptionId = null;
      _isAdvancing = false;
    });
    _autoAdvance();
  }

  void _shuffleOptions() {
    if (_selectedOptionId != null) return;
    HapticFeedback.selectionClick();
    setState(() => _shuffledOptions.shuffle());
  }

  // Category helpers
  Color _catBg(String cat) {
    switch (cat) {
      case 'humor': return AppColors.humorCategory;
      case 'sympathy': return AppColors.sympathyCategory;
      default: return AppColors.normalCategory;
    }
  }

  Color _catFg(String cat) {
    switch (cat) {
      case 'humor': return AppColors.humorCategoryText;
      case 'sympathy': return AppColors.sympathyCategoryText;
      default: return AppColors.normalCategoryText;
    }
  }

  String _catLabel(String cat) {
    switch (cat) {
      case 'humor': return '😂 Юмор';
      case 'sympathy': return '❤️ Симпатия';
      default: return '💬 Обычное';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideIn,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCategoryBadge(),
                        const SizedBox(height: 14),
                        _buildQuestion(),
                        const SizedBox(height: 20),
                        _buildOptionsGrid(),
                        const SizedBox(height: 16),
                        _buildActions(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final progress = (_currentIndex + 1) / _totalQuestions;
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Вопрос ${_currentIndex + 1} из $_totalQuestions',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              // Stars indicator
              const Row(
                children: [
                  Text('⭐', style: TextStyle(fontSize: 14)),
                  SizedBox(width: 4),
                  Text(
                    '+12',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.border,
              color: AppColors.primaryBlue,
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBadge() {
    final cat = _currentQuestion.category;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: _catBg(cat),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _catLabel(cat),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _catFg(cat),
        ),
      ),
    );
  }

  Widget _buildQuestion() {
    return Text(
      '${_currentQuestion.emoji} ${_currentQuestion.question}',
      style: const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
        height: 1.3,
      ),
    );
  }

  Widget _buildOptionsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.82,
      children: _shuffledOptions
          .map(
            (opt) => _OptionCard(
              option: opt,
              isSelected: _selectedOptionId == opt.id,
              isDisabled:
                  _selectedOptionId != null && _selectedOptionId != opt.id,
              onTap: () => _selectOption(opt.id),
            ),
          )
          .toList(),
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Shuffle button
        TextButton.icon(
          onPressed: _selectedOptionId == null ? _shuffleOptions : null,
          icon: const Icon(Icons.shuffle_rounded, size: 18),
          label: const Text('Перемешать'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        // Skip button
        OutlinedButton(
          onPressed: _isAdvancing ? null : _skipQuestion,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            foregroundColor: AppColors.textSecondary,
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          child: const Text('Пропустить'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Option card widget
// ---------------------------------------------------------------------------

class _OptionCard extends StatelessWidget {
  final PollOption option;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback onTap;

  const _OptionCard({
    required this.option,
    required this.isSelected,
    required this.isDisabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primaryBlue.withOpacity(0.09)
            : isDisabled
                ? AppColors.surface
                : AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? AppColors.primaryBlue : AppColors.border,
          width: isSelected ? 2.0 : 1.0,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.primaryBlue.withOpacity(0.22),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: isDisabled ? null : onTap,
          borderRadius: BorderRadius.circular(18),
          splashColor: AppColors.primaryBlue.withOpacity(0.08),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: AppColors.primaryBlue,
                                width: 2.5,
                              )
                            : null,
                      ),
                      child: CircleAvatar(
                        radius: 36,
                        backgroundColor:
                            generateAvatarColor(option.name).withOpacity(
                          isDisabled ? 0.45 : 1.0,
                        ),
                        child: Text(
                          getInitials(option.name),
                          style: TextStyle(
                            color: Colors.white
                                .withOpacity(isDisabled ? 0.6 : 1.0),
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    if (isSelected)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: AnimatedScale(
                          scale: 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: AppColors.primaryBlue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  option.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color:
                        isDisabled ? AppColors.textHint : AppColors.textPrimary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  option.grade,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDisabled
                        ? AppColors.textHint
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
