class Coordinates{
  final double latitude, longitude;
  Coordinates(this.latitude, this.longitude){
    if (latitude.abs() > 90 || longitude.abs() > 180){
      throw ArgumentError("Latitude ($latitude) and longitude ($longitude) must be in [-90;90] and [-180;180] respectively!");
    }
  }

  @override
  String toString(){
    return "lat: $latitude, long: $longitude";
  }
}

class Paper{
  final PaperSize size;
  final PaperOrientation orientation;

  Paper(this.size, this.orientation);
}

enum PaperSize{
  a0(longSide: 1189, shortSide: 841),
  a1(longSide: 841, shortSide: 594),
  a2(longSide: 594, shortSide: 420),
  a3(longSide: 420, shortSide: 297),
  a4(longSide: 297, shortSide: 210),
  a5(longSide: 210, shortSide: 148),
  a6(longSide: 148, shortSide: 105);

  final int longSide, shortSide; //unit is mm

  const PaperSize({
    required this.longSide,
    required this.shortSide
  });
}

enum PaperOrientation{
  portrait, landscape
}