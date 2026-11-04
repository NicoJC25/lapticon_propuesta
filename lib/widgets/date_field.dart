import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import 'app_components.dart';

/// Campo de fecha validable que abre el calendario.
class DateField extends FormField<DateTime> {
  DateField(
      {super.key,
      required String label,
      required String hint,
      required DateTime firstDate,
      required DateTime lastDate,
      super.validator,
      super.enabled,
      ValueChanged<DateTime>? onChanged})
      : super(builder: (state) {
          Future<void> pick() async {
            final picked = await showDatePicker(
                context: state.context,
                initialDate: state.value ?? firstDate,
                firstDate: firstDate,
                lastDate: lastDate,
                helpText: label);
            if (picked != null && state.mounted) {
              state.didChange(picked);
              onChanged?.call(picked);
            }
          }

          return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FieldLabel(label),
                    Semantics(
                        button: true,
                        label: [
                          label,
                          state.value == null
                              ? hint
                              : formatDate(state.value!),
                          if (state.errorText != null) state.errorText!,
                        ].join('. '),
                        excludeSemantics: true,
                        child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: state.widget.enabled ? pick : null,
                            child: InputDecorator(
                                isEmpty: state.value == null,
                                decoration: InputDecoration(
                                    enabled: state.widget.enabled,
                                    hintText: hint,
                                    errorText: state.errorText,
                                    prefixIcon: const Icon(Icons.event_outlined,
                                        size: 19, color: AppColors.muted)),
                                child: state.value == null
                                    ? null
                                    : Text(formatDate(state.value!),
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: AppColors.ink))))),
                  ]));
        });
}
