import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/game_settings.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../router/app_router.dart';
import '../../utils/helpers.dart';
import '../../services/local_game_service.dart';
import '../../services/question_report_service.dart';
import '../../services/subscription_service.dart';
import '../../widgets/common/question_report_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/service_providers.dart';
import '../../services/server_round_source.dart';

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

class QuizOption {
  final String id;
  final String name;
  final String grade;
  final String? avatarUrl;
  final String? serverUserId;

  const QuizOption({
    required this.id,
    required this.name,
    required this.grade,
    this.avatarUrl,
    this.serverUserId,
  });
}

class QuizQuestion {
  final String id;
  final String question;
  final String emoji;
  final String category; // humor | normal | sympathy
  final List<QuizOption> options;

  const QuizQuestion({
    required this.id,
    required this.question,
    required this.emoji,
    required this.category,
    required this.options,
  });
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class VoteScreen extends StatefulWidget {
  const VoteScreen({
    super.key,
    this.reportService = const QuestionReportService(),
    this.serverSource,
  });

  final QuestionReportService reportService;

  /// Server branch override (tests). Production resolves providers lazily.
  final ServerRoundSource? serverSource;

  @override
  State<VoteScreen> createState() => _VoteScreenState();
}

class _VoteScreenState extends State<VoteScreen>
    with SingleTickerProviderStateMixin {
  static const int _totalQuestions = 12;

  /// Null without providers, offline, logged out or on server failure.
  ServerRoundSource? _source;
  bool _serverRound = false;

  ServerRoundSource? _resolveSource() {
    if (widget.serverSource != null) return widget.serverSource;
    try {
      final container = ProviderScope.containerOf(context);
      return ServerRoundSource(
        container.read(quizServiceProvider),
        isLoggedIn: container.read(authServiceProvider).isLoggedIn,
      );
    } catch (_) {
      return null;
    }
  }

  List<QuizQuestion> _questions = [];
  bool _loading = true;
  bool _roundLoadStarted = false;

  int _currentIndex = 0;
  int _roundNumber = 0;
  String? _selectedOptionId;
  bool _isAdvancing = false;
  bool _reporting = false;
  List<QuizOption> _shuffledOptions = [];

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
    _fadeAnim = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    );
    _slideController.value = 1.0; // start visible
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_roundLoadStarted) return;
    _roundLoadStarted = true;
    final languageCode =
        Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';
    _loadRound(languageCode);
  }

  Future<void> _loadRound(String languageCode) async {
    final ready = await LocalGameService.instance.hasEnoughNames();
    if (!mounted) return;
    if (!ready) {
      // Not enough setup yet — only names onboarding, never a fake "need 5 people" gate
      context.go(AppRoutes.namesEntry);
      return;
    }

    try {
      await ProviderScope.containerOf(context).read(invitationServiceProvider).refresh()
          .timeout(const Duration(seconds: 6));
    } catch (_) { /* Offline play keeps its locally saved waiting period. */ }
    final remaining = await LocalGameService.instance.secondsUntilNextRound();
    if (!mounted) return;
    if (remaining > 0) {
      context.go(AppRoutes.timer);
      return;
    }

    // Server branch: logged in + online → shared questions, votes also land
    // server-side (and trigger pushes). Anything else keeps the local game.
    _source = _resolveSource();
    final serverSession = await _source?.tryLoadSession();
    if (!mounted) return;
    if (serverSession != null &&
        serverSession.questions.length >= _totalQuestions) {
      final svc = LocalGameService.instance;
      final completed = await svc.getCompletedRounds();
      if (!mounted) return;
      final questions = <QuizQuestion>[];
      for (final q in serverSession.questions.take(_totalQuestions)) {
        final names = await svc.selectedOptions();
        final options = <QuizOption>[];
        for (final (index, name) in names.indexed) {
          // Labels, not strangers' profile names. Ambiguous matches stay local.
          final matches = q.candidates
              .where(
                (c) =>
                    !c.isSelf &&
                    c.fullName.trim().toLowerCase() ==
                        name.trim().toLowerCase(),
              )
              .toList();
          final userId = matches.length == 1 ? matches.single.id : null;
          options.add(
            QuizOption(
              id: '${q.id}_$index',
              name: name,
              grade: '',
              serverUserId: userId,
            ),
          );
        }
        questions.add(
          QuizQuestion(
            id: q.id,
            question: q.text,
            emoji: q.emoji,
            category: q.category,
            options: options,
          ),
        );
      }
      await svc.beginRoundAnswers();
      await svc.saveRoundProgress(
        round: completed,
        questionIndex: 0,
        questionIds: questions.map((q) => q.id).toList(),
      );
      if (!mounted) return;
      setState(() {
        _questions = questions;
        _currentIndex = 0;
        _roundNumber = completed;
        _serverRound = true;
        _shuffledOptions = questions.isNotEmpty
            ? List.from(questions[0].options)
            : [];
        _loading = false;
      });
      return;
    }

    final svc = LocalGameService.instance;
    final completed = await svc.getCompletedRounds();
    if (!mounted) return;

    // Resume the current round without losing locally saved choices.
    List<GeneratedQuestion> generated = [];
    var startIndex = 0;
    {
      final saved = await svc.loadRoundProgress();
      if (!mounted) return;
      if (saved != null &&
          saved.round == completed &&
          saved.questionIndex < _totalQuestions) {
        final restored = await svc.restoreRound(
          ids: saved.questionIds,
          languageCode: languageCode,
        );
        if (!mounted) return;
        if (restored != null && restored.length == _totalQuestions) {
          generated = restored;
          startIndex = saved.questionIndex;
        }
      }
    }
    final fresh = generated.isEmpty;
    if (fresh) {
      generated = await svc.generateRound(languageCode: languageCode);
      if (!mounted) return;
    }

    if (generated.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    final questions = generated
        .map(
          (g) => QuizQuestion(
            id: g.id,
            question: g.question,
            emoji: g.emoji,
            category: g.category,
            options: g.optionNames
                .asMap()
                .entries
                .map(
                  (e) => QuizOption(
                    id: '${g.id}_${e.key}',
                    name: e.value,
                    grade: '',
                  ),
                )
                .toList(),
          ),
        )
        .toList();
    if (fresh) {
      await svc.beginRoundAnswers();
      await svc.saveRoundProgress(
        round: completed,
        questionIndex: 0,
        questionIds: questions.map((q) => q.id).toList(),
      );
      if (!mounted) return;
    }
    setState(() {
      _questions = questions;
      _currentIndex = startIndex;
      _roundNumber = completed;
      _shuffledOptions = questions.isNotEmpty
          ? List.from(questions[startIndex].options)
          : [];
      _loading = false;
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  QuizQuestion get _currentQuestion => _questions[_currentIndex];

  void _selectOption(String optionId) {
    if (_selectedOptionId != null || _isAdvancing) return;
    GameSettings.instance.feedback();
    setState(() => _selectedOptionId = optionId);
    _autoAdvance();
  }

  Future<void> _autoAdvance() async {
    setState(() => _isAdvancing = true);
    try {
      final question = _currentQuestion;
      final selected = _selectedOptionId;
      await LocalGameService.instance.recordAnswer(
        RoundAnswer(
          questionId: question.id,
          question: question.question,
          voter: await LocalGameService.instance.getPlayerName() ?? 'You',
          choice: selected == null
              ? null
              : question.options.firstWhere((o) => o.id == selected).name,
        ),
      );
      if (_serverRound) {
        final winner = selected == null
            ? null
            : question.options.firstWhere((o) => o.id == selected).serverUserId;
        await _source?.trySubmitVote(quizId: question.id, winnerId: winner);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isAdvancing = false;
        _selectedOptionId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couldn’t save your choice. Please try again.'),
        ),
      );
      return;
    }
    if (!mounted) return;
    _slideController.duration = GameSettings.instance.effectiveReduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 350);
    // Brief pause to show selection highlight
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    // Slide out
    await _slideController.reverse();
    if (!mounted) return;
    if (_currentIndex >= _totalQuestions - 1) {
      await LocalGameService.instance.completeRound();
      if (await SubscriptionService.instance.isPro()) {
        await LocalGameService.instance.addStars(
          LocalGameService.starsPerRound,
        );
      }
      if (!mounted) return;
      context.go(AppRoutes.starReceived);
    } else {
      setState(() {
        _currentIndex++;
        _selectedOptionId = null;
        _isAdvancing = false;
        _shuffledOptions = List.from(_questions[_currentIndex].options);
      });
      {
        await LocalGameService.instance.saveRoundProgress(
          round: _roundNumber,
          questionIndex: _currentIndex,
          questionIds: _questions.map((q) => q.id).toList(),
        );
        if (!mounted) return;
      }
      await _slideController.forward();
    }
  }

  void _skipQuestion() {
    if (_isAdvancing) return;
    GameSettings.instance.feedback();
    setState(() {
      _selectedOptionId = null;
      _isAdvancing = false;
    });
    _autoAdvance();
  }

  void _shuffleOptions() {
    GameSettings.instance.feedback(selection: true);
    setState(() => _shuffledOptions.shuffle());
  }

  Future<void> _reportQuestion() async {
    if (_reporting || _isAdvancing) return;
    final question = _currentQuestion;
    setState(() => _reporting = true);
    try {
      await showDialog<void>(
        context: context,
        builder: (_) => QuestionReportDialog(
          report: QuestionReport(
            questionId: question.id,
            questionText: question.question,
          ),
          service: widget.reportService,
        ),
      );
    } finally {
      if (mounted) setState(() => _reporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _questions.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }
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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [
              Text('Question ${_currentIndex + 1} of $_totalQuestions',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
              const Text('⭐ +${LocalGameService.starsPerRound}',
                semanticsLabel: '${LocalGameService.starsPerRound} stars per completed round',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: AppColors.primaryBlue)),
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

  Widget _buildQuestion() {
    return Text(
      '${_currentQuestion.emoji} ${_currentQuestion.question}'.trim(),
      style: const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
        height: 1.3,
      ),
    );
  }

  Widget _buildOptionsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _shuffledOptions.map((opt) {
            return SizedBox(
              width: cardWidth,
              child: _OptionCard(
                option: opt,
                isSelected: _selectedOptionId == opt.id,
                isDisabled:
                    _selectedOptionId != null && _selectedOptionId != opt.id,
                onTap: () => _selectOption(opt.id),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildActions() {
    // Use Wrap + intrinsic buttons so web layout never gets infinite-width
    // constraints (Row + Material 3 buttons can throw on Chrome).
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        TextButton.icon(
          onPressed: _shuffleOptions,
          icon: const Icon(Icons.shuffle_rounded, size: 18),
          label: const Text('Shuffle'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        OutlinedButton(
          onPressed: _isAdvancing ? null : _skipQuestion,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            foregroundColor: AppColors.textSecondary,
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          child: const Text('Skip'),
        ),
        TextButton.icon(
          onPressed: _reporting || _isAdvancing ? null : _reportQuestion,
          icon: const Icon(Icons.flag_outlined, size: 18),
          label: const Text('Report a question'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Option card widget
// ---------------------------------------------------------------------------

class _OptionCard extends StatelessWidget {
  final QuizOption option;
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
            ? AppColors.primaryBlue.withValues(alpha: 0.09)
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
                  color: AppColors.primaryBlue.withValues(alpha: 0.22),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
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
          splashColor: AppColors.primaryBlue.withValues(alpha: 0.08),
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
                        backgroundColor: generateAvatarColor(
                          option.name,
                        ).withValues(alpha: isDisabled ? 0.45 : 1.0),
                        child: Text(
                          getInitials(option.name),
                          style: TextStyle(
                            color: Colors.white.withValues(
                              alpha: isDisabled ? 0.6 : 1.0,
                            ),
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
                    color: isDisabled
                        ? AppColors.textHint
                        : AppColors.textPrimary,
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
