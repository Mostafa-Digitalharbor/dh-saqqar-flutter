import 'package:flutter/foundation.dart';

import '../../inbox/data/approval_models.dart'
    show Approval, ApprovalActionType, kDeleteOperation;

/// Collapsing a burst of near-identical approvals into one card.
///
/// When the agent writes six manufacturing orders it does not ask once — it
/// raises six approvals, one per record, differing only in their ids. The web
/// shows that as a single "6 similar requests" card with one Approve-all and
/// one Reject-all; the app was showing six full cards, so clearing a routine
/// batch meant six scrolls and twelve taps, and there was no way to reject
/// them together at all.
///
/// The grouping is done HERE, on the pending list, exactly as the web does it
/// (`groupApprovalsByShape` in the web bundle). This is the part worth being
/// explicit about, because an earlier version of this app tried to read the
/// group size off the wire and was removed for it: there is no `grouped_count`
/// field and there never was. A card cannot know its own group size — but the
/// *list* knows, because it holds every sibling. So "6" here is counted, not
/// reported, and it is the same 6 the web counts from the same list.
@immutable
class ApprovalGroup {
  const ApprovalGroup({required this.key, required this.approvals});

  /// `action_type|operation|model`, or null for a card that stands alone.
  final String? key;

  /// Never empty. One entry for a single card, two or more for a group.
  final List<Approval> approvals;

  bool get isGroup => approvals.length > 1;
  Approval get first => approvals.first;
  int get count => approvals.length;
}

/// The three fields that make two approvals "the same request twice".
///
/// Record ids are deliberately NOT part of the key — they are the only thing
/// that differs between siblings, which is the whole point.
String? approvalShapeKey(Approval approval) {
  final operation = approval.payload['operation']?.toString();
  final model = approval.payload['model']?.toString();
  if (operation == null || operation.isEmpty) return null;
  if (model == null || model.isEmpty) return null;
  return '${approval.actionType.wire}|$operation|$model';
}

/// Whether [approval] may be merged into a group.
///
/// This is deliberately the same test as `ChatApproval.canBatchApprove`
/// rather than the web's looser one: a group's headline button POSTs
/// `scope: "batch"`, so anything that must not be batch-approved must not be
/// grouped either, or the card would offer a button the server refuses.
///
///   * **Odoo writes only** — one tap that pre-approves future
///     `server_command` or `credential_storage` requests is an escalation the
///     user did not ask for.
///   * **Never deletes** — the server 400s on a batched delete, and a batch
///     delete is the one mistake with no undo. Each delete keeps its own card,
///     its own record list and its own red button.
///   * **Not already scoped** — `payload.batch_scope` means an earlier grant
///     already covers it.
bool approvalIsGroupable(Approval approval) =>
    approvalShapeKey(approval) != null &&
    approval.actionType == ApprovalActionType.odooWrite &&
    !approval.batchScoped &&
    approval.payload['operation'] != kDeleteOperation;

/// Groups [pending] by shape, preserving the order of first appearance.
///
/// Order is by first appearance rather than by size so that "the next thing to
/// decide" does not jump around as new approvals stream in on a poll tick — a
/// card the user was reading must not be reordered under their thumb.
///
/// A group that ends up with one member is demoted back to a single card:
/// "1 similar request" is a worse card than the request itself.
List<ApprovalGroup> groupApprovalsByShape(List<Approval> pending) {
  final order = <List<Approval>>[];
  final keys = <String?>[];
  final byKey = <String, int>{};

  for (final approval in pending) {
    final key = approvalIsGroupable(approval)
        ? approvalShapeKey(approval)
        : null;
    if (key == null) {
      order.add([approval]);
      keys.add(null);
      continue;
    }
    final slot = byKey[key];
    if (slot == null) {
      byKey[key] = order.length;
      order.add([approval]);
      keys.add(key);
    } else {
      order[slot].add(approval);
    }
  }

  return [
    for (var i = 0; i < order.length; i++)
      ApprovalGroup(
        key: order[i].length > 1 ? keys[i] : null,
        approvals: List.unmodifiable(order[i]),
      ),
  ];
}
