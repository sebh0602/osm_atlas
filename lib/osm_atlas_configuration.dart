import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:osm_atlas/utils.dart';
import 'package:osm_atlas/tile_provider.dart';

class AtlasConfiguration{
  //Vienna as default location
  Boundary boundary = Boundary(48.323, 48.118, 16.579, 16.183);

  Paper paper = Paper(PaperSize.a4, PaperOrientation.portrait,5,5);
  int zoomLevel = 15;
  int scale = 50000;
  String sourceURL = "https://tile.osmand.net/hd/{z}/{x}/{y}.png";
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
            margin = (entry.value["overlap"]/2).floor();
            //externally, overlap is the non-exclusive part of the page.
            //Internally, overlap is added to the page after the fact. To avoid confusion due to overlap being present on both pages, it is halved here.
          }
          paper = Paper(size, orientation, margin, overlap);
          break;
        case "zoomLevel":
          zoomLevel = entry.value;
          break;
        case "scale":
          scale = entry.value;
          break;
        case "sourceURL":
          sourceURL = entry.value;
          break;
        case "cachePath":
          cachePath = entry.value;
          break;
        case "outputPath":
          outputPath = entry.value;
          break;
        default:
          print("WARNING: Unknown property '${entry.key}'!");
          break;
      }

    }
  }
}