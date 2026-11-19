import 'shipment_repository.dart';

/// Ciudades habilitadas para vuelos. Cada ciudad usa un aeropuerto concreto.
enum FlightCity {
  bogota('Bogotá', 'BOG', 'Colombia', ['Bogota']),
  medellin('Medellín', 'MDE', 'Colombia', ['Medellin', 'Rionegro']),
  cali('Cali', 'CLO', 'Colombia', ['Santiago de Cali']),
  newYork('New York', 'JFK', 'Estados Unidos', ['New York City']),
  miami('Miami', 'MIA', 'Estados Unidos'),
  washington('Washington', 'IAD', 'Estados Unidos', ['Dulles']);

  const FlightCity(this.label, this.iata, this.country,
      [this.aliases = const []]);
  final String label, iata, country;

  /// Nombres antiguos del catálogo o del municipio del aeropuerto.
  final List<String> aliases;
  Place get place => Place(city: label, country: country);
  static FlightCity? fromIata(String code) {
    for (final city in values) {
      if (city.iata == code.trim().toUpperCase()) return city;
    }
    return null;
  }

  static FlightCity? fromName(String name) {
    final key = name.trim().toLowerCase();
    for (final city in values) {
      if ([city.label, ...city.aliases]
          .any((value) => value.toLowerCase() == key)) {
        return city;
      }
    }
    return null;
  }

  static String canonicalName(String name) =>
      fromName(name)?.label ?? name.trim();

  /// La búsqueda del backend compara texto exacto. Consultar las variantes
  /// conocidas permite recuperar registros anteriores sin reescribirlos.
  static Set<String> searchNames(String name) {
    final city = fromName(name);
    return {
      name.trim(),
      if (city != null) ...[city.label, ...city.aliases]
    };
  }

  static FlightCity? fromPlace(Place? place) {
    for (final city in values) {
      if (city.place == place) return city;
    }
    return null;
  }
}
