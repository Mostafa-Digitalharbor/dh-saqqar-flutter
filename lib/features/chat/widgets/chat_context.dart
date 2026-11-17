import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../shared/fig/fig.dart';
import '../../setup/setup_screens.dart'
    show ConnectionTabs, EnvMode, EnvTypePicker, FigDropdown;
import '../../vault/data/credential_models.dart';
import '../../vault/data/credentials_api.dart';
import '../../vault/data/project_models.dart';
import '../../vault/data/vault_repository.dart';
import '../../vault/view_model/vault_cubit.dart';
import '../../vault/view_model/vault_state.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/theme/app_sizes.dart';

part 'chat_context_companies.dart';
part 'chat_context_environment.dart';

/// The "ACTIVE CONTEXT" pill at the top of the chat: company avatar, company
/// name, environment chip and a chevron. Tapping opens the companies sheet.
class ChatContextPill extends StatelessWidget {
  const ChatContextPill({
    super.key,
    required this.company,
    required this.environment,
    required this.isLive,
    required this.readOnly,
    required this.onTap,
  });

  final String company;
  final String environment;
  final bool isLive;
  final bool readOnly;
  final VoidCallback onTap;

  String get _initials {
    final parts = company
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty);
    if (parts.isEmpty) return 'CM';
    final letters = parts.take(2).map((e) => e[0].toUpperCase()).join();
    return letters.length == 1 && company.length > 1
        ? company.substring(0, 2).toUpperCase()
        : letters;
  }

  @override
  Widget build(BuildContext context) {
    final hasEnv = environment.isNotEmpty;
    // Scales down rather than overflowing on a narrow phone, now that the
    // captions inside are held to the minimum readable size.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          // `minHeight`, not `height`: at larger text sizes the two-line label
          // must be able to grow the pill instead of overflowing it.
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(23),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Fig.blueAction, Color(0xFF1A3E96)],
                  ),
                ),
                child: Text(
                  _initials,
                  style: Fig.t(
                    context,
                    size: 10.5,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr.figActiveContext,
                    style: Fig.t(
                      context,
                      size: 5.5,
                      color: Colors.white.withValues(alpha: 0.8),
                      letterSpacing: 0.5,
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 70),
                    child: Text(
                      company.isEmpty ? context.tr.figCompany : company,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Fig.t(
                        context,
                        size: 10.5,
                        weight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              if (hasEnv) ...[
                const SizedBox(width: AppSpacing.s10),
                Container(
                  width: 1,
                  height: 22,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                const SizedBox(width: AppSpacing.s10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s9,
                    vertical: AppSpacing.s5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF123B2E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Fig.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s5),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 62),
                        child: Text(
                          environment,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Fig.t(
                            context,
                            size: 8.5,
                            color: const Color(0xFF8BE8C0),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(width: AppSpacing.s8),
              const Icon(
                LucideIcons.chevronDown,
                size: 16,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _dark = Fig.darkPanel;
