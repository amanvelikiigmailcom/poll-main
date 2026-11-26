import 'package:flutter/material.dart';
import '../../models/received_vote.dart';
import '../../theme/app_colors.dart';

/// Shared by the actual received-vote result and its image export.
/// Takes only the public historical projection, never voter/reveal data.
class VoteResultContent extends StatelessWidget {
  const VoteResultContent({super.key, required this.vote});
  final ReceivedVote vote;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        vote.question,
        style: const TextStyle(
          fontSize: 24,
          height: 1.3,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        vote.voterLabel,
        style: const TextStyle(
          color: AppColors.primaryBlue,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 24),
      const Text(
        'Answer options',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: 6),
      const Text(
        'People shown as answer options for this question.',
        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
      const SizedBox(height: 14),
      if (vote.participants.isEmpty)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Participants are not available for this quiz result.',
            textAlign: TextAlign.center,
          ),
        )
      else
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final participant in vote.participants)
                SizedBox(
                  width: (constraints.maxWidth - 12) / 2,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        const CircleAvatar(
                          radius: 30,
                          backgroundColor: Color(0xFFEFF1FE),
                          child: Text('🙂', style: TextStyle(fontSize: 34)),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          participant.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (participant.graduationYear != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Class of ${participant.graduationYear}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
    ],
  );
}
