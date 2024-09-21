import 'package:flutter/material.dart';
import 'package:flutter_adaptive_scaffold/flutter_adaptive_scaffold.dart';

const Duration adaptiveLayoutTransitionDuration = Duration.zero;

class TwoPageLayout extends StatelessWidget {
  final Widget body;
  final Widget? secondaryBody;

  const TwoPageLayout({
    Key? key,
    required this.body,
    this.secondaryBody,
  }) : super(key: key ?? const ValueKey('TwoPageLayout'));

  @override
  Widget build(BuildContext context) {
    return AdaptiveLayout(
      transitionDuration: adaptiveLayoutTransitionDuration,
      body: SlotLayout(
        config: <Breakpoint, SlotLayoutConfig>{
          Breakpoints.small: SlotLayout.from(
            key: const Key('Body Small'),
            builder: (_) => secondaryBody != null ? secondaryBody! : body,
          ),
          Breakpoints.mediumAndUp: SlotLayout.from(
            key: const Key('Body Medium'),
            builder: (_) => body,
          )
        },
      ),
      secondaryBody: SlotLayout(
        config: <Breakpoint, SlotLayoutConfig>{
          Breakpoints.small: SlotLayout.from(
            key: const Key('Body Small'),
            builder: null,
          ),
          Breakpoints.mediumAndUp: SlotLayout.from(
            key: const Key('Body Medium'),
            builder: secondaryBody != null
                ? (_) => Row(
                  children: [
                    const VerticalDivider(width: 1),
                    Expanded(child: secondaryBody!),
                  ],
                )
                : null,
          )
        },
      ),
      bodyRatio: 0.3,
    );
  }
}