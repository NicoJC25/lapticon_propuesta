import 'package:flutter/widgets.dart';

/// Alcance visible de la evaluación. Los módulos excluidos conservan su código.
class EvaluationFeatures extends InheritedWidget {
  const EvaluationFeatures(
      {super.key,
      this.chat = false,
      this.google = false,
      required super.child});
  final bool chat, google;
  static bool chatVisible(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EvaluationFeatures>()?.chat ??
      false;
  static bool googleVisible(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<EvaluationFeatures>()
          ?.google ??
      false;
  @override
  bool updateShouldNotify(EvaluationFeatures oldWidget) =>
      chat != oldWidget.chat || google != oldWidget.google;
}
