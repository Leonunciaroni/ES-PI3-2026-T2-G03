// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Banner para indicar o canal de entrega do código de verificação (SMS ou e-mail).
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Canal pelo qual o usuário recebe o código de verificação.
enum OtpDeliveryChannel {
  sms,
  email,
}

/// Indica de forma explícita se o código foi enviado por **SMS** ou por **e-mail**
/// e para qual destino (telefone mascarado ou e-mail).
class OtpDeliveryBanner extends StatelessWidget {
  const OtpDeliveryBanner({
    super.key,
    required this.channel,
    this.destinationDetail,
  });

  final OtpDeliveryChannel channel;
  final String? destinationDetail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSms = channel == OtpDeliveryChannel.sms;
    final icon = isSms ? Icons.sms_outlined : Icons.mark_email_read_outlined;
    final channelName = isSms ? 'SMS' : 'E-mail';

    final dest = destinationDetail?.trim();
    final whereText = (dest != null && dest.isNotEmpty)
        ? dest
        : (isSms
            ? 'o número associado à sua conta'
            : 'o endereço da sua conta');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.secondaryLabel(theme),
                  height: 1.4,
                ),
                children: [
                  const TextSpan(text: 'Código enviado por '),
                  TextSpan(
                    text: channelName,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const TextSpan(text: ' para '),
                  TextSpan(
                    text: whereText,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
