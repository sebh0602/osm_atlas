import 'package:pdf/widgets.dart' as pw;

import 'package:osm_atlas/atlas_configuration.dart';
import 'package:osm_atlas/coordinates.dart';
import 'package:osm_atlas/pdf_utils.dart';

class AtlasBuilder{
  final AtlasConfiguration config;
  Boundary? _adjustedBoundary;
  int? _adjustedMapWidth;
  int? _adjustedMapHeight;
  int? _xPages;
  int? _yPages;

  AtlasBuilder(this.config);

  void build(){
    print("Calculating...");
    //making sure the pages fit well
    _xPages = ((config.mapWidth-2*config.paper.overlap)/config.paper.nonOverlappingWidth).ceil();
    _yPages = ((config.mapHeight-2*config.paper.overlap)/config.paper.nonOverlappingHeight).ceil();

    _adjustedMapWidth = _xPages! * config.paper.nonOverlappingWidth + 2*config.paper.overlap;
    _adjustedMapHeight = _yPages! * config.paper.nonOverlappingHeight + 2*config.paper.overlap;

    final xStretch = _adjustedMapWidth! / config.mapWidth;
    final yStretch = _adjustedMapHeight! / config.mapHeight;

    _adjustedBoundary = config.boundary.stretch(xStretch, yStretch);
    final adjustedBoundaryWithoutOverlap = _adjustedBoundary!.stretch(1-2*config.paper.overlap/_adjustedMapWidth!, 1-2*config.paper.overlap/_adjustedMapHeight!);

    //creating page objects
    int pageCount = 0;
    var pages = List<Page?>.filled(_xPages!*_yPages!, null);
    var pdfPages = List<pw.Page?>.filled(_xPages!*_yPages!, null);

    final document = PDFDocument(pdfPages, _xPages!*_yPages!, config);

    final xPageStretch = 1+ 2*config.paper.overlap/config.paper.nonOverlappingWidth;
    final yPageStretch = 1+ 2*config.paper.overlap/config.paper.nonOverlappingHeight;
    for (int yPage = 0; yPage<_yPages!; yPage++){
      for (int xPage = 0; xPage<_xPages!; xPage++){
        var pageBoundary = adjustedBoundaryWithoutOverlap.section(xPage, _xPages!, yPage, _yPages!);
        var pP = PagePosition(_xPages!, _yPages!, xPage, yPage, config);
        pages[pageCount++] = Page(pageCount, pP, pageBoundary.stretch(xPageStretch, yPageStretch),config,document);
      }
    }

    print("(Down-)loading and composing tiles...");

    //building pages
    for (Page? p in pages){
      p?.build();
    }
  }
}