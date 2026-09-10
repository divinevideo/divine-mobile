// ABOUTME: Full-screen flow for submitting bug reports to Zendesk
// ABOUTME: Collects structured data (subject, description, steps, expected behavior)
// ABOUTME: Submits directly to Zendesk REST API with custom fields

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/bug_report/bug_report_cubit.dart';
import 'package:openvine/blocs/bug_report/bug_report_state.dart';
import 'package:openvine/config/bug_report_config.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/settings/support_center_screen.dart';
import 'package:openvine/services/bug_report_log_summary.dart';
import 'package:openvine/services/bug_report_service.dart';
import 'package:openvine/services/zendesk_support_service.dart';
import 'package:openvine/widgets/image_attachment_picker.dart';
import 'package:openvine/widgets/support_capped_text_field.dart';
import 'package:openvine/widgets/support_form_actions.dart';
import 'package:openvine/widgets/support_form_fields.dart';
import 'package:openvine/widgets/support_public_submission_notice.dart';

/// Route for collecting and submitting bug reports.
class BugReportScreen extends StatefulWidget {
  const BugReportScreen({
    required this.bugReportService,
    super.key,
    this.currentScreen,
    this.recentScreens = const [],
    this.userPubkey,
    this.submitBugReport,
    this.buildLogsSummary = buildLogsSummaryOffMain,
  });

  static const routeName = 'support-report-bug';
  static const String path = RoutePaths.supportReportBug;

  final BugReportService bugReportService;
  final String? currentScreen;
  final List<String> recentScreens;
  final String? userPubkey;
  final SubmitBugReportAction? submitBugReport;
  final BuildLogsSummary buildLogsSummary;

  @override
  State<BugReportScreen> createState() => _BugReportScreenState();
}

class _BugReportScreenState extends State<BugReportScreen> {
  final _fields = BugReportFields();

  @override
  void dispose() {
    _fields.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BugReportCubit(
        bugReportService: widget.bugReportService,
        buildLogsSummary: widget.buildLogsSummary,
        submitBugReport:
            widget.submitBugReport ??
            ZendeskSupportService.createStructuredBugReport,
      ),
      child: _BugReportView(
        fields: _fields,
        currentScreen: widget.currentScreen,
        recentScreens: widget.recentScreens,
        userPubkey: widget.userPubkey,
      ),
    );
  }
}

/// Form state for the bug report flow.
@visibleForTesting
class BugReportFields extends SupportFormFields {
  final steps = TextEditingController();
  final expected = TextEditingController();

  /// Plain field rather than a notifier: only `submit` reads it, and it reads
  /// it once, at the moment the button is tapped.
  List<XFile> attachments = const [];

  @override
  void dispose() {
    steps.dispose();
    expected.dispose();
    super.dispose();
  }
}

class _BugReportView extends StatelessWidget {
  const _BugReportView({
    required this.fields,
    this.currentScreen,
    this.recentScreens = const [],
    this.userPubkey,
  });

  final BugReportFields fields;
  final String? currentScreen;
  final List<String> recentScreens;
  final String? userPubkey;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isSubmitting = context.select(
      (BugReportCubit cubit) =>
          cubit.state.status == BugReportStatus.submitting,
    );

    return Scaffold(
      appBar: DiVineAppBar(
        title: l10n.supportReportBug,
        showBackButton: true,
        // safePop: this screen has a registered path, so the back stack
        // can be empty on a cold entry and a raw pop would throw GoError.
        onBackPressed: () =>
            context.safePop(fallback: SupportCenterScreen.path),
      ),
      backgroundColor: context.vineColors.background,
      body: Column(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 16,
                    children: [
                      const SupportPublicSubmissionNotice(),
                      SupportCappedTextField(
                        maxLength: BugReportConfig.maxSubjectLength,
                        controller: fields.subject,
                        labelText: l10n.supportSubjectRequiredLabel,
                        hintText: l10n.bugReportSubjectHint,
                        helperText: l10n.supportRequiredHelper,
                        imageInsertionNotice:
                            l10n.bugReportImageInsertionRejected,
                        enabled: !isSubmitting,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) =>
                            fields.descriptionFocus.requestFocus(),
                      ),
                      SupportCappedTextField(
                        maxLength: BugReportConfig.maxFreeTextFieldLength,
                        controller: fields.description,
                        focusNode: fields.descriptionFocus,
                        labelText: l10n.bugReportDescriptionRequiredLabel,
                        hintText: l10n.bugReportDescriptionHint,
                        helperText: l10n.supportRequiredHelper,
                        imageInsertionNotice:
                            l10n.bugReportImageInsertionRejected,
                        enabled: !isSubmitting,
                        minLines: 3,
                        maxLines: 5,
                        keyboardType: TextInputType.multiline,
                      ),
                      SupportCappedTextField(
                        maxLength: BugReportConfig.maxFreeTextFieldLength,
                        controller: fields.steps,
                        labelText: l10n.bugReportStepsLabel,
                        hintText: l10n.bugReportStepsHint,
                        imageInsertionNotice:
                            l10n.bugReportImageInsertionRejected,
                        enabled: !isSubmitting,
                        minLines: 3,
                        maxLines: 5,
                        keyboardType: TextInputType.multiline,
                      ),
                      SupportCappedTextField(
                        maxLength: BugReportConfig.maxFreeTextFieldLength,
                        controller: fields.expected,
                        labelText: l10n.bugReportExpectedBehaviorLabel,
                        hintText: l10n.bugReportExpectedBehaviorHint,
                        imageInsertionNotice:
                            l10n.bugReportImageInsertionRejected,
                        enabled: !isSubmitting,
                        minLines: 2,
                        maxLines: 4,
                        keyboardType: TextInputType.multiline,
                      ),
                      ImageAttachmentPicker(
                        enabled: !isSubmitting,
                        onChanged: (files) => fields.attachments = files,
                      ),
                      Text(
                        l10n.bugReportDiagnosticsNotice,
                        style: VineTheme.bodySmallFont(
                          color: context.vineColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Divider(height: 2, color: context.vineColors.outlineDisabled),
          SafeArea(
            top: false,
            child: BugReportActions(
              fields: fields,
              currentScreen: currentScreen,
              recentScreens: recentScreens,
              userPubkey: userPubkey,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pinned footer of the bug report flow: failure banner plus actions.
@visibleForTesting
class BugReportActions extends StatelessWidget {
  const BugReportActions({
    required this.fields,
    this.currentScreen,
    this.recentScreens = const [],
    this.userPubkey,
    super.key,
  });

  final BugReportFields fields;
  final String? currentScreen;
  final List<String> recentScreens;
  final String? userPubkey;

  String _failureMessage(BugReportFailureKey? key, BuildContext context) {
    return switch (key) {
      BugReportFailureKey.attachmentUpload =>
        context.l10n.bugReportUploadFailed,
      BugReportFailureKey.generic || null => context.l10n.bugReportSendFailed,
    };
  }

  void _submit(BuildContext context, BugReportFields fields) {
    context.read<BugReportCubit>().submit(
      subject: fields.subject.text,
      description: fields.description.text,
      stepsToReproduce: fields.steps.text,
      expectedBehavior: fields.expected.text,
      attachments: fields.attachments,
      currentScreen: currentScreen,
      recentScreens: recentScreens,
      userPubkey: userPubkey,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BugReportCubit, BugReportState>(
      listenWhen: (prev, curr) =>
          prev.status != curr.status && curr.status == BugReportStatus.success,
      listener: (context, _) => closeSupportFlowWithConfirmation(
        context,
        message: context.l10n.bugReportSuccessMessage,
      ),
      builder: (context, state) => SupportFormActions(
        fields: fields,
        sendLabel: context.l10n.bugReportSendReport,
        isSubmitting: state.status == BugReportStatus.submitting,
        failureMessage: state.status == BugReportStatus.failure
            ? _failureMessage(state.failureKey, context)
            : null,
        onSubmit: () => _submit(context, fields),
      ),
    );
  }
}
