import 'dart:io';
import 'package:image/image.dart' as img_lib;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:osm_atlas/atlas_configuration.dart';
import 'package:osm_atlas/coordinates.dart';

class Page{
  final int pageNumber;
  final Boundary boundary;
  final AtlasConfiguration config;
  final PDFDocument pdf;
  final PagePosition pagePosition;
  pw.Font? _font;
  int? _tileSize;
  img_lib.Image? _pageImage;
  Page(this.pageNumber,this.pagePosition,this.boundary,this.config,this.pdf);

  Future<void> build() async{
    _pageImage = await _createPageImage();
    final img =pw.Image(
      pw.ImageImage(_pageImage!),
      fit: pw.BoxFit.fill
      //width: config.paper.printableWidth*Paper.mm,
      //height: config.paper.printableHeight*Paper.mm
    );

    final fontFile = File(config.fontSource);
    if (await fontFile.exists()){
      _font = pw.Font.ttf((await fontFile.readAsBytes()).buffer.asByteData());
    } else {
      print("Warning: Font not found.");
    }    

    final page = pw.Page(
      pageFormat: config.paper.pdfFormat,
      orientation: config.paper.orientation.pdfOrientation,
      //margin: pw.EdgeInsets.all(config.paper.margin * Paper.mm),
      build:(context) {
        return pw.Stack(
          children: [
            img,
            //pw.Center(child: img),
            _getNeighbourLink(Direction.left),
            _getNeighbourLink(Direction.right),
            _getNeighbourLink(Direction.top),
            _getNeighbourLink(Direction.bottom)
          ]
        );
      },
    );

    pdf.addPage(page, pageNumber);
  }

  pw.Widget _getNeighbourLink(Direction dir){
    final width = 8*Paper.mm;
    final height = 5*Paper.mm;
    final neighbourNumber = pagePosition.getNeighbour(dir);
    if (neighbourNumber == null){
      return pw.Container(height: 0, width: 0);
    }
    
    var alignment = pw.Alignment.center;
    double? left,right,top,bottom;
    switch (dir){
      case Direction.left:
        left = 0;
        bottom = 50*Paper.mm;
        break;
      case Direction.right:
        right = 0;
        top = 50*Paper.mm;
        break;
      case Direction.top:
        top = 0;
        right = 50*Paper.mm;
        break;
      case Direction.bottom:
        bottom = 0;
        left = 50*Paper.mm;
        break;
    }
    return pw.Positioned(
      left: left,
      top: top,
      right:right,
      bottom: bottom,
      child: pw.UrlLink(
        destination: "#page=$neighbourNumber",
        child: pw.Container(
          decoration: pw.BoxDecoration(
            //color: PdfColor.fromHex("99EEFF"),
            color: PdfColor.fromHex("000000"),
          ),
          width: width,
          height: height,
          alignment: alignment,
          padding: pw.EdgeInsets.zero,
          margin: pw.EdgeInsets.zero,
          child: pw.Text(
            "0$neighbourNumber",
            tightBounds: true,
            style: pw.TextStyle(
              color: PdfColor.fromHex("FFFFFF"),
              fontSize: 12,
              font: _font
            )
          )
        )
      )
    );
  }

  Future<img_lib.Image> _createPageImage() async{
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
    final path = "${config.outputPath}/atlas.pdf";
    final file = File(path);
    await file.create(recursive: true);
    await file.writeAsBytes(await pdf.save());
    print("Done! Output saved to $path.");
  }
}

class PagePosition{
  final int width, height, x, y;
  final AtlasConfiguration config;
  PagePosition(this.width, this.height, this.x, this.y, this.config);

  int? get topNeighbour{
    if (y == 0){
      return null;
    } else{
      return width*(y-1) + x+1 + config.pageNumberOffset;
    }
  }

  int? get bottomNeighbour{
    if (y == height-1){
      return null;
    } else{
      return width*(y+1) + x+1 + config.pageNumberOffset;
    }
  }

  int? get rightNeighbour{
    if (x == width-1){
      return null;
    } else{
      return width*y + x+2 + config.pageNumberOffset;
    }
  }

  int? get leftNeighbour{
    if (x == 0){
      return null;
    } else{
      return width*y + x + config.pageNumberOffset;
    }
  }

  int? getNeighbour(Direction dir){
    switch (dir){
      case Direction.left:
        return leftNeighbour;
      case Direction.right:
        return rightNeighbour;
      case Direction.top:
        return topNeighbour;
      case Direction.bottom:
        return bottomNeighbour;
    }
  }
}

class Paper{
  final PaperSize size;
  final PaperOrientation orientation;
  final int margin, overlap;
  static final double mm = PdfPageFormat.mm;

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

  PdfPageFormat get pdfFormat{
    if (orientation == PaperOrientation.landscape){
      return PdfPageFormat(size.longSide*mm, size.shortSide*mm, marginAll: margin*mm);
    } else {
      return PdfPageFormat(size.shortSide*mm, size.longSide*mm, marginAll: margin*mm);
    }
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
    required this.shortSide,
  });
}

enum PaperOrientation{
  portrait(pw.PageOrientation.portrait),
  landscape(pw.PageOrientation.landscape);

  final pw.PageOrientation pdfOrientation;
  const PaperOrientation(this.pdfOrientation);
}