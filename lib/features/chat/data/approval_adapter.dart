/// Server `Approval` → the demo-shaped model the approval card consumes.
///
/// **Why this is one function and not two.** The chat screen and the rail
/// drawer each carried their own private `_adaptApiApproval`, over the same
/// input type (`inbox/data/approval_models.dart`, imported under two
/// different prefixes) and feeding the same `ChatApprovalCard`. They had
/// drifted:
///
///   * the inline card titled an approval **"Create 6 × Manufacturing
///     Order"** — the server's model label, the record count, and the
///     operation verb, in the user's language;
///   * the drawer titled the *same* approval **"Odoo write"** — the generic
///     action-type name, because its copy never learned about model labels.
///
/// On a screen whose whole job is "here is what the agent wants to do to
/// your Odoo — yes or no", the title is the sentence the user decides on.
/// Two surfaces describing one action differently is not a formatting
/// nit. The rich title wins because it is the one that actually says what
/// will happen.
///
/// `_riskFor` was duplicated verbatim as well — two copies of one table
/// whose output colours a chip on a destructive-action card. A new action
/// type added to one copy would have been rated `high` on one surface and
/// whatever the other copy said on the other.
///
/// No `BuildContext` here on purpose: everything it needs is [AppStrings],
/// so it is a pure function a test can call directly.
library;

import '../../../core/i18n/app_strings.dart';
import 'chat_view_models.dart';
import '../../inbox/data/approval_models.dart';

/// Risk band shown as a coloured chip on the approval card.
///
/// High by default, and only explicit reads step down — the bias matches
/// the web, and it is the safe direction to be wrong in: over-warning about
/// a harmless export costs a glance, under-warning about a write costs data.
String approvalRisk(ApprovalActionType type) => switch (type) {
      ApprovalActionType.credentialStorage => 'medium',
      ApprovalActionType.credentialUsage => 'medium',
      ApprovalActionType.reportExport => 'low',
      _ => 'high',
    };

/// The sentence the user approves.
///
/// Prefers the server-resolved model label, which yields "Create 6 ×
/// Manufacturing Order" in the active locale. Falls back to the action-type
/// title when the server sent no label — an approval must always be named,
/// even when it can only be named generically.
String approvalTitle(Approval approval, AppStrings tr) {
  final label = approval.modelLabel(isArabic: tr.isArabic);
  if (label == null) return tr.approvalActionTitle(approval.actionType.wire);

  final verb = tr.approvalOperationVerb(
    approval.payload['operation']?.toString(),
  );
  return tr.approvalModelTitle(verb, approval.recordCount, label);
}

/// Maps [approval] onto the model the card renders.
ChatApproval adaptApiApproval(Approval approval, AppStrings tr) {
  return ChatApproval(
    id: approval.id,
    title: approvalTitle(approval, tr),
    prompt: approval.prompt,
    actionType: approval.actionType.wire,
    risk: approvalRisk(approval.actionType),
    status: switch (approval.status) {
      ApprovalStatus.pending => ChatApprovalStatus.pending,
      ApprovalStatus.approved => ChatApprovalStatus.approved,
      ApprovalStatus.rejected => ChatApprovalStatus.rejected,
    },
    // NULLS ARE DROPPED, not stringified. `value.toString()` on a null yields
    // the literal string "null", and the server sends null for every optional
    // field — so an ordinary email approval (cc, bcc and in_reply_to all null)
    // rendered "Cc: null", "Bcc: null", and a Reply badge on every single
    // mail, because "null" is a non-empty string. An absent field must read
    // as absent.
    payload: {
      for (final entry in approval.payload.entries)
        if (entry.value != null) entry.key: entry.value.toString(),
    },
    recordCount: approval.recordCount,
    // The delete type-to-confirm gate lives on the card, so every surface
    // that renders approvals needs the server's phrase — dropping it would
    // leave that surface accepting only client-built strings.
    confirmPhrase: approval.confirmPhrase,
    deleteRecords: approval.deleteRecords,
    batchScoped: approval.batchScoped,
  );
}
