import SwiftUI

/// Voice-command tab. Picks a project/environment once per conversation —
/// same requirement the phone's chat screen enforces ("the agent has no
/// credentials to work against otherwise") — then records a short voice
/// note and has the phone transcribe + forward it as a normal chat turn.
/// Anything the assistant needs a decision on shows up in the Approvals
/// tab exactly like it would from the main app; this screen only owns
/// context selection, capture, and the immediate reply.
struct VoiceCommandView: View {
  @EnvironmentObject private var session: PhoneSession
  @StateObject private var recorder = VoiceRecorder()

  // Context (project/environment) picking.
  @State private var path: [WatchProject] = []
  @State private var projects: [WatchProject] = []
  @State private var isLoadingProjects = false
  @State private var isProvisioningDefault = false
  @State private var contextError: String?
  @State private var selectedProjectName: String?
  @State private var selectedEnvironment: WatchEnvironment?
  @State private var hasPickedContext = false

  // Recording / sending.
  @State private var phase: Phase = .idle
  @State private var conversationId: String?
  @State private var transcript: String?
  @State private var reply: String?
  @State private var errorMessage: String?
  @State private var stillWorkingWorkItem: DispatchWorkItem?

  /// How long the spinner stays up waiting for [PhoneSession.lateVoiceReply]
  /// before giving up and showing a placeholder — a client-side backstop
  /// under the phone's own 5-minute background poll, so the watch doesn't
  /// spin forever if delivery genuinely never arrives. The real answer
  /// still wins over this placeholder if it shows up after the fact (see
  /// `applyLateReplyIfCurrent`).
  private static let stillWorkingFallbackDelay: TimeInterval = 90

  private enum Phase: Equatable {
    case idle, recording, sending, done, failed
  }

  var body: some View {
    NavigationStack(path: $path) {
      VStack(spacing: 6) {
        SaqqarBrandHeader()
        Group {
          if hasPickedContext {
            micFlow
          } else {
            contextPickerRoot
          }
        }
      }
      .background(SaqqarColor.bg)
      .navigationTitle("")
      .navigationDestination(for: WatchProject.self) { project in
        environmentPicker(for: project)
      }
    }
    .onAppear {
      if !hasPickedContext && projects.isEmpty && !isLoadingProjects {
        loadProjects()
      }
    }
    .onChange(of: session.lateVoiceReply) { _, value in
      applyLateReplyIfCurrent(value)
    }
  }

  /// A reply that arrived after `sendVoiceCommand`'s own round-trip
  /// already returned. Only worth applying if it's for the conversation
  /// still on screen — otherwise leave it for the notification alone to
  /// carry. Always wins over whatever's already shown for that
  /// conversation (the server's own run-completion signal, so it's more
  /// authoritative than anything captured mid-run), except while a new
  /// recording is actively in progress.
  private func applyLateReplyIfCurrent(_ value: LateVoiceReply?) {
    guard let value, value.conversationId == conversationId, phase != .recording else { return }
    stillWorkingWorkItem?.cancel()
    reply = value.reply
    phase = .done
    session.clearLateVoiceReply()
  }

  // MARK: - Context picker

  @ViewBuilder
  private var contextPickerRoot: some View {
    if isLoadingProjects {
      terminalStatus(">_ scanning projects…", color: SaqqarColor.cyan, showsSpinner: true)
    } else if let contextError {
      VStack(spacing: 10) {
        Text("[ ERROR ]")
          .font(.system(.caption2, design: .monospaced).bold())
          .foregroundStyle(SaqqarColor.danger)
        Text(contextError)
          .font(.footnote)
          .multilineTextAlignment(.center)
        terminalButton("RETRY", color: SaqqarColor.cyan) { loadProjects() }
      }
      .padding()
    } else if projects.isEmpty {
      emptyProjectsState
    } else {
      List {
        Button("> no environment") { pickNoEnvironment() }
          .font(.system(.footnote, design: .monospaced))
          .foregroundStyle(SaqqarColor.muted)
        ForEach(projects) { project in
          NavigationLink(value: project) {
            Text(project.name.isEmpty ? "untitled" : project.name)
              .font(.system(.footnote, design: .monospaced))
          }
        }
      }
      .scrollContentBackground(.hidden)
      .background(SaqqarColor.bg)
    }
  }

  private var emptyProjectsState: some View {
    VStack(spacing: 10) {
      SaqqarLogoMark(size: 40)
      Text("[ NO PROJECTS ]")
        .font(.system(.caption2, design: .monospaced).bold())
        .tracking(1)
        .foregroundStyle(SaqqarColor.muted)
      terminalButton(isProvisioningDefault ? "SETTING UP…" : "USE MY DATABASE", color: SaqqarColor.cyan) {
        useDefaultProject()
      }
      .disabled(isProvisioningDefault)
      Button("> skip, no environment") { pickNoEnvironment() }
        .font(.system(.caption2, design: .monospaced))
        .buttonStyle(.plain)
        .foregroundStyle(SaqqarColor.muted)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(SaqqarColor.bg)
  }

  private func environmentPicker(for project: WatchProject) -> some View {
    List {
      Button("> no environment") { pickNoEnvironment() }
        .font(.system(.footnote, design: .monospaced))
        .foregroundStyle(SaqqarColor.muted)
      ForEach(project.environments) { env in
        Button {
          pick(project: project, environment: env)
        } label: {
          HStack {
            Text(env.name.isEmpty ? "untitled" : env.name)
              .font(.system(.footnote, design: .monospaced))
            if env.isLive {
              Spacer()
              Text("LIVE")
                .font(.system(.caption2, design: .monospaced).bold())
                .foregroundStyle(SaqqarColor.purple)
            }
          }
        }
      }
    }
    .scrollContentBackground(.hidden)
    .background(SaqqarColor.bg)
    .navigationTitle(project.name.isEmpty ? "ENV" : project.name.uppercased())
  }

  private func loadProjects() {
    guard session.isReachable else {
      contextError = "Open Saqqar on your iPhone to sync."
      return
    }
    isLoadingProjects = true
    contextError = nil
    session.fetchProjects { result in
      isLoadingProjects = false
      switch result {
      case .success(let value):
        projects = value
      case .failure(let error):
        contextError = error.message
      }
    }
  }

  private func useDefaultProject() {
    isProvisioningDefault = true
    session.useDefaultProject { result in
      isProvisioningDefault = false
      switch result {
      case .success(let value):
        selectedProjectName = nil
        selectedEnvironment = WatchEnvironment(dict: [
          "id": value.environmentId,
          "name": value.environmentName,
          "isLive": false,
        ])
        hasPickedContext = true
        path = []
      case .failure(let error):
        contextError = error.message
      }
    }
  }

  private func pick(project: WatchProject, environment: WatchEnvironment) {
    selectedProjectName = project.name
    selectedEnvironment = environment
    hasPickedContext = true
    path = []
  }

  private func pickNoEnvironment() {
    selectedProjectName = nil
    selectedEnvironment = nil
    hasPickedContext = true
    path = []
  }

  private func resetContext() {
    hasPickedContext = false
    selectedProjectName = nil
    selectedEnvironment = nil
    stillWorkingWorkItem?.cancel()
    // A new environment means a new conversation — carrying the old one
    // forward would leave it bound to whatever it already had.
    conversationId = nil
    transcript = nil
    reply = nil
    errorMessage = nil
    phase = .idle
    path = []
    loadProjects()
  }

  // MARK: - Mic flow

  private var micFlow: some View {
    ScrollView {
      VStack(spacing: 12) {
        contextLabel
        content
      }
      .padding()
      .frame(maxWidth: .infinity)
    }
    .background(SaqqarColor.bg)
  }

  private var contextLabel: some View {
    HStack(spacing: 4) {
      Text("[ \(contextDescription.uppercased()) ]")
        .font(.system(.caption2, design: .monospaced))
        .lineLimit(1)
        .foregroundStyle(SaqqarColor.muted)
      Spacer()
      Button("CHANGE") { resetContext() }
        .font(.system(.caption2, design: .monospaced).bold())
        .buttonStyle(.plain)
        .foregroundStyle(SaqqarColor.cyan)
    }
  }

  private var contextDescription: String {
    guard let env = selectedEnvironment, !env.id.isEmpty else { return "no environment" }
    if let selectedProjectName, !selectedProjectName.isEmpty {
      return "\(selectedProjectName) · \(env.name)"
    }
    return env.name
  }

  @ViewBuilder
  private var content: some View {
    switch phase {
    case .idle: idleState
    case .recording: recordingState
    case .sending: sendingState
    case .done: resultState
    case .failed: failedState
    }
  }

  private var idleState: some View {
    Button {
      startRecording()
    } label: {
      VStack(spacing: 10) {
        ZStack {
          Circle()
            .stroke(SaqqarColor.cyan.opacity(0.3), lineWidth: 1)
            .frame(width: 64, height: 64)
          Image(systemName: "waveform.badge.mic")
            .font(.system(size: 30))
            .foregroundStyle(SaqqarColor.cyan)
        }
        Text(session.isReachable ? "> tap to transmit" : "[ IPHONE OFFLINE ]")
          .font(.system(.footnote, design: .monospaced))
          .multilineTextAlignment(.center)
          .foregroundStyle(session.isReachable ? SaqqarColor.muted : SaqqarColor.danger)
      }
    }
    .buttonStyle(.plain)
    .disabled(!session.isReachable)
  }

  private var recordingState: some View {
    VStack(spacing: 10) {
      HStack(spacing: 6) {
        Circle().fill(SaqqarColor.danger).frame(width: 8, height: 8)
        Text("RECORDING")
          .font(.system(.caption2, design: .monospaced).bold())
          .tracking(1)
          .foregroundStyle(SaqqarColor.danger)
      }
      Text(String(format: "%02.0f:%02.0f", recorder.elapsed, VoiceRecorder.maxDuration))
        .font(.system(.title3, design: .monospaced).bold())
        .foregroundStyle(SaqqarColor.cyan)
      terminalButton("DONE", color: SaqqarColor.cyan) { finishRecording() }
      Button("> cancel") { cancelRecording() }
        .font(.system(.caption2, design: .monospaced))
        .buttonStyle(.plain)
        .foregroundStyle(SaqqarColor.muted)
    }
  }

  private var sendingState: some View {
    terminalStatus(">_ awaiting response…", color: SaqqarColor.cyan, showsSpinner: true)
  }

  private var resultState: some View {
    VStack(alignment: .leading, spacing: 10) {
      if let transcript {
        VStack(alignment: .leading, spacing: 2) {
          Text("[ TRANSCRIPT ]")
            .font(.system(.caption2, design: .monospaced).bold())
            .foregroundStyle(SaqqarColor.muted)
          Text(transcript)
            .font(.footnote)
            .foregroundStyle(SaqqarColor.muted)
        }
      }
      VStack(alignment: .leading, spacing: 2) {
        Text("[ RESPONSE ]")
          .font(.system(.caption2, design: .monospaced).bold())
          .foregroundStyle(SaqqarColor.cyan)
        Text(reply ?? "Still working — check the app or your pending approvals.")
          .font(.footnote)
      }
      terminalButton("ASK AGAIN", color: SaqqarColor.cyan) { reset() }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var failedState: some View {
    VStack(spacing: 10) {
      Text("[ ERROR ]")
        .font(.system(.caption2, design: .monospaced).bold())
        .foregroundStyle(SaqqarColor.danger)
      Text(errorMessage ?? "Something went wrong.")
        .font(.footnote)
        .multilineTextAlignment(.center)
      terminalButton("RETRY", color: SaqqarColor.danger) { reset() }
    }
  }

  /// Shared "terminal window" status block for loading/waiting states —
  /// a monospaced prompt line plus an optional spinner, on the dark bg.
  private func terminalStatus(_ text: String, color: Color, showsSpinner: Bool) -> some View {
    VStack(spacing: 10) {
      if showsSpinner {
        SaqqarLoadingMark(size: 40)
      }
      Text(text)
        .font(.system(.footnote, design: .monospaced))
        .foregroundStyle(color)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  /// Shared bracket-style command button — bold monospaced caps in a
  /// thin-bordered pill, matching the terminal aesthetic instead of a
  /// stock rounded system button.
  private func terminalButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(title)
        .font(.system(.caption, design: .monospaced).bold())
        .tracking(1)
    }
    .tint(color)
  }

  private func startRecording() {
    guard session.isReachable else { return }
    recorder.requestPermissionAndStart { granted in
      if granted {
        phase = .recording
      } else {
        errorMessage = recorder.lastError
        phase = .failed
      }
    }
  }

  private func finishRecording() {
    guard let url = recorder.stop() else {
      reset()
      return
    }
    phase = .sending
    session.sendVoiceCommand(
      fileURL: url,
      conversationId: conversationId,
      environmentId: environmentIdForNextTurn
    ) { result in
      switch result {
      case .success(let value):
        conversationId = value.conversationId
        transcript = value.transcript
        if let reply = value.reply {
          self.reply = reply
          phase = .done
        } else {
          // The run outlived the interactive request — keep the spinner
          // up rather than dead-ending on "Ask again" with nothing to
          // show. `applyLateReplyIfCurrent` flips this to `.done` for
          // real once the actual answer lands.
          phase = .sending
          scheduleStillWorkingFallback(for: value.conversationId)
        }
      case .failure(let error):
        errorMessage = error.message
        phase = .failed
      }
    }
  }

  private func scheduleStillWorkingFallback(for expectedConversationId: String) {
    stillWorkingWorkItem?.cancel()
    let workItem = DispatchWorkItem {
      guard phase == .sending, conversationId == expectedConversationId else { return }
      reply = nil
      phase = .done
    }
    stillWorkingWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.stillWorkingFallbackDelay, execute: workItem)
  }

  /// Binding only ever happens on the first turn of a conversation — once
  /// [conversationId] exists the environment is already bound server-side.
  private var environmentIdForNextTurn: String? {
    guard conversationId == nil, let id = selectedEnvironment?.id, !id.isEmpty else { return nil }
    return id
  }

  private func cancelRecording() {
    recorder.cancel()
    phase = .idle
  }

  private func reset() {
    stillWorkingWorkItem?.cancel()
    transcript = nil
    reply = nil
    errorMessage = nil
    phase = .idle
  }
}

#Preview {
  VoiceCommandView().environmentObject(PhoneSession.shared)
}
