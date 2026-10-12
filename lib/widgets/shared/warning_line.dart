import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

/// One consequence in a destructive-action dialog, with a warning icon.
/// Used wherever a delete must spell out what it takes with it.
class WarningLine extends StatelessWidget {
  final String text;
  const WarningLine(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2, right: 8),
              child: Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: AppColors.missedRed,
              ),
            ),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: AppColors.missedRed,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}
