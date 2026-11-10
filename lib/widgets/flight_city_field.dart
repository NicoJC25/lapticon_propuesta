import 'package:flutter/material.dart';
import '../data/flight_city.dart';

class FlightCityField extends StatelessWidget {
  const FlightCityField(
      {super.key,
      required this.label,
      required this.onChanged,
      this.value,
      this.validator,
      this.enabled = true});
  final String label;
  final FlightCity? value;
  final ValueChanged<FlightCity> onChanged;
  final FormFieldValidator<FlightCity>? validator;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<FlightCity>(
          value: value,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          hint: const Text('Selecciona una ciudad'),
          items: [
            for (final city in FlightCity.values)
              DropdownMenuItem(value: city, child: Text(city.label))
          ],
          validator: validator,
          onChanged: !enabled
              ? null
              : (city) {
                  if (city != null) onChanged(city);
                }));
}
