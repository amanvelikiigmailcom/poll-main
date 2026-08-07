import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class _Room {
  const _Room({
    required this.id,
    required this.name,
    required this.city,
    required this.participants,
  });

  final String id;
  final String name;
  final String city;
  final int participants;
}

// ---------------------------------------------------------------------------
// Demo data
// ---------------------------------------------------------------------------

const _kDemoRooms = [
  _Room(
    id: '1',
    name: 'Школа №1024',
    city: 'Москва',
    participants: 78,
  ),
  _Room(
    id: '2',
    name: 'Гимназия №45',
    city: 'Москва',
    participants: 134,
  ),
  _Room(
    id: '3',
    name: 'Лицей «Вторая школа»',
    city: 'Москва',
    participants: 56,
  ),
  _Room(
    id: '4',
    name: 'ГБОУ СОШ №179',
    city: 'Москва',
    participants: 210,
  ),
  _Room(
    id: '5',
    name: 'Лицей №1535',
    city: 'Москва',
    participants: 92,
  ),
];

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class _RoomState {
  const _RoomState({
    this.query = '',
    this.selectedId,
  });

  final String query;
  final String? selectedId;

  List<_Room> filtered(List<_Room> rooms) {
    if (query.isEmpty) return rooms;
    final q = query.toLowerCase();
    return rooms
        .where((r) =>
            r.name.toLowerCase().contains(q) ||
            r.city.toLowerCase().contains(q))
        .toList();
  }

  _RoomState copyWith({String? query, Object? selectedId = _sentinel}) {
    return _RoomState(
      query: query ?? this.query,
      selectedId:
          selectedId == _sentinel ? this.selectedId : selectedId as String?,
    );
  }
}

const _sentinel = Object();

class _RoomNotifier extends StateNotifier<_RoomState> {
  _RoomNotifier() : super(const _RoomState());

  void setQuery(String q) => state = state.copyWith(query: q);

  void select(String id) {
    state = state.copyWith(selectedId: id);
  }
}

final _roomProvider =
    StateNotifierProvider.autoDispose<_RoomNotifier, _RoomState>(
  (ref) => _RoomNotifier(),
);

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class RoomScreen extends ConsumerStatefulWidget {
  const RoomScreen({super.key});

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_roomProvider);
    final notifier = ref.read(_roomProvider.notifier);
    final rooms = state.filtered(_kDemoRooms);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 32),

            // --- Icon + Title ---
            const Icon(
              Icons.house_rounded,
              size: 56,
              color: AppColors.primaryBlue,
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Выберите комнату',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- Search field ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                onChanged: notifier.setQuery,
                decoration: InputDecoration(
                  hintText: 'Поиск комнаты или класса',
                  hintStyle: const TextStyle(color: Colors.grey),
                  prefixIcon:
                      const Icon(Icons.search, color: AppColors.primaryBlue),
                  filled: true,
                  fillColor: const Color(0xFFF5F6FA),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // --- Room list ---
            Expanded(
              child: rooms.isEmpty
                  ? _EmptyState(
                      onCreateTap: () => context.push('/create-room'),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: rooms.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final room = rooms[i];
                        final isSelected = state.selectedId == room.id;
                        return _RoomTile(
                          room: room,
                          isSelected: isSelected,
                          onTap: () => notifier.select(room.id),
                        );
                      },
                    ),
            ),

            // --- Empty state hint (always shown below list) ---
            if (rooms.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Нет подходящей комнаты? ',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/create-room'),
                      child: const Text(
                        'Создайте свою комнату',
                        style: TextStyle(
                          color: AppColors.primaryBlue,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // --- Buttons ---
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: state.selectedId != null
                          ? () => context.go('/home')
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        disabledBackgroundColor: AppColors.primaryBlue.withOpacity(0.4),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Выбрать комнату',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => context.push('/create-room'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryBlue,
                        side: const BorderSide(
                            color: AppColors.primaryBlue, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Создать комнату',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Room tile
// ---------------------------------------------------------------------------

class _RoomTile extends StatelessWidget {
  const _RoomTile({
    required this.room,
    required this.isSelected,
    required this.onTap,
  });

  final _Room room;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Radio<String>(
              value: room.id,
              groupValue: isSelected ? room.id : null,
              onChanged: (_) => onTap(),
              activeColor: AppColors.primaryBlue,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${room.city}, ',
                        style: const TextStyle(
                            fontSize: 13, color: Colors.grey),
                      ),
                      Text(
                        '${room.participants} участников',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreateTap});

  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Нет подходящей комнаты?',
              style: TextStyle(color: Colors.grey, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: onCreateTap,
              child: const Text(
                'Создайте свою комнату',
                style: TextStyle(
                  color: AppColors.primaryBlue,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
