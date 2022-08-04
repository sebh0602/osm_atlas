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

  Boundary get boundary{
    final neighbour = TileCoordinates(x+1, y+1, z);
    final nwCorner = toStandardCoordinates();
    final seCorner = neighbour.toStandardCoordinates();
    return Boundary(nwCorner.latitude, seCorner.latitude, seCorner.longitude, nwCorner.longitude);
  }

  PixelCoordinates getPixelCoordinates(Coordinates coords, int size){
    if (!boundary.contains(coords)){
      throw Exception("Coordinates not in boundary!");
    }
    final x = (coords.longitude-boundary.west)/boundary.degWidth;
    final y = (boundary.north-coords.latitude)/boundary.degHeight;
    return PixelCoordinates((x*size).floor(), (y*size).floor());
  }

  double _sinh(double x){
    return (math.exp(x) - math.exp(-x))/2;
  }
}

class PixelCoordinates{
  final int x,y;
  PixelCoordinates(this.x,this.y);

  @override
  String toString(){
    return "x: $x, y: $y";
  }
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

  double get degWidth{
    return east-west;
  }

  //in meters
  double get height{
    final meridian = 20003930; //m
    final heightDeg = north-south;
    return meridian*heightDeg/180;
  }

  double get degHeight{
    return north-south;
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

  bool contains(Coordinates coords){
    if (coords.latitude > north || coords.latitude < south){
      return false;
    } else if (coords.longitude > east || coords.longitude < west){
      return false;
    } else{
      return true;
    }
  }
}

enum Direction{
  left,right,top,bottom
}