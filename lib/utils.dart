import 'dart:typed_data';
import 'dart:math' as math;

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

  TileCoordinates toTileCoordinates(int zoom){
    final x = ((longitude + 180)/360 * math.pow(2, zoom)).floor();
    final y = (
      (
        1
        -
        math.log(
          math.tan(latitude*math.pi/180) + 1 / math.cos(latitude*math.pi/180)
        )
        /
        math.pi
      )
      *
      math.pow(2, zoom-1)
    ).floor();
    return TileCoordinates(x, y, zoom);
  }
}

class TileCoordinates{
  final int x,y,z;
  TileCoordinates(this.x,this.y,this.z);

  //Coordinates of upper left / north west corner
  Coordinates toStandardCoordinates(){
    final longitude = x*360/math.pow(2, z) - 180;
    final latitude = math.atan(_sinh(math.pi-2*math.pi*y/math.pow(2, z))) * 180/math.pi;
    return Coordinates(latitude, longitude);
  }

  //size in meters
  double get tileSize{
    final equator = 40075016.686; //m
    return equator/math.pow(2, z)*math.cos(toStandardCoordinates().latitude*math.pi/180);
  }

  double _sinh(double x){
    return (math.exp(x) - math.exp(-x))/2;
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

class Tile{
  final Uint8List bytes;
  final TileCoordinates tileCoordinates;
  Tile(this.tileCoordinates, this.bytes);
}