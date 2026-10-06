import 'package:flutter/material.dart';

import 'package:the_audit/core/utils/theme.dart';

/// Numbered step indicator (1 — 2 — 3): done steps are filled with a tick,
/// the current step is filled with its number, upcoming steps are outlined.
class StepIndicator extends StatelessWidget {
  final int current;
  final int count;

  /// Called with a step's index when it's tapped; null = not tappable.
  final ValueChanged<int>? onStepTap;

  const StepIndicator({
    super.key,
    required this.current,
    required this.count,
    this.onStepTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: i <= current ? AppStepper.lineDone : AppStepper.lineTodo,
              ),
            ),
          Semantics(
            label: 'Step ${i + 1} of $count',
            selected: i == current,
            button: i < current,
            child: GestureDetector(
              onTap: onStepTap == null ? null : () => onStepTap!(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= current ? AppStepper.active : AppStepper.todoFill,
                  border: Border.all(
                    color: i <= current
                        ? AppStepper.active
                        : AppStepper.todoBorder,
                  ),
                  boxShadow: i == current
                      ? const [
                          BoxShadow(color: AppStepper.glow, blurRadius: 10),
                        ]
                      : null,
                ),
                child: i < current
                    ? const Icon(
                        Icons.check,
                        size: 18,
                        color: AppColors.snowWhite,
                      )
                    : Text(
                        '${i + 1}',
                        style: i == current
                            ? AppStepper.activeNumber
                            : AppStepper.todoNumber,
                      ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
