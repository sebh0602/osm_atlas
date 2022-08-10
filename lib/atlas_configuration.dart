import 'dart:io';

import 'package:pdf/widgets.dart' as pw;

import 'package:osm_atlas/tile_provider.dart';
import 'package:osm_atlas/coordinates.dart';
import 'package:osm_atlas/pdf_utils.dart';

class AtlasConfiguration{
  //Vienna as default location
  Boundary boundary = Boundary(48.28, 48.13, 16.515, 16.25);

  Paper paper = Paper(PaperSize.a4, PaperOrientation.portrait, margin:5, overlap:5);
  int pageNumberOffset = 0;
  bool evenLeftNumbering = false;
  bool dontAlternatePageNumbering = false;
  bool omitHorizontalLinks = false;
  String fontSource = "fonts/roboto.ttf";
  String fntFontSource = "fonts/roboto.zip";
  bool whiteBorderAroundLinks = false; //page links
  pw.Font? font;

  String title = "Atlas";
  String subtitle = "Sebastian Hietsch / OpenStreetMap (${DateTime.now().year})";
  String innerText = "Map data from OpenStreetMap.\nopenstreetmap.org/copyright";
  bool omitTitlePage = false;
  bool omitInnerPage = false;
  bool addBlankPage = false;

  int zoomLevel = 15;
  int overviewZoomLevel = 13;
  int scale = 50000;
  String sourceURL = "https://tile.osmand.net/hd/{z}/{x}/{y}.png";
  String? overlayURL;
  String? apiKey; //can be either the key itself or the path to the key
  String cachePath = "cache";

  String outputPath = "output";

  TileProvider? _tileProvider;

  //I am using this complicated construction, because the sourceURL and cachePath may not be known during construction
  TileProvider get tileProvider{
    return _tileProvider ?? _createTileProvider();
  }

  TileProvider _createTileProvider(){
    _tileProvider = TileProvider(this);
    return _tileProvider!;
  }

  double get mapWidth{ //in mm, ideal size without adjustments
    return boundary.width/scale*1000;
  }

  double get mapHeight{ //in mm
    return boundary.height/scale*1000;
  }

  String get fileType{
    return sourceURL.split(".").last.split("?").first;
  }

  void importYamlConfiguration(dynamic yamlMap){
    for (MapEntry entry in yamlMap.entries){
      switch (entry.key){
        case "boundary":
          if (!entry.value.keys.contains("north") || !entry.value.keys.contains("south") || !entry.value.keys.contains("east") || !entry.value.keys.contains("west")){
            print("WARNING: Incomplete coordinates for 'boundary'! You need to specify North/South/East/West. Ignoring property.");
            continue;
          } else {
            boundary = Boundary(entry.value["north"], entry.value["south"],entry.value["east"], entry.value["west"]);
          }
          break;
        case "paper":
          var size = paper.size;
          var orientation = paper.orientation;
          var margin = paper.margin;
          var overlap = paper.overlap;
          var coloredMargin = paper.coloredMargin;
          if (entry.value.keys.contains("size")){
            var s = entry.value["size"];
            switch (s){
              case "a0":
                size = PaperSize.a0;
                break;
              case "a1":
                size = PaperSize.a1;
                break;
              case "a2":
                size = PaperSize.a2;
                break;
              case "a3":
                size = PaperSize.a3;
                break;
              case "a4":
                size = PaperSize.a4;
                break;
              case "a5":
                size = PaperSize.a5;
                break;
              case "a6":
                size = PaperSize.a6;
                break;
            }
          }
          if (entry.value.keys.contains("orientation")){
            var o = entry.value["orientation"];
            if (o == "portrait"){
              orientation = PaperOrientation.portrait;
            } else if (o == "landscape"){
              orientation = PaperOrientation.landscape;
            }
          }
          if (entry.value.keys.contains("margin")){
            margin = entry.value["margin"];
          }
          if (entry.value.keys.contains("overlap")){
            overlap = (entry.value["overlap"]/2).floor();
            //externally, overlap is the non-exclusive part of the page.
            //Internally, overlap is added to the page after the fact. To avoid confusion due to overlap being present on both pages, it is halved here.
          }
          if (entry.value.keys.contains("coloredMargin")){
            coloredMargin = entry.value["coloredMargin"];
          }
          paper = Paper(size, orientation, margin:margin, overlap:overlap, coloredMargin: coloredMargin);
          break;
        case "zoomLevel":
          zoomLevel = entry.value;
          break;
        case "overviewZoomLevel":
          overviewZoomLevel = entry.value;
          break;
        case "scale":
          scale = entry.value;
          break;
        case "sourceURL":
          sourceURL = entry.value;
          break;
        case "overlayURL":
          overlayURL = entry.value;
          break;
        case "apiKey":
          final f = File(entry.value);
          if (f.existsSync()){
            apiKey = f.readAsStringSync();
          } else {
            apiKey = entry.value;
          }
          break;
        case "cachePath":
          cachePath = entry.value;
          break;
        case "outputPath":
          outputPath = entry.value;
          break;
        case "pageNumberOffset":
          pageNumberOffset = entry.value;
          break;
        case "evenLeftNumbering":
          evenLeftNumbering = entry.value;
          break;
        case "dontAlternatePageNumbering":
          dontAlternatePageNumbering = entry.value;
          break;
        case "omitHorizontalLinks":
          omitHorizontalLinks = entry.value;
          break;
        case "title":
          title = entry.value;
          break;
        case "subtitle":
          subtitle = entry.value;
          break;
        case "innerText":
          innerText = entry.value;
          break;
        case "omitTitlePage":
          omitTitlePage = entry.value;
          break;
        case "omitInnerPage":
          omitInnerPage = entry.value;
          break;
        case "addBlankPage":
          addBlankPage = entry.value;
          break;
        default:
          print("WARNING: Unknown property '${entry.key}'!");
          break;
      }

    }
  }
}