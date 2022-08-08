import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img_lib;

import 'package:osm_atlas/atlas_configuration.dart';
import 'package:osm_atlas/utils.dart';
import 'package:osm_atlas/coordinates.dart';

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
      return Tile(tc,bytes,config);
    } else {
      var tile = await _getNetworkTile(tc,3);
      if (config.overlayURL != null){
        var overlayTile = await _getNetworkTile(tc, 3, getOverlay: true);
        var baseImg = TileProvider.decodeImg(tile.bytes,config);
        var topImg = TileProvider.decodeImg(overlayTile.bytes,config);
        if (baseImg == null || topImg == null){
          throw Exception("Images shouldn't be null!");
        }
        tile = Tile(tc, img_lib.encodePng(img_lib.copyInto(baseImg, topImg)),config);
      }
      () async {
        await file.create(recursive: true);
        await file.writeAsBytes(tile.bytes);
      }();
      return tile;
    }
  }

  static img_lib.Image? decodeImg(List<int> bytes, AtlasConfiguration config){
    if (config.sourceURL.split(".").last == "png"){
      return img_lib.decodePng(bytes);
    } else if (config.sourceURL.split(".").last == "jpg" || config.sourceURL.split(".").last == "jpeg"){
      return img_lib.decodeJpg(bytes);
    } else{
      return img_lib.decodeImage(bytes);
    }
  }

  String _getRequestUrl(TileCoordinates tc, {bool getOverlay = false}){
    final baseUrl = (getOverlay && config.overlayURL != null) ? config.overlayURL : config.sourceURL;
    return baseUrl!
      .replaceFirst("{x}", tc.x.toString())
      .replaceFirst("{y}", tc.y.toString())
      .replaceFirst("{z}", tc.z.toString())
      .replaceFirst("{k}", config.apiKey ?? "");
  }

  String get _urlTimeHashCode{
    //A new file will be fetched at least once every 3 months
    final baseString = "${config.sourceURL}${config.overlayURL ?? ""}Y${DateTime.now().year}Q${(DateTime.now().month/3).floor() + 1}";
    return baseString.hashCode.toRadixString(36);
  }

  String _getTilePath(TileCoordinates tc){
    return "${config.cachePath}/$_urlTimeHashCode-${tc.z}-${tc.x}-${tc.y}.png";
  }

  Future<Tile> _getNetworkTile(TileCoordinates tc,int remainingTries,{bool getOverlay = false}) async {
    remainingTries--;
    final coordinateUrl = _getRequestUrl(tc, getOverlay:getOverlay);
    final url = Uri.parse(coordinateUrl);
    try{
      final response = await http.get(url);
      if (response.statusCode == 200){
        final bytes = response.bodyBytes;
        return Tile(tc, bytes, config);
      } else {
        if (remainingTries == 0){
          throw HttpException("Status code: ${response.statusCode}, header: ${response.headers}, url: $coordinateUrl");
        } else {
          return _getNetworkTile(tc, remainingTries);
        }
      }
    } catch (e){
      if (remainingTries == 0){
        rethrow;
      }
      return _getNetworkTile(tc, remainingTries);
    }
  }
}