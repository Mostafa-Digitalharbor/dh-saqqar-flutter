import 'package:flutter/widgets.dart';

import '../../../core/i18n/app_localizations.dart';

/// Canonical tool names the backend reports while the agent is running.
/// Kept verbatim from the web (`pendingStatusForTool` in app.js line 2421)
/// so the two clients stay in lockstep — any new tool added server-side
/// only needs a constant + a status-text branch added here.
class ToolNames {
  ToolNames._();

  static const requestCredentials = 'request_credentials';
  static const countOdooRecords = 'count_odoo_records';
  static const searchOdooRecords = 'search_odoo_records';
  static const describeOdooModel = 'describe_odoo_model';
  static const createOdooRecord = 'create_odoo_record';
  static const writeOdooRecords = 'write_odoo_records';
  static const deleteOdooRecords = 'delete_odoo_records';
  static const callOdooMethod = 'call_odoo_method';
  static const runReadonlySql = 'run_readonly_sql';
  static const generateExcelReport = 'generate_excel_report';
  static const generatePdfReport = 'generate_pdf_report';
  static const generatePdfDocument = 'generate_pdf_document';
  static const generateWordReport = 'generate_word_report';
  static const generateWordDocument = 'generate_word_document';
  static const listGithubDirectory = 'list_github_directory';
  static const getGithubFile = 'get_github_file';
  static const requestShellCommandApproval = 'request_shell_command_approval';
  static const runServerCommand = 'run_server_command';
}

/// Resolves the localised "Saqqar is doing X" label for the chat typing
/// row. Mirrors the web's `pendingStatusForTool()` switch — both clients
/// MUST keep the same mapping so a user moving between web and mobile gets
/// the same in-flight feedback.
///
/// Returns a generic "Finishing response" label when [toolName] is null
/// or unrecognised (e.g. an older backend that hasn't been taught about a
/// new tool yet).
String pendingStatusForTool(
  BuildContext context, {
  String? toolName,
  bool hasAttachment = false,
}) {
  // Attachment review takes priority over any tool branch — the web
  // applies the same rule because the attachment status is what the user
  // is actually waiting for in that turn.
  if (hasAttachment) return context.tr.activityReviewingAttachment;

  switch (toolName) {
    case ToolNames.requestCredentials:
      return context.tr.activityPreparingAccess;
    case ToolNames.countOdooRecords:
    case ToolNames.searchOdooRecords:
      return context.tr.activityCheckingOdoo;
    case ToolNames.describeOdooModel:
      return context.tr.activityInspectingOdooModel;
    case ToolNames.createOdooRecord:
    case ToolNames.writeOdooRecords:
    case ToolNames.deleteOdooRecords:
    case ToolNames.callOdooMethod:
      return context.tr.activityApplyingOdooChange;
    case ToolNames.runReadonlySql:
      return context.tr.activityRunningQuery;
    case ToolNames.generateExcelReport:
      return context.tr.activityBuildingExcel;
    case ToolNames.generatePdfReport:
    case ToolNames.generatePdfDocument:
      return context.tr.activityBuildingPdf;
    case ToolNames.generateWordReport:
    case ToolNames.generateWordDocument:
      return context.tr.activityBuildingWord;
    case ToolNames.listGithubDirectory:
    case ToolNames.getGithubFile:
      return context.tr.activityReadingRepo;
    case ToolNames.requestShellCommandApproval:
      return context.tr.activityPreparingApproval;
    case ToolNames.runServerCommand:
      return context.tr.activityRunningCommand;
    default:
      return context.tr.activityFinishingResponse;
  }
}

/// Maps free-form user-prompt text (or assistant placeholder messages) to
/// the most likely tool the agent will reach for, so the typing row can
/// show contextual feedback BEFORE the backend reports the actual tool
/// call. Heuristic — once the chat is wired to the live streaming API,
/// callers should prefer the real `toolName` from the last assistant /
/// tool message and only fall back to this helper for the first frame.
String? guessToolFromPrompt(String prompt) {
  final lower = prompt.toLowerCase();
  if (lower.contains('excel') ||
      lower.contains('xlsx') ||
      lower.contains('csv') ||
      lower.contains('export') ||
      lower.contains('صدّر') ||
      lower.contains('تقرير')) {
    return ToolNames.generateExcelReport;
  }
  if (lower.contains('pdf') || lower.contains('بي دي اف')) {
    return ToolNames.generatePdfReport;
  }
  if (lower.contains('word') ||
      lower.contains('docx') ||
      lower.contains('مستند')) {
    return ToolNames.generateWordReport;
  }
  if (lower.contains('sql') ||
      lower.contains('postgres') ||
      lower.contains('database') ||
      lower.contains('قاعدة')) {
    return ToolNames.runReadonlySql;
  }
  if (lower.contains('log') ||
      lower.contains('tail') ||
      lower.contains('shell') ||
      lower.contains('command') ||
      lower.contains('سيرفر') ||
      lower.contains('سجل')) {
    return ToolNames.runServerCommand;
  }
  if (lower.contains('repo') ||
      lower.contains('github') ||
      lower.contains('addons') ||
      lower.contains('module')) {
    return ToolNames.listGithubDirectory;
  }
  if (lower.contains('describe') ||
      lower.contains('model') ||
      lower.contains('schema')) {
    return ToolNames.describeOdooModel;
  }
  if (lower.contains('write') ||
      lower.contains('update') ||
      lower.contains('delete') ||
      lower.contains('create')) {
    return ToolNames.writeOdooRecords;
  }
  if (lower.contains('odoo') ||
      lower.contains('user') ||
      lower.contains('count') ||
      lower.contains('search')) {
    return ToolNames.countOdooRecords;
  }
  return null;
}
