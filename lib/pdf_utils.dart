import 'dart:io';
import 'package:image/image.dart' as img_lib;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:osm_atlas/osm_atlas_configuration.dart';
import 'package:osm_atlas/coordinates.dart';

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
    await file.create(recursive: true);
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