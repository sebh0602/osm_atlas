import 'dart:typed_data';
import 'dart:math' as math;

class Coordinates{
  final double latitude, longitude;
  Coordinates(this.latitude, this.longitude){
    if (latitude.abs() > 85 || longitude.abs() > 180){
      throw ArgumentError("Latitude ($latitude) and longitude ($longitude) must be in [-85;85] and [-180;180] respectively!");
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

class Tile{
  final Uint8List bytes;
  final TileCoordinates tileCoordinates;
  Tile(this.tileCoordinates, this.bytes);
}

class Boundary{
  final double north, south, east, west;
  Boundary(this.north,this.south,this.east,this.west){
    if (north.abs() > 85 || south.abs()>85 || east.abs() > 180 || west.abs() > 180){
      throw ArgumentError("Latitude ($north/$south) and longitude ($east/$west) must be in [-85;85] and [-180;180] respectively!");
    } else if (north<south || east<west){
      throw ArgumentError("You mixed up North/South or East/West!");
    }
  }

  //in meters
  double get width{
    final equator = 40075016.686; //m
    final widthDeg = east-west;
    return equator*widthDeg/360*math.cos(0.5*(north+south)*math.pi/180);
  }

  //in meters
  double get height{
    final meridian = 20003930; //m
    final heightDeg = north-south;
    return meridian*heightDeg/180;
  }

  Coordinates get center{
    return Coordinates((north+south)/2, (east+west)/2);
  }

  Boundary stretch(double x, double y){
    var newNorth = (north - center.latitude)*y + center.latitude;
    var newSouth = (south - center.latitude)*y + center.latitude;
    var newEast = (east - center.longitude)*x + center.longitude;
    var newWest = (west - center.longitude)*x + center.longitude;
    return Boundary(newNorth, newSouth, newEast, newWest);
  }

  Boundary section(int x, int xCount, int y, int yCount){
    final heightDeg = north-south;
    final widthDeg = east-west;
    final pageHeightDeg = heightDeg/yCount;
    final pageWidthDeg = widthDeg/xCount;
    
    var newNorth = north-pageHeightDeg*y;
    var newSouth = north-pageHeightDeg*(y+1);
    var newEast = west+pageWidthDeg*(x+1);
    var newWest = west+pageWidthDeg*x;
    return Boundary(newNorth, newSouth, newEast, newWest);
  }
}

class Page{
  final int pageNumber, xCoordinate, yCoordinate;
  final Boundary boundary;
  Page(this.pageNumber,this.xCoordinate,this.yCoordinate,this.boundary);

  Future<void> build() async{
    
  }
}

class Paper{
  final PaperSize size;
  final PaperOrientation orientation;
  final int margin, overlap;

  Paper(this.size, this.orientation, this.margin, this.overlap);

  int get width{
    if (orientation == PaperOrientation.landscape){
      return size.longSide;
    } else {
      return size.shortSide;
    }
  }

  int get printableWidth{
    return width - 2*margin;
  }

  int get nonOverlappingWidth{
    return printableWidth - 2*overlap;
  }

  int get height{
    if (orientation == PaperOrientation.landscape){
      return size.shortSide;
    } else {
      return size.longSide;
    }
  }

  int get printableHeight{
    return height - 2*margin;
  }

  int get nonOverlappingHeight{
    return printableHeight - 2*overlap;
  }
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
