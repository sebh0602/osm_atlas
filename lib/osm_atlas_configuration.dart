import 'package:osm_atlas/utils.dart';
import 'package:osm_atlas/tile_provider.dart';

class OsmAtlasConfiguration{
  //Vienna as default location
  Coordinates nwCorner = Coordinates(48.323, 16.183);
  Coordinates seCorner = Coordinates(48.118, 16.579);

  Paper paper = Paper(PaperSize.a4, PaperOrientation.portrait);
  int zoomLevel = 15;
  String sourceURL = "https://tile.osmand.net/hd/{z}/{x}/{y}.png";
  String cachePath = "cache";
  String outputPath = "output";

  TileProvider? _tileProvider;

  void createTileProvider(){
    _tileProvider = TileProvider(sourceURL, cachePath);
  }

  void importYamlConfiguration(dynamic yamlMap){
    for (MapEntry entry in yamlMap.entries){
      switch (entry.key){
        case "nwCorner":
          if (!entry.value.keys.contains("lat") || !entry.value.keys.contains("long")){
            print("WARNING: Incomplete coordinates for 'nwCorner'! Ignoring property.");
            continue;
          } else {
            nwCorner = Coordinates(entry.value["lat"], entry.value["long"]);
          }
          break;
        case "seCorner":
          if (!entry.value.keys.contains("lat") || !entry.value.keys.contains("long")){
            print("WARNING: Incomplete coordinates for 'seCorner'! Ignoring property.");
            continue;
          } else {
            seCorner = Coordinates(entry.value["lat"], entry.value["long"]);
          }
          break;
        case "paper":
          var size = paper.size;
          var orientation = paper.orientation;
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
          paper = Paper(size, orientation);
          break;
        case "zoomLevel":
          zoomLevel = entry.value;
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