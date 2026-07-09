import SwiftUI

struct ContentView: View {
  @EnvironmentObject private var session: PhoneSession
  @State private var actionsInFlight: Set<String> = []

  var body: some View {
    NavigationStack {
      VStack(spacing: 6) {
        HStack {
          SaqqarBrandHeader()
          Spacer()
          if session.pendingCount > 0 {
            Text("\(session.pendingCount)")
              .font(.system(.caption2, design: .monospaced).bold())
              .monospacedDigit()
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .foregroundStyle(.black)
              .background(SaqqarColor.cyan, in: Capsule())
          }
        }
        .padding(.horizontal, 4)

        Group {
          if session.approvals.isEmpty {
            emptyState
          } else {
            List(session.approvals) { approval in
              ApprovalRow(
                approval: approval,
                isBusy: actionsInFlight.contains(approval.id),
                onDecide: { approved in decide(approval, approved: approved) }
              )
              .listRowBackground(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                  .fill(SaqqarColor.surface)
                  .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                      .stroke(SaqqarColor.cyan.opacity(0.25), lineWidth: 1)
                  )
              )
            }
            .listStyle(.carousel)
            .scrollContentBackground(.hidden)
            .background(SaqqarColor.bg)
          }
        }
      }
      .background(SaqqarColor.bg)
      .navigationTitle("")
      .alert(
        "Couldn't sync",
        isPresented: Binding(
          get: { session.lastError != nil },
          set: { if !$0 { session.lastError = nil } }
        )
      ) {
        Button("OK", role: .cancel) { session.lastError = nil }
      } message: {
        Text(session.lastError ?? "")
      }
    }
  }

  private var emptyState: some View {
    VStack(spacing: 12) {
      if session.isReachable {
        ZStack {
          Circle()
            .fill(SaqqarColor.cyan.opacity(0.14))
            .frame(width: 88, height: 88)
            .blur(radius: 8)
          SaqqarLogoMark(size: 60)
        }
      } else {
        Image(systemName: "iphone.slash")
          .font(.system(size: 32, weight: .bold))
          .foregroundStyle(SaqqarColor.muted)
      }
      Text(session.isReachable ? "[ ALL CLEAR ]" : "[ IPHONE OFFLINE ]")
        .font(.system(.caption2, design: .monospaced).bold())
        .tracking(1)
        .multilineTextAlignment(.center)
        .foregroundStyle(session.isReachable ? SaqqarColor.cyan : SaqqarColor.muted)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(SaqqarColor.bg)
  }

  private func decide(_ approval: WatchApproval, approved: Bool) {
    actionsInFlight.insert(approval.id)
    session.decide(approval, approved: approved) { _ in
      actionsInFlight.remove(approval.id)
    }
  }
}

private struct ApprovalRow: View {
  let approval: WatchApproval
  let isBusy: Bool
  let onDecide: (Bool) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Label(approval.actionTypeLabel, systemImage: approval.actionTypeIcon)
        .font(.system(.caption2, design: .monospaced).bold())
        .textCase(.uppercase)
        .foregroundStyle(SaqqarColor.cyan)
      Text(approval.prompt)
        .font(.footnote)
        .lineLimit(3)
      if !approval.conversationTitle.isEmpty {
        Text(approval.conversationTitle)
          .font(.system(.caption2, design: .monospaced))
          .foregroundStyle(SaqqarColor.muted)
          .lineLimit(1)
      }
      HStack(spacing: 8) {
        Button(role: .destructive) {
          onDecide(false)
        } label: {
          Label("Deny", systemImage: "xmark")
        }
        .tint(SaqqarColor.danger)

        Button {
          onDecide(true)
        } label: {
          Label("Approve", systemImage: "checkmark")
        }
        .tint(SaqqarColor.cyan)
      }
      .labelStyle(.iconOnly)
      .buttonStyle(.bordered)
      .disabled(isBusy)
      .opacity(isBusy ? 0.5 : 1)
    }
    .padding(.vertical, 4)
  }
}

#Preview {
  ContentView().environmentObject(PhoneSession.shared)
}
