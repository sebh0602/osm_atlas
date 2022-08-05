import 'dart:typed_data';
import 'package:image/image.dart' as img_lib;
import 'package:osm_atlas/coordinates.dart';


class Tile{
  final Uint8List bytes;
  final TileCoordinates tileCoordinates;
  img_lib.Image? image;
  
  Tile(this.tileCoordinates, this.bytes){
    image = img_lib.decodePng(bytes);
    
  }
}