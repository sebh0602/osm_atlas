import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:image/image.dart' as img_lib;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:osm_atlas/osm_atlas_configuration.dart';

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

class Tile{
  final Uint8List bytes;
  final TileCoordinates tileCoordinates;
  img_lib.Image? image;
  
  Tile(this.tileCoordinates, this.bytes){
    image = img_lib.decodePng(bytes);
    
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

class Page{
  final int pageNumber, xCoordinate, yCoordinate;
  final Boundary boundary;
  final AtlasConfiguration config;
  final PDFDocument pdf;
  int? _tileSize;
  img_lib.Image? _pageImage;
  Page(this.pageNumber,this.xCoordinate,this.yCoordinate,this.boundary,this.config,this.pdf);

  Future<void> build() async{
    _pageImage = await createPageImage();

    final page = pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Center(
          child: pw.Text("Page Nr. $pageNumber"),
        ); // Center
      }
    );

    pdf.addPage(page, pageNumber);
  }

  Future<img_lib.Image> createPageImage() async{
    final nwCorner = Coordinates(boundary.north, boundary.west).toTileCoordinates(config.zoomLevel);
    final seCorner = Coordinates(boundary.south, boundary.east).toTileCoordinates(config.zoomLevel);
    final xTiles = seCorner.x-nwCorner.x+1;
    final yTiles = seCorner.y-nwCorner.y+1;

    var sample = await config.tileProvider.getTileTC(nwCorner);
    if (sample.image == null){
      throw Exception("Image is null!");
    }
    _tileSize = sample.image!.width;
    final pageImageWidth = _tileSize!*xTiles;
    final pageImageHeight = _tileSize!*yTiles;
    var pageImage = img_lib.Image(pageImageWidth,pageImageHeight);
    for (int x = 0; x<xTiles; x++){
      for (int y = 0; y<yTiles; y++){
        var tile = await config.tileProvider.getTileTC(TileCoordinates(nwCorner.x+x, nwCorner.y+y, config.zoomLevel));
        if (tile.image == null){
          throw Error();
        }
        pageImage = img_lib.copyInto(pageImage, tile.image!, dstX: _tileSize!*x, dstY: _tileSize!*y);
      }
    }
    final topLeftPixel = nwCorner.getPixelCoordinates(Coordinates(boundary.north, boundary.west), _tileSize!);
    final bottomRightPixel = seCorner.getPixelCoordinates(Coordinates(boundary.south, boundary.east), _tileSize!);
    pageImage = img_lib.copyCrop(pageImage, topLeftPixel.x, topLeftPixel.y, _tileSize!*(xTiles-1) + bottomRightPixel.x-topLeftPixel.x, _tileSize!*(yTiles-1) +bottomRightPixel.y-topLeftPixel.y);
    return pageImage;
    //final bytes = img_lib.encodePng(pageImage);
    //final path = "pages/$pageNumber.png";
    //await File(path).create(recursive: true);
	  //await File(path).writeAsBytes(bytes);
  }
}

class PDFDocument{
  final pdf = pw.Document();
  final List<pw.Page?> pages;
  final int documentLength;
  final AtlasConfiguration config;
  var _addedPages = 0;
  PDFDocument(this.pages,this.documentLength,this.config);

  void addPage(pw.Page page, int number){
    pages[number-1] = page;
    _addedPages++;
    if (_addedPages == documentLength){
      _createDocument();
    }
  }

  void _createDocument() async{
    print("Saving pdf...");
    for (int i = 0; i<documentLength; i++){
      if (pages[i] != null){
        pdf.addPage(pages[i]!);
      }
    }
    final file = File("${config.outputPath}/atlas.pdf");
    await file.writeAsBytes(await pdf.save());
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
