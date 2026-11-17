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
      padding: const EdgeInsets.fromLTRB(14, 36, 14, 0),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _update(() {
              _sidebarOpen = true;
              _railOpen = false;
            }),
            child: const SizedBox(
              width: 48,
              height: 48,
              child: Icon(LucideIcons.menu, color: Colors.white, size: 24),
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
              width: 48,
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 1.6),
                    ),
                    child: const Icon(
                      LucideIcons.layoutPanelLeft,
                      size: 17,
                      color: Colors.white,
                    ),
                  ),
                  if (pending > 0)
                    Positioned(
                      top: 4,
                      right: 2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF5A4D),
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
