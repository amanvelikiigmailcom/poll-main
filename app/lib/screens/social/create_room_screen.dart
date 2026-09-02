import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Room type enum
// ---------------------------------------------------------------------------

enum _RoomType { public, private }

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class _CreateRoomState {
  const _CreateRoomState({
    this.name = '',
    this.roomType = _RoomType.public,
    this.city = 'Москва',
    this.isLoading = false,
  });

  final String name;
  final _RoomType roomType;
  final String city;
  final bool isLoading;

  bool get canSubmit => name.trim().isNotEmpty && !isLoading;

  _CreateRoomState copyWith({
    String? name,
    _RoomType? roomType,
    String? city,
    bool? isLoading,
  }) {
    return _CreateRoomState(
      name: name ?? this.name,
      roomType: roomType ?? this.roomType,
      city: city ?? this.city,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class _CreateRoomNotifier extends StateNotifier<_CreateRoomState> {
  _CreateRoomNotifier() : super(const _CreateRoomState());

  void setName(String v) => state = state.copyWith(name: v);
  void setRoomType(_RoomType t) => state = state.copyWith(roomType: t);
  void setCity(String v) => state = state.copyWith(city: v);
  void setLoading(bool v) => state = state.copyWith(isLoading: v);
}

final _createRoomProvider =
    StateNotifierProvider.autoDispose<_CreateRoomNotifier, _CreateRoomState>(
  (ref) => _CreateRoomNotifier(),
);

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  final _nameController = TextEditingController();
  final _cityController = TextEditingController(text: 'Москва');
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final notifier = ref.read(_createRoomProvider.notifier);
    notifier.setLoading(true);

    // Simulate network call
    await Future.delayed(const Duration(milliseconds: 600));

    notifier.setLoading(false);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Комната успешно создана!'),
        backgroundColor: AppColors.primaryBlue,
        behavior: SnackBarBehavior.floating,
      ),
    );

    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_createRoomProvider);
    final notifier = ref.read(_createRoomProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.black, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Создать комнату',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Room name ---
                const _SectionLabel('Название комнаты'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  onChanged: notifier.setName,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _inputDecoration('Введите название комнаты'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Название не может быть пустым';
                    }
                    if (v.trim().length < 3) {
                      return 'Минимум 3 символа';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // --- Room type ---
                const _SectionLabel('Тип комнаты'),
                const SizedBox(height: 4),
                _RoomTypeSelector(
                  selected: state.roomType,
                  onChanged: notifier.setRoomType,
                ),

                const SizedBox(height: 24),

                // --- City ---
                const _SectionLabel('Город'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _cityController,
                  onChanged: notifier.setCity,
                  decoration: _inputDecoration('Ваш город'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Укажите город';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // --- Note ---
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: state.roomType == _RoomType.public
                      ? Container(
                          key: const ValueKey('public-note'),
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Icon(Icons.info_outline,
                                  color: AppColors.primaryBlue, size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Комната будет видна всем пользователям вашего города',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          key: const ValueKey('private-note'),
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Icon(Icons.lock_outline,
                                  color: Colors.grey, size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Комната будет доступна только по приватной ссылке',
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.grey),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),

                const SizedBox(height: 40),

                // --- Submit button ---
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: state.canSubmit ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      disabledBackgroundColor:
                          AppColors.primaryBlue.withValues(alpha: 0.4),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: state.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Создать',
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w600),
                          ),
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

// ---------------------------------------------------------------------------
// Room type selector
// ---------------------------------------------------------------------------

class _RoomTypeSelector extends StatelessWidget {
  const _RoomTypeSelector({
    required this.selected,
    required this.onChanged,
  });

  final _RoomType selected;
  final ValueChanged<_RoomType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _RadioTile(
          value: _RoomType.public,
          groupValue: selected,
          label: 'Публичная',
          subtitle: 'Видна всем пользователям в вашем городе',
          icon: Icons.public_rounded,
          onChanged: onChanged,
        ),
        const SizedBox(height: 8),
        _RadioTile(
          value: _RoomType.private,
          groupValue: selected,
          label: 'По ссылке (приватная)',
          subtitle: 'Доступна только по приватной ссылке',
          icon: Icons.link_rounded,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _RadioTile<T> extends StatelessWidget {
  const _RadioTile({
    required this.value,
    required this.groupValue,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.onChanged,
  });

  final T value;
  final T groupValue;
  final String label;
  final String subtitle;
  final IconData icon;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryBlue.withValues(alpha: 0.07)
              : const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primaryBlue : Colors.grey,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppColors.primaryBlue : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Radio<T>(
              value: value,
              groupValue: groupValue,
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
              activeColor: AppColors.primaryBlue,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }
}

InputDecoration _inputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.grey),
    filled: true,
    fillColor: const Color(0xFFF5F6FA),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.red, width: 1.5),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.red, width: 1.5),
    ),
  );
}
