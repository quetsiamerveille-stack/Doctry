import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/formatters.dart';
import '../models/declaration.dart';
import 'common.dart';

class MatchCard extends StatelessWidget {
  const MatchCard({
    super.key,
    required this.match,
    this.onContact,
    this.onConfirmReturn,
    this.onRelease,
    this.onReward,
  });

  final MatchResult match;
  final VoidCallback? onContact;
  final VoidCallback? onConfirmReturn;
  final VoidCallback? onRelease;
  final VoidCallback? onReward;

  Color get _statusColor {
    if (match.findStatus == 'returned' || match.lossStatus == 'returned') {
      return AppColors.green;
    }
    if (match.rewardStatus == 'escrow') {
      return AppColors.gold;
    }
    return AppColors.siam;
  }

  String get _statusLabel {
    if (match.findStatus == 'returned' || match.lossStatus == 'returned') {
      return 'Restitué';
    }
    if (match.rewardStatus == 'escrow') {
      return 'Récompense séquestrée';
    }
    return 'Correspondance active';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.7), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.goldSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.link, color: AppColors.darkBlue, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Document similaire trouvé',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: AppColors.darkBlue,
                      ),
                    ),
                    Text(
                      '${Fmt.docType(match.docType)} · ${match.counterpartName.isEmpty ? 'Membre DOCTRY' : match.counterpartName}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              StatusBadge(label: _statusLabel, color: _statusColor),
            ],
          ),
          const SizedBox(height: 12),
          _InfoLine(
            icon: Icons.psychology_outlined,
            label: 'Score IA',
            value: '${match.percent} % · ${match.engineLabel}',
          ),
          if (match.reason.isNotEmpty)
            _InfoLine(icon: Icons.notes_outlined, label: 'Analyse', value: match.reason),
          if (match.rewardAmount > 0)
            _InfoLine(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Récompense',
              value: '${Fmt.money(match.rewardAmount)} · ${Fmt.rewardStatus(match.rewardStatus)}',
            ),
          _InfoLine(
            icon: Icons.schedule,
            label: 'Détecté le',
            value: Fmt.dateTime(match.createdAt),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (onContact != null)
                DoctryButton(
                  label: 'Contacter',
                  icon: Icons.chat_outlined,
                  onPressed: onContact,
                ),
              if (onConfirmReturn != null &&
                  match.lossStatus != 'returned' &&
                  match.findStatus != 'returned')
                DoctryButton(
                  label: 'Restitution effectuée',
                  icon: Icons.handshake_outlined,
                  color: AppColors.green,
                  onPressed: onConfirmReturn,
                ),
              if (onRelease != null &&
                  match.rewardStatus == 'escrow' &&
                  (match.lossStatus == 'returned' || match.findStatus == 'returned'))
                DoctryButton(
                  label: 'Envoyer la récompense',
                  icon: Icons.send_to_mobile_outlined,
                  variant: DoctryButtonVariant.gold,
                  onPressed: onRelease,
                ),
              if (onReward != null && match.rewardStatus == 'none')
                DoctryButton(
                  label: 'Associer une récompense',
                  icon: Icons.card_giftcard_outlined,
                  variant: DoctryButtonVariant.outlined,
                  onPressed: onReward,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 15, color: AppColors.siam),
          const SizedBox(width: 8),
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
