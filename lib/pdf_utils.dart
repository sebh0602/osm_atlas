import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img_lib;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:osm_atlas/atlas_configuration.dart';
import 'package:osm_atlas/coordinates.dart';
import 'package:osm_atlas/utils.dart';

class Page{
  final int pageNumber;
  final Boundary boundary;
  final AtlasConfiguration config;
  final PDFDocument pdf;
  final PagePosition pagePosition;
  img_lib.Image? _pageImage;
  Page(this.pageNumber,this.pagePosition,this.boundary,this.config,this.pdf);

  Future<void> build() async{
    _pageImage = await createPageImage(boundary,config.zoomLevel,config,pdf: pdf);
    final img =pw.Image(
      pw.ImageImage(_pageImage!),
      fit: pw.BoxFit.fill
      //width: config.paper.printableWidth*Paper.mm,
      //height: config.paper.printableHeight*Paper.mm
    );

    final page = pw.Page(
      pageFormat: config.paper.pdfFormat(),
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
    if (neighbourNumber == null || (config.omitHorizontalLinks && dir.horizontal)){
      return pw.Container(height: 0, width: 0);
    }
    neighbourNumber += pdf.additionalOffset;

    final borderSide = pw.BorderSide(color: PdfColor.fromHex("FFFFFF"),width: 1*Paper.mm);
    var border = pw.Border(bottom: borderSide,top: borderSide,left: borderSide,right: borderSide);
    
    var alignment = pw.Alignment.center;
    double? left,right,top,bottom;
    switch (dir){
      case Direction.left:
        left = 0;
        bottom = 50*Paper.mm;
        border = pw.Border(bottom: borderSide,top: borderSide,right: borderSide);
        break;
      case Direction.right:
        right = 0;
        top = 50*Paper.mm;
        border = pw.Border(bottom: borderSide,top: borderSide,left: borderSide);
        break;
      case Direction.top:
        top = 0;
        right = 50*Paper.mm;
        border = pw.Border(bottom: borderSide,left: borderSide,right: borderSide);
        break;
      case Direction.bottom:
        bottom = 0;
        left = 50*Paper.mm;
        border = pw.Border(top: borderSide,left: borderSide,right: borderSide);
        break;
    }

    final textContainer = pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex("000000"),
        border: (config.whiteBorderAroundLinks) ? border : null
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
    );

    final marginContainer = pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex("000000"),
        border: (config.whiteBorderAroundLinks) ? border : null
      ),
      width: dir.horizontal ? config.paper.margin * Paper.mm : width,
      height: dir.horizontal ? height : config.paper.margin * Paper.mm,
    );

    List<pw.Widget> children;
    if (dir == Direction.left || dir == Direction.top){
      children = [marginContainer,textContainer];
    } else{
      children = [textContainer,marginContainer];
    }
    final arrangement = dir.horizontal ? pw.Row(children: children) : pw.Column(children: children);

    return pw.Positioned(
      left: left,
      top: top,
      right:right,
      bottom: bottom,
      child: pw.UrlLink(
        destination: "#page=$neighbourNumber",
        child: config.paper.coloredMargin ? arrangement : textContainer
      )
    );
  }

  Direction get numberingSide{
    if (config.dontAlternatePageNumbering){
      return (config.evenLeftNumbering) ? Direction.left : Direction.right;
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

    final roundedContainer = pw.Container(
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
    );

    final sideMargin = pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex("FFFFFF"),
      ),
      width: config.paper.margin * Paper.mm,
      height: config.paper.margin * Paper.mm + height
    );

    final arrangement = pw.Row(
      children: [
        if (numberingSide == Direction.left) sideMargin,
        pw.Column(
          crossAxisAlignment: (numberingSide == Direction.left) ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
          children: [
            roundedContainer,
            pw.Container(
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex("FFFFFF"),
              ),
              width: width,
              height: config.paper.margin * Paper.mm
            )
          ]
        ),
        if (numberingSide == Direction.right) sideMargin,
      ]
    );


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
            width: width + borderWidth + (config.paper.coloredMargin ? config.paper.margin.toDouble() * Paper.mm : 0.0),
            height: height + borderWidth + (config.paper.coloredMargin ? config.paper.margin.toDouble() * Paper.mm : 0.0)
          ),
          config.paper.coloredMargin ? arrangement : roundedContainer
        ]
      )
    );
  }

  String _padNumber(int number, PagePosition pP){
    final padLength = (pP.width*pP.height+config.pageNumberOffset+pdf.additionalOffset).toString().length;
    return padNumber(number, padLength);
  }

  static Future<img_lib.Image> createPageImage(Boundary boundary, int zoomLevel, AtlasConfiguration config,{PDFDocument? pdf}) async{
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
        pdf?.addDownloadedTile();
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
  var _downloadedTiles = 0;
  PDFDocument(this.pages,this.additionalOffset,this.overviewBoundary,this.xPages,this.yPages, this.config);

  int get documentLength => xPages*yPages;

  void statusUpdate(){
    stdout.write("Completed pages: $_addedPages/$documentLength, (Down-)loaded tiles: $_downloadedTiles\r");
  }

  void addDownloadedTile(){
    _downloadedTiles++;
    if (_downloadedTiles % 10 == 0) statusUpdate();
  }

  void addPage(pw.Page page, int number){
    pages[number-1] = page;
    _addedPages++;
    statusUpdate();
    if (_addedPages == documentLength){
      print("");
      _createDocument();
    }
  }

  void _createDocument() async{
    print("Creating title and overview...");
    if (!config.omitTitlePage) pdf.addPage(_createTitlePage());
    if (config.addBlankPage) pdf.addPage(pw.Page(pageFormat: config.paper.pdfFormat(), orientation: config.paper.orientation.pdfOrientation, build: (context) => pw.Container(width: 0,height: 0),));
    pdf.addPage(await _createOverview());
    if (!config.omitInnerPage) pdf.addPage(_createInnerPage());

    print("Composing and saving pdf...");
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
      pageFormat: config.paper.pdfFormat(keepMargin: true),
      orientation: config.paper.orientation.pdfOrientation,
      build: (context) {
        return pw.Stack(
          children: [
            pw.Positioned(
              left: config.textInset*Paper.mm,
              right: config.textInset*Paper.mm,
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
              left: config.textInset*Paper.mm,
              right: config.textInset*Paper.mm,
              bottom: config.textInset*Paper.mm,
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
    final date = "${DateTime.now().year}-${padNumber(DateTime.now().month,2)}-${padNumber(DateTime.now().day,2)}";
    final text = "Base map: ${config.sourceURL}\nOverlay: ${config.overlayURL ?? "none"}\nZoom level: ${config.zoomLevel}\nPage Size: ${config.paper.size.name}\nCreation date: $date\nThis atlas was created using a program written by Sebastian Hietsch.";
    final pageWidth = (config.paper.printableWidth/10 - 2*config.textInset/10).floor(); //in cm
    final ssW = _getScaleSectionWidth();
    final ssCount = (pageWidth/(ssW*100/config.scale)).floor();
    final scaleText = "$ssCount ?? ${formatMeters(ssW)} = ${formatMeters(ssCount*ssW)}";

    final scale = [
      pw.Positioned(
        left: config.textInset*Paper.mm,
        right: config.textInset*Paper.mm,
        top: config.textInset*Paper.mm,
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              "1 : ${addSeparators(config.scale.toString())}",
              style: pw.TextStyle(
                font: config.font,
                fontSize: 10
              ),
              textAlign: pw.TextAlign.left
            ),
            pw.Text(
              "1 cm = ${formatMeters(config.scale/100)}",
              style: pw.TextStyle(
                font: config.font,
                fontSize: 10
              ),
              textAlign: pw.TextAlign.right
            )
          ]
        ),
      ),
      pw.Positioned(
        right: config.textInset*Paper.mm,
        left: config.textInset*Paper.mm,
        top: (config.textInset + 20)*Paper.mm,
        child: pw.Text(
          scaleText,
          style: pw.TextStyle(
            font: config.font,
            fontSize: 10
          ),
          textAlign: pw.TextAlign.center
        ),
      ),
      pw.Positioned(
        left:0,
        right: 0,
        top:(config.textInset + 10)*Paper.mm,
        child: pw.Center(
          child: pw.Image(
            pw.ImageImage(_getScaleImage(ssCount)),
            width: ssW*ssCount*1000/config.scale*Paper.mm,
            height: 5*Paper.mm,
            alignment: pw.Alignment.center
          )
        ),
      )
    ];

    final bottomText = pw.Positioned(
      left: config.textInset*Paper.mm,
      right: config.textInset*Paper.mm,
      bottom: config.textInset*Paper.mm,
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            config.innerText,
            style: pw.TextStyle(
              font: config.font,
              fontSize: 10
            ),
            textAlign: pw.TextAlign.center
          ),
          pw.Container(height: 10*Paper.mm),
          pw.Text(
            text,
            style: pw.TextStyle(
              font: config.font,
              fontSize: 10
            ),
            textAlign: pw.TextAlign.left
          )
        ]
      )  
    );

    return pw.Page(
      pageFormat: config.paper.pdfFormat(keepMargin: true),
      orientation: config.paper.orientation.pdfOrientation,
      build: (context) {
        return pw.Stack(
          children: [
            ...scale,
            bottomText
          ]
        );
      },
    );
  }

  int _getScaleSectionWidth(){
    var width = 5.0; //meter
    final factors = [2.0, 2.5, 2.0];
    var factorIndex = 0;
    final minSections = 3;
    while (width*100/config.scale < (config.paper.printableWidth/10 - 2*config.textInset/10) / minSections){ //comparison in cm
      width = width * factors[factorIndex % 3];
      factorIndex += 1;
    }
    factorIndex -= 1;
    width = width / factors[factorIndex % 3];
    return width.round();
  }

  img_lib.Image _getScaleImage(int sectionCount){
    final black = img_lib.Color.fromRgb(0,0,0);
    var returnImg = img_lib.Image(1050,20);
    img_lib.drawRect(returnImg, 0, 0, 1049, 19, black);
    var blackImg = img_lib.Image(1,18);
    img_lib.fill(blackImg, black);
    final sectionWidth = (1050/sectionCount).round();
    blackImg = img_lib.copyResize(blackImg,height: 18,width:sectionWidth);
    for (int i = 0; i<sectionCount; i+=2){
      img_lib.copyInto(returnImg, blackImg,dstY:1,dstX:i*sectionWidth);
    }
    return returnImg;
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
        var text = padNumber(pageNumber,(additionalOffset+config.pageNumberOffset+xPages*yPages).toString().length);

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
      pageFormat: config.paper.pdfFormat(keepMargin: true),
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
  final bool coloredMargin;
  static final double mm = PdfPageFormat.mm;

  Paper(this.size, this.orientation, {required this.margin, required this.overlap, this.coloredMargin = false});

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

  PdfPageFormat pdfFormat({bool keepMargin = false}){
    final pMargin = (coloredMargin && !keepMargin) ? 0.0 : margin*mm;
    if (orientation == PaperOrientation.landscape){
      return PdfPageFormat(size.longSide*mm, size.shortSide*mm, marginAll: pMargin);
    } else {
      return PdfPageFormat(size.shortSide*mm, size.longSide*mm, marginAll: pMargin);
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

  String get name{
    return toString().split('.').last.toUpperCase();
  }
}

enum PaperOrientation{
  portrait(pw.PageOrientation.portrait),
  landscape(pw.PageOrientation.landscape);

  final pw.PageOrientation pdfOrientation;
  const PaperOrientation(this.pdfOrientation);
}