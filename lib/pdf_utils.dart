import 'dart:io';
import 'dart:math' as math;

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
  img_lib.Image? _pageImage;
  Page(this.pageNumber,this.pagePosition,this.boundary,this.config,this.pdf);

  Future<void> build() async{
    _pageImage = await createPageImage(boundary,config.zoomLevel,config);
    final img =pw.Image(
      pw.ImageImage(_pageImage!),
      fit: pw.BoxFit.fill
      //width: config.paper.printableWidth*Paper.mm,
      //height: config.paper.printableHeight*Paper.mm
    );

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
            _getNeighbourLink(Direction.bottom),
            _getPageNumber()
          ]
        );
      },
    );

    pdf.addPage(page, pageNumber);
  }

  pw.Widget _getNeighbourLink(Direction dir){
    final width = 8*Paper.mm;
    final height = 5*Paper.mm;
    var neighbourNumber = pagePosition.getNeighbour(dir);
    if (neighbourNumber == null){
      return pw.Container(height: 0, width: 0);
    }
    neighbourNumber += pdf.additionalOffset;
    
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
            _padNumber(neighbourNumber, pagePosition),
            tightBounds: true,
            style: pw.TextStyle(
              color: PdfColor.fromHex("FFFFFF"),
              fontSize: 11,
              font: config.font
            )
          )
        )
      )
    );
  }

  Direction get numberingSide{
    if (config.dontSwitchPageNumbering){
      return Direction.right;
    }
    if ((pageNumber + config.pageNumberOffset + pdf.additionalOffset) % 2 == 0){
      if (config.evenLeftNumbering){
        return Direction.left;
      } else {
        return Direction.right;
      }
    } else {
      if (config.evenLeftNumbering){
        return Direction.right;
      } else {
        return Direction.left;
      }
    }
  }

  pw.Widget _getPageNumber(){
    final width = 8*Paper.mm;
    final height = 5*Paper.mm;
    var alignment = pw.Alignment.center;

    double? left,right;
    final bottom = 0.0;
    if (numberingSide == Direction.left){
      left = 0;
    } else{
      right = 0;
    }

    final borderWidth = 1;
    final radiusSml = pw.Radius.circular(2*Paper.mm);
    final radiusLrg = pw.Radius.circular(2*Paper.mm + borderWidth);
    final borderRadiusSml = (numberingSide == Direction.left) ? pw.BorderRadius.only(topRight: radiusSml) : pw.BorderRadius.only(topLeft: radiusSml);
    final borderRadiusLrg = (numberingSide == Direction.left) ? pw.BorderRadius.only(topRight: radiusLrg) : pw.BorderRadius.only(topLeft: radiusLrg);

    return pw.Positioned(
      left: left,
      right:right,
      bottom: bottom,
      child: pw.Stack(
        alignment: (numberingSide == Direction.left) ? pw.Alignment.bottomLeft : pw.Alignment.bottomRight,
        children: [
          pw.Container(
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex("000000"),
              borderRadius: borderRadiusLrg
            ),
            width: width + borderWidth,
            height: height + borderWidth
          ),
          pw.Container(
            decoration: pw.BoxDecoration(
              //color: PdfColor.fromHex("99EEFF"),
              color: PdfColor.fromHex("FFFFFF"),
              borderRadius: borderRadiusSml
            ),
            width: width,
            height: height,
            alignment: alignment,
            padding: pw.EdgeInsets.zero,
            margin: pw.EdgeInsets.zero,
            child: pw.Text(
              _padNumber(pageNumber+config.pageNumberOffset + pdf.additionalOffset, pagePosition),
              tightBounds: true,
              style: pw.TextStyle(
                color: PdfColor.fromHex("000000"),
                fontSize: 11,
                font: config.font
              )
            )
          )
        ]
      )
    );
  }

  String _padNumber(int number, PagePosition pP){
    final maxLen = (pP.width*pP.height+config.pageNumberOffset+pdf.additionalOffset).toString().length;
    final ownLen = number.toString().length;
    return "0"*(maxLen-ownLen) + number.toString();
  }

  static Future<img_lib.Image> createPageImage(Boundary boundary, int zoomLevel, AtlasConfiguration config) async{
    final nwCorner = Coordinates(boundary.north, boundary.west).toTileCoordinates(zoomLevel);
    final seCorner = Coordinates(boundary.south, boundary.east).toTileCoordinates(zoomLevel);
    final xTiles = seCorner.x-nwCorner.x+1;
    final yTiles = seCorner.y-nwCorner.y+1;

    var sample = await config.tileProvider.getTileTC(nwCorner);
    if (sample.image == null){
      throw Exception("Image is null!");
    }
    final tileSize = sample.image!.width;
    final pageImageWidth = tileSize*xTiles;
    final pageImageHeight = tileSize*yTiles;
    var pageImage = img_lib.Image(pageImageWidth,pageImageHeight);
    for (int x = 0; x<xTiles; x++){
      for (int y = 0; y<yTiles; y++){
        var tile = await config.tileProvider.getTileTC(TileCoordinates(nwCorner.x+x, nwCorner.y+y, zoomLevel));
        if (tile.image == null){
          throw Error();
        }
        pageImage = img_lib.copyInto(pageImage, tile.image!, dstX: tileSize*x, dstY: tileSize*y);
      }
    }
    final topLeftPixel = nwCorner.boundary.getPixelCoordinates(Coordinates(boundary.north, boundary.west), tileSize, tileSize);
    final bottomRightPixel = seCorner.boundary.getPixelCoordinates(Coordinates(boundary.south, boundary.east), tileSize, tileSize);
    pageImage = img_lib.copyCrop(pageImage, topLeftPixel.x, topLeftPixel.y, tileSize*(xTiles-1) + bottomRightPixel.x-topLeftPixel.x, tileSize*(yTiles-1) +bottomRightPixel.y-topLeftPixel.y);
    return pageImage;
  }
}

class PDFDocument{
  final pdf = pw.Document();
  final List<pw.Page?> pages;
  final int additionalOffset,xPages,yPages;
  final Boundary overviewBoundary;
  final AtlasConfiguration config;
  var _addedPages = 0;
  PDFDocument(this.pages,this.additionalOffset,this.overviewBoundary,this.xPages,this.yPages, this.config);

  int get documentLength => xPages*yPages;

  void statusUpdate(){
    stdout.write("Pages completed: $_addedPages/$documentLength\r");
  }

  void addPage(pw.Page page, int number){
    pages[number-1] = page;
    _addedPages++;
    statusUpdate();
    if (_addedPages == documentLength){
      _createDocument();
    }
  }

  void _createDocument() async{
    print("Creating title and overview...");
    if (!config.omitTitlePage) pdf.addPage(_createTitlePage());
    if (config.addBlankPage) pdf.addPage(pw.Page(pageFormat: config.paper.pdfFormat, orientation: config.paper.orientation.pdfOrientation, build: (context) => pw.Container(width: 0,height: 0),));
    pdf.addPage(await _createOverview());
    if (!config.omitInnerPage) pdf.addPage(_createInnerPage());

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

  pw.Page _createTitlePage(){
    return pw.Page(
      pageFormat: config.paper.pdfFormat,
      orientation: config.paper.orientation.pdfOrientation,
      build: (context) {
        return pw.Stack(
          children: [
            pw.Positioned(
              left: 10*Paper.mm,
              right: 10*Paper.mm,
              top: config.paper.height*0.3*Paper.mm,
              child: pw.Text(
                config.title,
                style: pw.TextStyle(
                  font: config.font,
                  fontSize: 28
                ),
                textAlign: pw.TextAlign.center
              )
            ),
            pw.Positioned(
              left: 10*Paper.mm,
              right: 10*Paper.mm,
              bottom: 10*Paper.mm,
              child: pw.Text(
                config.subtitle,
                style: pw.TextStyle(
                  font: config.font,
                  fontSize: 10
                ),
                textAlign: pw.TextAlign.center
              )
            )
          ]
        );
      },
    );
  }

  pw.Page _createInnerPage(){
    return pw.Page(
      pageFormat: config.paper.pdfFormat,
      orientation: config.paper.orientation.pdfOrientation,
      build: (context) {
        return pw.Stack(
          children: [
            pw.Positioned(
              left: 20*Paper.mm,
              right: 20*Paper.mm,
              bottom: config.paper.height*0.1*Paper.mm,
              child: pw.Text(
                config.innerText,
                style: pw.TextStyle(
                  font: config.font,
                  fontSize: 10
                ),
                textAlign: pw.TextAlign.center
              )
            )
            //TODO: Add scale, physical scale, cm/m equivalence,
          ]
        );
      },
    );
  }

  Future<pw.Page> _createOverview() async{
    final stretchedBoundary = overviewBoundary.stretch(1.1, 1.1);
    var overviewImage = await Page.createPageImage(stretchedBoundary,config.overviewZoomLevel, config);
    
    final thickness = math.max(0.003*math.max(overviewImage.width, overviewImage.height),3).floor();
    List<int> fontBytes = await File(config.fntFontSource).readAsBytes();
    final font = img_lib.BitmapFont.fromZip(fontBytes);
    font.size = 2;
    final color = img_lib.Color.fromRgb(0, 0, 0);

    for (int x = 0; x<xPages; x++){
      for (int y = 0; y<yPages; y++){
        var pageBoundary = overviewBoundary.section(x, xPages, y, yPages);
        pageBoundary.draw(overviewImage, stretchedBoundary, color, thickness);

        final pageNumber = additionalOffset + config.pageNumberOffset + xPages*y + x + 1;
        var text = "$pageNumber";

        var i = img_lib.Image(190,160);
        img_lib.fill(i, img_lib.Color.fromRgb(255, 255, 255));
        img_lib.drawStringCentered(i, font, text);
        i = img_lib.copyCrop(i, 0, 40, 190, 100);
        i = img_lib.copyResize(i, width: thickness*16);
        var coords = stretchedBoundary.getPixelCoordinates(Coordinates(pageBoundary.north, pageBoundary.west), overviewImage.width, overviewImage.height);
        img_lib.copyInto(overviewImage, i,dstX: (coords.x+thickness/2).ceil(), dstY: (coords.y + thickness/2).ceil());
        //img_lib.drawStringCentered(overviewImage, font, "123", color: color, x: coords.x+2*thickness, y: coords.y+2*thickness);
      }
    }

    final img = pw.Image(
      pw.ImageImage(overviewImage),
      fit: pw.BoxFit.contain,
      alignment: pw.Alignment.center
    );
    return pw.Page(
      pageFormat: config.paper.pdfFormat,
      orientation: config.paper.orientation.pdfOrientation,
      build: (context) => pw.Center(child: img),
    );
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