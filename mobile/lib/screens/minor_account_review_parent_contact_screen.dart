// ABOUTME: Parent-contact submission screen for 13-15 minor-account review
// ABOUTME: cases. Sends a parent or guardian email to the backend.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/minor_account_review_screen.dart';
import 'package:openvine/screens/minor_account_review_under13_support_screen.dart';
import 'package:openvine/utils/validators.dart';
import 'package:unified_logger/unified_logger.dart';

class MinorAccountReviewParentContactScreen extends ConsumerStatefulWidget {
  static const routeName = 'minor-account-review-parent-contact';
  static const path = '/account-review/parent-contact';

  const MinorAccountReviewParentContactScreen({super.key});

  @override
  ConsumerState<MinorAccountReviewParentContactScreen> createState() =>
      _MinorAccountReviewParentContactScreenState();
}

class _MinorAccountReviewParentContactScreenState
    extends ConsumerState<MinorAccountReviewParentContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isSubmitting = false;
  String? _submittedEmail;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(currentMinorAccountReviewStatusProvider);

    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.minorAccountReviewParentContactTitle,
        showBackButton: true,
        onBackPressed: () =>
            context.safePop(fallback: MinorAccountReviewScreen.path),
      ),
      backgroundColor: context.vineColors.background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: statusAsync.when(
              loading: () =>
                  const Center(child: PartialCircleSpinner(progress: 0.33)),
              error: (error, _) {
                Log.error(
                  'Failed to load parent-contact review state: $error',
                  name: 'MinorAccountReviewParentContactScreen',
                  category: LogCategory.ui,
                );
                return _ParentContactLoadErrorView(
                  onRetry: () =>
                      ref.invalidate(currentMinorAccountReviewStatusProvider),
                );
              },
              data: (status) => _ParentContactBody(
                status: status,
                isSubmitting: _isSubmitting,
                formKey: _formKey,
                emailController: _emailController,
                errorMessage: _errorMessage,
                submittedEmail: _submittedEmail,
                onSubmit: _submit,
                onCheckAgain: () =>
                    ref.invalidate(currentMinorAccountReviewStatusProvider),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(MinorReviewCase reviewCase) async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      if (kDebugMode) {
        final overrideService = ref.read(
          minorAccountReviewOverrideServiceProvider,
        );
        final localOverride = overrideService.getOverride();
        if (localOverride?.currentCase?.id == reviewCase.id) {
          await overrideService.setOverride(
            localOverride!.copyWith(
              currentCase: localOverride.currentCase!.copyWith(
                state: MinorReviewCaseState.submittedForReview,
                instructions: MinorReviewInstructions(
                  title: context.l10n.minorAccountReviewSubmissionReceivedTitle,
                  body: context
                      .l10n
                      .minorAccountReviewSubmissionReceivedLocalBody,
                ),
              ),
            ),
          );
        } else {
          await ref
              .read(minorAccountReviewRepositoryProvider)
              .submitParentContact(caseId: reviewCase.id, email: email);
        }
      } else {
        await ref
            .read(minorAccountReviewRepositoryProvider)
            .submitParentContact(caseId: reviewCase.id, email: email);
      }
      ref.invalidate(currentMinorAccountReviewStatusProvider);
      if (!mounted) return;
      setState(() {
        _submittedEmail = email;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = context.l10n.minorAccountReviewParentContactError;
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

class _ParentContactBody extends StatelessWidget {
  const _ParentContactBody({
    required this.status,
    required this.isSubmitting,
    required this.formKey,
    required this.emailController,
    required this.errorMessage,
    required this.submittedEmail,
    required this.onSubmit,
    required this.onCheckAgain,
  });

  final MinorAccountReviewStatus status;
  final bool isSubmitting;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final String? errorMessage;
  final String? submittedEmail;
  final Future<void> Function(MinorReviewCase reviewCase) onSubmit;
  final VoidCallback onCheckAgain;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final validationMessages = AuthValidationMessages.fromL10n(l10n);
    final reviewCase = status.currentCase;
    if (reviewCase == null) {
      return const _MissingCaseView();
    }
    if (!reviewCase.allowsParentVideoOrEmail) {
      return const _UnsupportedCaseView();
    }

    if (submittedEmail != null) {
      return _SuccessView(email: submittedEmail!, onCheckAgain: onCheckAgain);
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.minorAccountReviewParentContactHeading,
                style: VineTheme.headlineMediumFont(
                  color: context.vineColors.primaryText,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.minorAccountReviewParentContactBody(reviewCase.id),
                style: VineTheme.bodyMediumFont(
                  color: context.vineColors.mutedText,
                ),
              ),
              const SizedBox(height: 24),
              DivineAuthTextField(
                label: l10n.minorAccountReviewParentContactFieldLabel,
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                validator: (value) => Validators.validateEmail(
                  value,
                  messages: validationMessages,
                ),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  errorMessage!,
                  style: VineTheme.bodyMediumFont(color: VineTheme.error),
                ),
              ],
              const SizedBox(height: 24),
              DivineButton(
                label: isSubmitting
                    ? l10n.minorAccountReviewSubmitting
                    : l10n.minorAccountReviewSubmitEmail,
                expanded: true,
                onPressed: isSubmitting ? null : () => onSubmit(reviewCase),
              ),
              const SizedBox(height: 12),
              DivineButton(
                label: l10n.minorAccountReviewBackToReview,
                type: DivineButtonType.secondary,
                expanded: true,
                onPressed: isSubmitting
                    ? null
                    : () => context.safePop(
                        fallback: MinorAccountReviewScreen.path,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.email, required this.onCheckAgain});

  final String email;
  final VoidCallback onCheckAgain;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.minorAccountReviewSubmissionReceivedTitle,
            style: VineTheme.headlineMediumFont(
              color: context.vineColors.primaryText,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.minorAccountReviewSubmissionReceivedBody(email),
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.mutedText,
            ),
          ),
          const SizedBox(height: 24),
          DivineButton(
            label: context.l10n.minorAccountReviewBackToReview,
            expanded: true,
            onPressed: () => context.go(MinorAccountReviewScreen.path),
          ),
          const SizedBox(height: 12),
          DivineButton(
            label: context.l10n.minorAccountReviewCheckAgain,
            type: DivineButtonType.secondary,
            expanded: true,
            onPressed: () {
              onCheckAgain();
              context.go(MinorAccountReviewScreen.path);
            },
          ),
        ],
      ),
    );
  }
}

class _MissingCaseView extends StatelessWidget {
  const _MissingCaseView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.minorAccountReviewMissingCase,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            DivineButton(
              label: context.l10n.minorAccountReviewBackToReview,
              expanded: true,
              onPressed: () => context.go(MinorAccountReviewScreen.path),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnsupportedCaseView extends StatelessWidget {
  const _UnsupportedCaseView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.minorAccountReviewUnder13SupportBody,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            DivineButton(
              label: context.l10n.minorAccountReviewBackToReview,
              expanded: true,
              onPressed: () =>
                  context.go(MinorAccountReviewUnder13SupportScreen.path),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParentContactLoadErrorView extends StatelessWidget {
  const _ParentContactLoadErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            context.l10n.minorAccountReviewErrorTitle,
            style: VineTheme.titleMediumFont(
              color: context.vineColors.primaryText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.minorAccountReviewErrorBody,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.secondaryText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          DivineButton(
            label: context.l10n.minorAccountReviewTryAgain,
            expanded: true,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
