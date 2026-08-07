import 'dart:ui';
import 'package:flutter/material.dart';

enum RevealMode { none, letter, name }

enum PremiumTier { pro, max }

class PersonData {
  final String realName;
  final String grade;
  final String avatarUrl;
  bool isRevealed;
  String? revealedText;
  RevealMode? revealedAs;

  PersonData({
    required this.realName,
    required this.grade,
    this.avatarUrl = '',
    this.isRevealed = false,
    this.revealedText,
    this.revealedAs,
  });
}

class PremiumResultScreen extends StatefulWidget {
  final String pollEmoji;
  final String pollQuestion;
  final PremiumTier tier;
  final List<PersonData>? persons;

  const PremiumResultScreen({
    super.key,
    this.pollEmoji = '😊',
    this.pollQuestion = 'Кто самый красивый?',
    this.tier = PremiumTier.pro,
    this.persons,
  });

  @override
  State<PremiumResultScreen> createState() => _PremiumResultScreenState();
}

class _PremiumResultScreenState extends State<PremiumResultScreen>
    with SingleTickerProviderStateMixin {
  static const Color primaryBlue = Color(0xFF4B6EF5);
  static const Color accentRed = Color(0xFFFF3B5C);

  late int nameRevealLimit;
  late int letterRevealLimit;
  RevealMode currentMode = RevealMode.none;

  late List<PersonData> persons;
  late AnimationController _animationController;
  int? _animatingIndex;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    if (widget.tier == PremiumTier.max) {
      nameRevealLimit = -1; // -1 = unlimited
      letterRevealLimit = -1;
    } else {
      nameRevealLimit = 2;
      letterRevealLimit = 1;
    }

    persons = widget.persons ??
        [
          PersonData(realName: 'Александр Иванов', grade: '10А'),
          PersonData(realName: 'Мария Петрова', grade: '10Б'),
          PersonData(realName: 'Дмитрий Сидоров', grade: '11А'),
          PersonData(realName: 'Анна Козлова', grade: '10А'),
        ];
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  bool get isMaxTier => widget.tier == PremiumTier.max;
  bool get nameLimit => nameRevealLimit == 0;
  bool get letterLimit => letterRevealLimit == 0;
  bool get allLimitsExhausted => nameLimit && letterLimit;

  void _onCardTap(int index) {
    if (currentMode == RevealMode.none) return;
    if (persons[index].isRevealed) return;

    if (currentMode == RevealMode.letter) {
      if (letterRevealLimit == 0) return;
      _animateReveal(index, () {
        setState(() {
          persons[index].isRevealed = true;
          persons[index].revealedAs = RevealMode.letter;
          persons[index].revealedText =
              '${persons[index].realName[0]}...';
          if (letterRevealLimit > 0) letterRevealLimit--;
          currentMode = RevealMode.none;
        });
      });
    } else if (currentMode == RevealMode.name) {
      if (nameRevealLimit == 0) return;
      _animateReveal(index, () {
        setState(() {
          persons[index].isRevealed = true;
          persons[index].revealedAs = RevealMode.name;
          persons[index].revealedText = persons[index].realName;
          if (nameRevealLimit > 0) nameRevealLimit--;
          currentMode = RevealMode.none;
        });
      });
    }
  }

  void _animateReveal(int index, VoidCallback onComplete) {
    setState(() => _animatingIndex = index);
    _animationController.forward(from: 0).then((_) {
      onComplete();
      setState(() => _animatingIndex = null);
    });
  }

  void _enterLetterMode() {
    if (letterRevealLimit == 0) {
      _showLimitToast();
      return;
    }
    setState(() => currentMode = RevealMode.letter);
    _showToast('Нажмите на карточку кого хотите узнать');
  }

  void _enterNameMode() {
    if (nameRevealLimit == 0) {
      _showLimitToast();
      return;
    }
    setState(() => currentMode = RevealMode.name);
    _showToast('Нажмите на карточку кого хотите узнать');
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  void _showLimitToast() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Лимит исчерпан'),
        backgroundColor: Colors.grey.shade700,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          '${widget.pollEmoji} ${widget.pollQuestion}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: Column(
        children: [
          _buildCounterBanner(),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: persons.length,
              itemBuilder: (context, index) => _buildPersonCard(index),
            ),
          ),
          _buildActionButtons(),
          if (allLimitsExhausted && !isMaxTier) _buildUpgradeLink(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildCounterBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isMaxTier
          ? const Row(
              children: [
                Text(
                  'Неограниченные раскрытия ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                Text('♾️', style: TextStyle(fontSize: 16)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'У вас осталось:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.person_search,
                        size: 16, color: primaryBlue),
                    const SizedBox(width: 6),
                    Text(
                      '$nameRevealLimit раскрытия полного имени',
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            nameRevealLimit == 0 ? Colors.red : Colors.black54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.text_fields,
                        size: 16, color: accentRed),
                    const SizedBox(width: 6),
                    Text(
                      '$letterRevealLimit первой буквы',
                      style: TextStyle(
                        fontSize: 13,
                        color: letterRevealLimit == 0
                            ? Colors.red
                            : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildPersonCard(int index) {
    final person = persons[index];
    final bool isAnimating = _animatingIndex == index;
    final bool isSelectable =
        currentMode != RevealMode.none && !person.isRevealed;

    return GestureDetector(
      onTap: () => person.isRevealed ? _openProfile(index) : _onCardTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelectable
                ? primaryBlue
                : person.isRevealed
                    ? const Color(0xFFE8EAFF)
                    : Colors.transparent,
            width: isSelectable ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildAvatar(person, isAnimating),
                  const SizedBox(height: 10),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: person.isRevealed
                        ? Column(
                            key: ValueKey('revealed_$index'),
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  person.revealedText ?? person.realName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                person.grade,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black38,
                                ),
                              ),
                              if (person.revealedAs == RevealMode.name)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: primaryBlue.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Открыть профиль →',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: primaryBlue,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          )
                        : Column(
                            key: ValueKey('hidden_$index'),
                            children: [
                              const Text(
                                '???',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  color: Colors.black26,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Класс ?',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.black26),
                              ),
                              if (isSelectable)
                                const Padding(
                                  padding: EdgeInsets.only(top: 6),
                                  child: Text(
                                    'Нажмите',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: primaryBlue,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
              if (isAnimating)
                Positioned.fill(
                  child: Container(
                    color: Colors.white.withValues(alpha: 0.7),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: primaryBlue,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(PersonData person, bool isAnimating) {
    if (person.isRevealed) {
      return Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.shade100,
          border: Border.all(color: primaryBlue, width: 2.5),
        ),
        child: person.avatarUrl.isNotEmpty
            ? ClipOval(
                child: Image.network(
                  person.avatarUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.person,
                    size: 38,
                    color: Colors.grey,
                  ),
                ),
              )
            : const Icon(Icons.person, size: 38, color: Colors.grey),
      );
    }

    return SizedBox(
      width: 68,
      height: 68,
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: Colors.grey.shade200,
              child: const Icon(Icons.person, size: 42, color: Colors.grey),
            ),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final bool letterExhausted = letterRevealLimit == 0 && !isMaxTier;
    final bool nameExhausted = nameRevealLimit == 0 && !isMaxTier;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: letterExhausted ? _showLimitToast : _enterLetterMode,
              icon: const Text('🔤', style: TextStyle(fontSize: 16)),
              label: const Text('Узнать первую букву имени'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    letterExhausted ? Colors.grey.shade400 : accentRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: letterExhausted ? 0 : 2,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: nameExhausted ? _showLimitToast : _enterNameMode,
              icon: const Text('👤', style: TextStyle(fontSize: 16)),
              label: const Text('Узнать полное имя'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    nameExhausted ? Colors.grey.shade400 : primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: nameExhausted ? 0 : 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeLink() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: TextButton.icon(
        onPressed: () {
          Navigator.of(context).pushReplacementNamed('/premium');
        },
        icon: const Text('🏆', style: TextStyle(fontSize: 14)),
        label: const Text(
          'Premium Max — неограниченные раскрытия',
          style: TextStyle(
            color: accentRed,
            fontWeight: FontWeight.bold,
            fontSize: 13,
            decoration: TextDecoration.underline,
            decorationColor: accentRed,
          ),
        ),
      ),
    );
  }

  void _openProfile(int index) {
    final person = persons[index];
    if (person.revealedAs != RevealMode.name) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Профиль: ${person.realName}'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
    // TODO: Navigate to profile screen
    // context.push('/profile/${person.userId}');
  }
}
