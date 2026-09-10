import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

class ErrorMessage extends StatelessWidget {
  final String? message;

  const ErrorMessage({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VineTheme.error,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VineTheme.error),
      ),
      child: Row(
        children: [
          DivineIcon(
            icon: DivineIconName.warningCircle,
            color: context.vineColors.primaryText,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message!,
              style: TextStyle(
                color: context.vineColors.primaryText,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
