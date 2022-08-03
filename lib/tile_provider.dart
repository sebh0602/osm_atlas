import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:osm_atlas/osm_atlas_configuration.dart';
import 'package:osm_atlas/utils.dart';

class TileProvider{
  final AtlasConfiguration config;

  TileProvider(this.config);

  //Standard coordinates
  Future<Tile> getTileSC(Coordinates coords,int zoom) async{
    return getTileTC(coords.toTileCoordinates(zoom));
  }

  //Tile coordinates
  Future<Tile> getTileTC(TileCoordinates tc) async{
    final path = _getTilePath(tc);
    final file = File(path);
    if (await file.exists()){
      final bytes = await file.readAsBytes();
      return Tile(tc,bytes);
    } else {
      final tile = await _getNetworkTile(tc);
      () async {
        await file.create(recursive: true);
        await file.writeAsBytes(tile.bytes);
      }();
      return tile;
    }
  }

  String _getRequestUrl(TileCoordinates tc){
    return config.sourceURL
      .replaceFirst("{x}", tc.x.toString())
      .replaceFirst("{y}", tc.y.toString())
      .replaceFirst("{z}", tc.z.toString());
  }

  String get _urlTimeHashCode{
    //A new file will be fetched at least once every 3 months
    final baseString = "${config.sourceURL}Y${DateTime.now().year}Q${(DateTime.now().month/3).floor() + 1}";
    return baseString.hashCode.toRadixString(36);
  }

  String _getTilePath(TileCoordinates tc){
    return "${config.cachePath}/$_urlTimeHashCode-${tc.z}-${tc.x}-${tc.y}.png";
  }

  Future<Tile> _getNetworkTile(TileCoordinates tc) async {
    final coordinateUrl = _getRequestUrl(tc);
    final url = Uri.parse(coordinateUrl);
    final response = await http.get(url);
    if (response.statusCode == 200){
      final bytes = response.bodyBytes;
      return Tile(tc, bytes);
    } else {
      throw HttpException("Status code: ${response.statusCode}, header: ${response.headers}");
    }
  }
}