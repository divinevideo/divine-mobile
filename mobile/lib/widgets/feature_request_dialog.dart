// ABOUTME: Full-screen flow for submitting feature requests to Zendesk
// ABOUTME: Collects structured data (subject, description, usefulness, when to use)
// ABOUTME: Submits directly to Zendesk via SDK or REST API with custom fields

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/feature_request/feature_request_cubit.dart';
import 'package:openvine/blocs/feature_request/feature_request_state.dart';
import 'package:openvine/config/bug_report_config.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/settings/support_center_screen.dart';
import 'package:openvine/widgets/support_capped_text_field.dart';
import 'package:openvine/widgets/support_form_actions.dart';
import 'package:openvine/widgets/support_form_fields.dart';
import 'package:openvine/widgets/support_public_submission_notice.dart';

/// Route for collecting and submitting feature requests.
class FeatureRequestScreen extends StatefulWidget {
  const FeatureRequestScreen({
    super.key,
    this.userPubkey,
    this.submitFeatureRequest,
  });

  static const routeName = 'support-request-feature';
  static const path = '/support-center/request-feature';

  final String? userPubkey;
  final SubmitFeatureRequestAction? submitFeatureRequest;

  @override
  State<FeatureRequestScreen> createState() => _FeatureRequestScreenState();
}

class _FeatureRequestScreenState extends State<FeatureRequestScreen> {
  final _fields = FeatureRequestFields();

  @override
  void dispose() {
    _fields.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => widget.submitFeatureRequest == null
          ? FeatureRequestCubit()
          : FeatureRequestCubit(
              submitFeatureRequest: widget.submitFeatureRequest!,
            ),
      child: _FeatureRequestView(
        fields: _fields,
        userPubkey: widget.userPubkey,
      ),
    );
  }
}

/// Form state for the feature request flow.
@visibleForTesting
class FeatureRequestFields extends SupportFormFields {
  final usefulness = TextEditingController();
  final whenToUse = TextEditingController();

  @override
  void dispose() {
    usefulness.dispose();
    whenToUse.dispose();
    super.dispose();
  }
}

class _FeatureRequestView extends StatelessWidget {
  const _FeatureRequestView({required this.fields, this.userPubkey});

  final FeatureRequestFields fields;
  final String? userPubkey;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isSubmitting = context.select(
      (FeatureRequestCubit cubit) =>
          cubit.state.status == FeatureRequestStatus.submitting,
    );

    return Scaffold(
      appBar: DiVineAppBar(
        title: l10n.supportRequestFeature,
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
                        hintText: l10n.featureRequestSubjectHint,
                        helperText: l10n.supportRequiredHelper,
                        imageInsertionNotice:
                            l10n.featureRequestImageInsertionRejected,
                        enabled: !isSubmitting,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) =>
                            fields.descriptionFocus.requestFocus(),
                      ),
                      SupportCappedTextField(
                        maxLength: BugReportConfig.maxFreeTextFieldLength,
                        controller: fields.description,
                        focusNode: fields.descriptionFocus,
                        labelText: l10n.featureRequestDescriptionRequiredLabel,
                        hintText: l10n.featureRequestDescriptionHint,
                        helperText: l10n.supportRequiredHelper,
                        imageInsertionNotice:
                            l10n.featureRequestImageInsertionRejected,
                        enabled: !isSubmitting,
                        minLines: 3,
                        maxLines: 5,
                        keyboardType: TextInputType.multiline,
                      ),
                      SupportCappedTextField(
                        maxLength: BugReportConfig.maxFreeTextFieldLength,
                        controller: fields.usefulness,
                        labelText: l10n.featureRequestUsefulnessLabel,
                        hintText: l10n.featureRequestUsefulnessHint,
                        imageInsertionNotice:
                            l10n.featureRequestImageInsertionRejected,
                        enabled: !isSubmitting,
                        minLines: 3,
                        maxLines: 5,
                        keyboardType: TextInputType.multiline,
                      ),
                      SupportCappedTextField(
                        maxLength: BugReportConfig.maxFreeTextFieldLength,
                        controller: fields.whenToUse,
                        labelText: l10n.featureRequestWhenLabel,
                        hintText: l10n.featureRequestWhenHint,
                        imageInsertionNotice:
                            l10n.featureRequestImageInsertionRejected,
                        enabled: !isSubmitting,
                        minLines: 2,
                        maxLines: 4,
                        keyboardType: TextInputType.multiline,
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
            child: FeatureRequestActions(
              fields: fields,
              userPubkey: userPubkey,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pinned footer of the feature request flow: failure banner plus actions.
@visibleForTesting
class FeatureRequestActions extends StatelessWidget {
  const FeatureRequestActions({
    required this.fields,
    this.userPubkey,
    super.key,
  });

  final FeatureRequestFields fields;
  final String? userPubkey;

  void _submit(BuildContext context, FeatureRequestFields fields) {
    context.read<FeatureRequestCubit>().submit(
      subject: fields.subject.text,
      description: fields.description.text,
      usefulness: fields.usefulness.text,
      whenToUse: fields.whenToUse.text,
      userPubkey: userPubkey,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FeatureRequestCubit, FeatureRequestState>(
      listenWhen: (prev, curr) =>
          prev.status != curr.status &&
          curr.status == FeatureRequestStatus.success,
      listener: (context, _) => closeSupportFlowWithConfirmation(
        context,
        message: context.l10n.featureRequestSuccessMessage,
      ),
      builder: (context, state) => SupportFormActions(
        fields: fields,
        sendLabel: context.l10n.featureRequestSendRequest,
        isSubmitting: state.status == FeatureRequestStatus.submitting,
        failureMessage: state.status == FeatureRequestStatus.failure
            ? context.l10n.featureRequestSendFailed
            : null,
        onSubmit: () => _submit(context, fields),
      ),
    );
  }
}
