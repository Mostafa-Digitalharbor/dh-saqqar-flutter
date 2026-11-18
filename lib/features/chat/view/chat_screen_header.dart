part of 'chat_screen.dart';

/// The chat's top bar: info, company / environment pill and menu.
extension _ChatHeader on _ChatScreenState {
  /// Redesign header: hamburger, the ACTIVE CONTEXT pill, and (only when
  /// something is waiting) the approvals bell.
  Widget _chatHeader({
    required String company,
    required String environment,
    required bool isLive,
    required bool readOnly,
    required int pending,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.s14, AppSpacing.s36, AppSpacing.s14, 0),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _update(() {
              _sidebarOpen = true;
              _railOpen = false;
            }),
            child: const SizedBox(
              width: FigMetrics.size48, height: FigMetrics.size48,
              child: Icon(LucideIcons.menu, color: AppColors.figWhite, size: AppIconSizes.back),
            ),
          ),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: ChatContextPill(
                  company: company,
                  environment: environment,
                  isLive: isLive,
                  readOnly: readOnly,
                  onTap: _openCompanies,
                ),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: context.tr.figWorkspace,
            excludeSemantics: true,
            child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _update(() {
              _railOpen = true;
              _sidebarOpen = false;
            }),
            child: SizedBox(
              width: FigMetrics.size48, height: FigMetrics.size48,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: FigMetrics.size30, height: FigMetrics.size30,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.tight),
                      border: Border.all(color: AppColors.figWhite, width: FigMetrics.bwFig1U6),
                    ),
                    child: const Icon(
                      LucideIcons.layoutPanelLeft,
                      size: AppIconSizes.listMark,
                      color: AppColors.figWhite,
                    ),
                  ),
                  if (pending > 0)
                    Positioned(
                      top: AppSpacing.s4,
                      right: AppSpacing.s2,
                      child: Container(
                        width: FigMetrics.size10, height: FigMetrics.size10,
                        decoration: const BoxDecoration(
                          color: AppColors.figCFFFF5A4D,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }
}
