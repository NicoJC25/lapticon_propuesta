import 'shipment_repository.dart';

/// Ciudades habilitadas para vuelos. Cada ciudad usa un aeropuerto concreto.
enum FlightCity {
  bogota('Bogotá', 'BOG', 'Colombia'),
  medellin('Medellín', 'MDE', 'Colombia'),
  cali('Cali', 'CLO', 'Colombia'),
  newYork('New York', 'JFK', 'Estados Unidos'),
  miami('Miami', 'MIA', 'Estados Unidos'),
  washington('Washington', 'IAD', 'Estados Unidos');

  const FlightCity(this.label, this.iata, this.country);
  final String label, iata, country;
  Place get place => Place(city: label, country: country);
  static FlightCity? fromPlace(Place? place) {
    for (final city in values) {
      if (city.place == place) return city;
    }
    return null;
  }
}
