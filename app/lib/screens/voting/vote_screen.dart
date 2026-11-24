import '../../services/contact_sync_service.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../widgets/common/premium_badge.dart';
import '../../services/game_settings.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../router/app_router.dart';
import '../../utils/helpers.dart';
import '../../services/local_game_service.dart';
import '../../services/question_report_service.dart';
import '../../widgets/common/question_report_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/service_providers.dart';
import '../../services/server_round_source.dart';
import '../../services/api_service.dart';

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

class QuizOption {
  final String id;
  final String name;
  final String grade;
  final String? avatarUrl;
  final String? serverUserId;
  final bool premiumBadge;
  final String? premiumBadgeUntil;

  const QuizOption({
    required this.id,
    required this.name,
    required this.grade,
    this.avatarUrl,
    this.serverUserId,
    this.premiumBadge = false,
    this.premiumBadgeUntil,
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

  Map<String, dynamic> toDraft() => {
    'id': id,
    'text': question,
    'emoji': emoji,
    'category': category,
    'options': [
      for (final option in options)
        {
          'id': option.id,
          'name': option.name,
          'winnerId': option.serverUserId,
          'premiumBadge': option.premiumBadge,
          'premiumBadgeUntil': option.premiumBadgeUntil,
        },
    ],
  };

  factory QuizQuestion.fromDraft(Map<String, dynamic> data) => QuizQuestion(
    id: data['id'] as String,
    question: data['text'] as String,
    emoji: data['emoji'] as String,
    category: data['category'] as String,
    options: [
      for (final option in data['options'] as List)
        QuizOption(
          id: option['id'] as String,
          premiumBadge: option['premiumBadge'] == true,
          premiumBadgeUntil: option['premiumBadgeUntil'] as String?,
          name: option['name'] as String,
          grade: '',
          serverUserId: option['winnerId'] as String?,
        ),
    ],
  );
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
  static const int _totalQuestions = LocalGameService.roundLength;

  ServerRoundSource? _source;
  String? _sessionId;
  bool _schoolVoting = false;
  String? _sessionKey;
  String? _ownerId;
  bool _editingFromReview = false;
  bool _sealed = false;
  bool _submitting = false;
  String? _submitError;
  String? _loadError;
  bool _canDiscardDraft = false;
  final Map<String, RoundAnswer> _answers = {};
  bool get _isReview => _currentIndex == _totalQuestions;

  ServerRoundSource? _resolveSource() {
    if (widget.serverSource != null) return widget.serverSource;
    try {
      final container = ProviderScope.containerOf(context);
      return ServerRoundSource(
        container.read(quizServiceProvider),
        isLoggedIn: container.read(authServiceProvider).isLoggedIn,
        readToken: container.read(storageServiceProvider).getToken,
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
    _startLoading();
  }

  Future<void> _startLoading({bool discard = false}) async {
    final language = Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';
    setState(() {
      _loading = true;
      _loadError = null;
      _canDiscardDraft = false;
    });
    try {
      if (discard) await LocalGameService.instance.discardRoundDraft();
      await _loadRound(language);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error is ApiException
            ? error.message
            : 'Couldn’t open your round. Please try again.';
      });
    }
  }

  Future<void> _loadRound(String languageCode) async {
    final ready = await LocalGameService.instance.hasEnoughNames();
    if (!mounted) return;
    final svc = LocalGameService.instance;
    final saved = await svc.loadRoundProgress();
    if (!mounted) return;
    final mode = saved?.draft == null ? await _schoolMode() : null;
    if (!mounted) return;
    if (!ready && saved?.draft == null && mode != true) {
      context.go(AppRoutes.namesEntry);
      return;
    }

    try {
      await ProviderScope.containerOf(context)
          .read(invitationServiceProvider)
          .refresh()
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      /* Offline play keeps its locally saved waiting period. */
    }
    final remaining = await LocalGameService.instance.secondsUntilNextRound();
    if (!mounted) return;
    if (remaining > 0) {
      context.go(AppRoutes.timer);
      return;
    }

    final completed = await svc.getCompletedRounds();
    if (!mounted) return;
    _source = _resolveSource();
    final draft = saved?.draft;
    if (saved != null && saved.round == completed && draft != null) {
      final sessionKey = draft['sessionKey'] as String?;
      final sessionId = draft['sessionId'] as String?;
      final ownerId = draft['ownerId'] as String?;
      if (sessionId != null &&
          (sessionKey == null ||
              await _source?.ownsDraft(sessionKey, ownerId: ownerId) != true)) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _loadError =
              'This online draft was saved under a different sign-in or your session is unavailable.';
          _canDiscardDraft = true;
        });
        return;
      }
      if (!mounted) return;
      final questions = (draft['questions'] as List)
          .cast<Map<String, dynamic>>()
          .map(QuizQuestion.fromDraft)
          .toList();
      if (questions.length != _totalQuestions ||
          saved.questionIndex > _totalQuestions) {
        throw StateError('Invalid draft');
      }
      _sessionId = sessionId;
      _schoolVoting = draft['schoolVoting'] == true;
      _sessionKey = sessionKey;
      _ownerId = ownerId;
      _sealed = draft['sealed'] == true;
      _editingFromReview = draft['editingFromReview'] == true;
      _useRound(
        questions,
        completed,
        saved.questionIndex,
        saved.draftAnswers ?? [],
      );
      return;
    }

    // Resume an older local draft before looking for a new online round.
    List<GeneratedQuestion>? generated;
    var startIndex = 0;
    List<RoundAnswer> previous = [];
    if (saved != null &&
        saved.round == completed &&
        saved.questionIndex < _totalQuestions) {
      generated = await svc.restoreRound(
        ids: saved.questionIds,
        languageCode: languageCode,
      );
      if (generated?.length == _totalQuestions) {
        startIndex = saved.questionIndex;
        previous = await svc.getRoundAnswers();
      } else {
        generated = null;
      }
    }
    final serverSession = generated == null
        ? await _source?.tryLoadSession()
        : null;
    if (!mounted) return;
    if (serverSession != null &&
        serverSession.supportsRoundSubmission &&
        serverSession.answeredCount == 0 &&
        serverSession.sessionId.isNotEmpty &&
        serverSession.questions.length == _totalQuestions) {
      final questions = <QuizQuestion>[];
      final localLabels = await ContactSyncService.localLabels();
      if (!mounted) return;
      final names = serverSession.schoolVoting
          ? <String>[]
          : await svc.selectedOptions();
      if (!mounted) return;
      if (!serverSession.schoolVoting && !ready) {
        if (mode == true) {
          setState(() {
            _loading = false;
            _loadError =
                'A contact round is already open. Finish it on the device where you started it.';
          });
        } else {
          context.go(AppRoutes.namesEntry);
        }
        return;
      }
      for (final q in serverSession.questions) {
        final options = <QuizOption>[];
        if (serverSession.schoolVoting) {
          for (final candidate in q.candidates.where(
            (c) => !c.isSelf && c.id != serverSession.ownerId,
          )) {
            options.add(
              QuizOption(
                id: candidate.id,
                name: candidate.firstName,
                grade: '',
                serverUserId: candidate.id,
                premiumBadge: candidate.premiumBadge,
                premiumBadgeUntil: candidate.premiumBadgeUntil,
              ),
            );
          }
        }
        for (final (index, name) in names.indexed) {
          // Labels, not strangers' profile names. Ambiguous matches stay local.
          final matches = q.candidates
              .where(
                (c) =>
                    !c.isSelf &&
                    (c.contactHash != null
                            ? localLabels[c.contactHash]?.trim().toLowerCase()
                            : c.fullName.trim().toLowerCase()) ==
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
              premiumBadge: matches.length == 1 && matches.single.premiumBadge,
              premiumBadgeUntil: matches.length == 1
                  ? matches.single.premiumBadgeUntil
                  : null,
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
      if (!mounted) return;
      _sessionId = serverSession.sessionId;
      _schoolVoting = serverSession.schoolVoting;
      _sessionKey = _source!.loadedSessionKey;
      _ownerId = serverSession.ownerId;
      await _initializeRound(questions, completed, 0, []);
      return;
    }
    if (generated == null && mode == true) {
      setState(() {
        _loading = false;
        _loadError =
            'Couldn’t start a school round. Check your connection and try again.';
      });
      return;
    }
    if (!ready) {
      context.go(AppRoutes.namesEntry);
      return;
    }
    generated ??= await svc.generateRound(languageCode: languageCode);
    if (!mounted) return;
    if (generated.length != _totalQuestions) {
      throw StateError('Incomplete round');
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
    _sessionId = null;
    _schoolVoting = false;
    _sessionKey = null;
    _ownerId = null;
    await _initializeRound(questions, completed, startIndex, previous);
  }

  Future<bool?> _schoolMode() async {
    try {
      final details = ProviderScope.containerOf(
        context,
        listen: false,
      ).read(onboardingDetailsProvider);
      return (await details.votingMode())?.school;
    } catch (_) {
      return null;
    }
  }

  Future<void> _initializeRound(
    List<QuizQuestion> questions,
    int round,
    int index,
    List<RoundAnswer> answers,
  ) async {
    _questions = questions;
    _roundNumber = round;
    _editingFromReview = false;
    _sealed = false;
    final byId = {for (final answer in answers) answer.questionId: answer};
    _answers
      ..clear()
      ..addAll({
        for (final question in questions)
          if (byId[question.id] case final answer?) question.id: answer,
      });
    await _saveDraft(index);
    if (mounted) _useRound(questions, round, index, _answers.values.toList());
  }

  void _useRound(
    List<QuizQuestion> questions,
    int round,
    int index,
    List<RoundAnswer> answers,
  ) {
    setState(() {
      _questions = questions;
      _roundNumber = round;
      _answers
        ..clear()
        ..addEntries(
          answers.map((answer) => MapEntry(answer.questionId, answer)),
        );
      _showPosition(index);
      _loading = false;
    });
  }

  Future<void> _saveDraft(int index) =>
      LocalGameService.instance.saveRoundProgress(
        round: _roundNumber,
        questionIndex: index,
        questionIds: _questions.map((q) => q.id).toList(),
        draftAnswers: [
          for (final q in _questions)
            if (_answers[q.id] case final a?) a,
        ],
        draft: {
          'questions': _questions.map((q) => q.toDraft()).toList(),
          if (_sessionId != null) 'sessionId': _sessionId,
          if (_schoolVoting) 'schoolVoting': true,
          if (_sessionKey != null) 'sessionKey': _sessionKey,
          if (_ownerId != null) 'ownerId': _ownerId,
          'editingFromReview': _editingFromReview,
          'sealed': _sealed,
        },
      );

  void _showPosition(int index) {
    _currentIndex = index;
    _shuffledOptions = _isReview ? [] : List.of(_currentQuestion.options);
    _selectedOptionId = _isReview ? null : _savedOptionId(_currentQuestion);
  }

  String? _savedOptionId(QuizQuestion question) {
    final answer = _answers[question.id];
    if (answer?.optionId != null) return answer!.optionId;
    if (answer?.choice == null) return null;
    for (final option in question.options) {
      if (option.name == answer!.choice) return option.id;
    }
    return null;
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  QuizQuestion get _currentQuestion => _questions[_currentIndex];

  Future<void> _choose(QuizOption? option) async {
    if (_isAdvancing || _sealed) return;
    GameSettings.instance.feedback();
    final question = _currentQuestion;
    final old = _answers[question.id];
    final oldEditing = _editingFromReview;
    final next = oldEditing ? _totalQuestions : _currentIndex + 1;
    setState(() {
      _isAdvancing = true;
      _selectedOptionId = option?.id;
    });
    try {
      final voter = await LocalGameService.instance.getPlayerName() ?? 'You';
      if (!mounted) return;
      _answers[question.id] = RoundAnswer(
        questionId: question.id,
        question: question.question,
        voter: voter,
        choice: option?.name,
        optionId: option?.id,
      );
      _editingFromReview = false;
      await _saveDraft(next);
    } catch (_) {
      if (!mounted) return;
      if (old == null) {
        _answers.remove(question.id);
      } else {
        _answers[question.id] = old;
      }
      setState(() {
        _editingFromReview = oldEditing;
        _isAdvancing = false;
        _selectedOptionId = _savedOptionId(question);
      });
      _showSaveError();
      return;
    }
    if (!mounted) return;
    _slideController.duration = GameSettings.instance.effectiveReduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 350);
    if (!GameSettings.instance.effectiveReduceMotion) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    if (!mounted) return;
    await _slideController.reverse();
    if (!mounted) return;
    setState(() => _showPosition(next));
    await _slideController.forward();
    if (mounted) setState(() => _isAdvancing = false);
  }

  Future<void> _goTo(int next, {bool editing = false}) async {
    if (_isAdvancing || _sealed) return;
    final oldEditing = _editingFromReview;
    setState(() {
      _isAdvancing = true;
      _editingFromReview = editing;
    });
    try {
      await _saveDraft(next);
      if (mounted) setState(() => _showPosition(next));
    } catch (_) {
      _editingFromReview = oldEditing;
      if (mounted) _showSaveError();
    } finally {
      if (mounted) setState(() => _isAdvancing = false);
    }
  }

  void _showSaveError() => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Couldn’t save your choice. Please try again.'),
    ),
  );

  Future<void> _submit() async {
    if (_submitting ||
        _isAdvancing ||
        !_isReview ||
        _answers.length != _totalQuestions) {
      return;
    }
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    final wasSealed = _sealed;
    var sent = false;
    try {
      _sealed = true;
      await _saveDraft(_totalQuestions);
      if (!mounted) return;
      // Guest/local rounds never use a debug/SDK flag to award paid benefits.
      const bonus = false;
      if (!mounted) return;
      final sessionId = _sessionId;
      if (sessionId != null) {
        sent = true;
        await _source!.submitRound(
          sessionId: sessionId,
          sessionKey: _sessionKey!,
          ownerId: _ownerId,
          answers: {
            for (final q in _questions)
              q.id: q.options
                  .where((o) => o.id == _savedOptionId(q))
                  .firstOrNull
                  ?.serverUserId,
          },
        );
      }
      if (!mounted) return;
      await LocalGameService.instance.finishRoundDraft(
        _roundNumber,
        bonus: bonus,
        awardStars: sessionId == null,
      );
      if (mounted) {
        try {
          ProviderScope.containerOf(context).invalidate(starBalanceProvider);
        } on StateError {
          /* An injected offline preview may have no provider scope. */
        }
      }
      if (mounted) {
        context.go(
          AppRoutes.starReceived,
          extra: {
            'starsAwarded': sessionId == null
                ? 1000
                : _source?.lastStarsAwarded,
          },
        );
      }
    } catch (error) {
      if (!mounted) return;
      if (_schoolVoting &&
          error is ApiException &&
          error.statusCode == 409 &&
          error.message == 'Your campus changed. Start a new round.') {
        setState(() {
          _loadError = error.message;
          _canDiscardDraft = true;
        });
        return;
      }
      if (sent && error is ApiException && error.statusCode == 422) {
        // The server validated the entire batch before writing anything.
        _sealed = false;
        try {
          await _saveDraft(_totalQuestions);
        } catch (_) {
          _sealed = true;
        }
      } else if (!sent) {
        _sealed = wasSealed;
      }
      if (!mounted) return;
      setState(
        () => _submitError = error is ApiException
            ? error.message
            : 'Couldn’t finish the round. Your answers are saved.',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
    if (_loadError case final error?) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error, textAlign: TextAlign.center),
                  TextButton(
                    onPressed: _startLoading,
                    child: const Text('Try again'),
                  ),
                  if (_canDiscardDraft)
                    TextButton(
                      onPressed: _confirmDiscard,
                      child: const Text('Discard draft'),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (_loading || _questions.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_isReview) return _buildReview();
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
                        if (_sessionId != null)
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text(
                              'Premium recipients can reveal your first initial or full name using limited weekly reveals.',
                            ),
                          ),
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

  Future<void> _confirmDiscard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this draft?'),
        content: const Text(
          'The answers saved on this device will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _startLoading(discard: true);
  }

  Widget _buildReview() {
    final answered = _answers.values
        .where((answer) => answer.choice != null)
        .length;
    final skipped = _answers.length - answered;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Review your answers',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text('$answered answered · $skipped skipped'),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: _questions.length,
                itemBuilder: (context, index) {
                  final q = _questions[index];
                  final answer = _answers[q.id];
                  return ListTile(
                    title: Text('${index + 1}. ${q.question}'),
                    subtitle: Text(
                      answer == null
                          ? 'Not answered'
                          : answer.choice ?? 'Skipped',
                    ),
                    trailing: _sealed ? null : const Icon(Icons.edit_outlined),
                    onTap: _sealed || _submitting || _isAdvancing
                        ? null
                        : () => _goTo(index, editing: true),
                  );
                },
              ),
            ),
            if (_sessionId != null)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'By submitting, you acknowledge that Premium recipients can reveal your first initial or full name using limited weekly reveals.',
                ),
              ),
            if (_submitError case final error?)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Semantics(liveRegion: true, child: Text(error)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton(
                onPressed:
                    _submitting ||
                        _isAdvancing ||
                        _answers.length != _totalQuestions
                    ? null
                    : _submit,
                child: Text(
                  _submitting
                      ? 'Submitting…'
                      : _sealed
                      ? 'Retry submission'
                      : _sessionId == null
                      ? 'Finish round'
                      : 'Submit votes',
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
              if (_currentIndex > 0 && !_editingFromReview)
                IconButton(
                  tooltip: 'Previous question',
                  onPressed: _isAdvancing
                      ? null
                      : () => _goTo(_currentIndex - 1),
                  icon: const Icon(Icons.arrow_back),
                ),
              Text(
                'Question ${_currentIndex + 1} of $_totalQuestions',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const Text(
                '⭐ +${LocalGameService.starsPerRound}',
                semanticsLabel:
                    '${LocalGameService.starsPerRound} stars per completed round',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryBlue,
                ),
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
                isDisabled: _isAdvancing && _selectedOptionId != opt.id,
                onTap: () => _choose(opt),
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
        if (_editingFromReview || _answers.containsKey(_currentQuestion.id))
          FilledButton.tonal(
            onPressed: _isAdvancing
                ? null
                : () => _goTo(
                    _editingFromReview ? _totalQuestions : _currentIndex + 1,
                  ),
            child: Text(_editingFromReview ? 'Back to review' : 'Next'),
          ),
        TextButton.icon(
          onPressed: _isAdvancing ? null : _shuffleOptions,
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
          onPressed: _isAdvancing ? null : () => _choose(null),
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
                PremiumBadge(
                  active: option.premiumBadge,
                  until: option.premiumBadgeUntil,
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
