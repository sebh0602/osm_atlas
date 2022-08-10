import 'package:image/image.dart' as img_lib;
import 'package:osm_atlas/atlas_configuration.dart';

import 'package:osm_atlas/coordinates.dart';
import 'package:osm_atlas/tile_provider.dart';


class Tile{
  final List<int> bytes;
  final TileCoordinates tileCoordinates;
  final AtlasConfiguration config;
  img_lib.Image? image;
  
  Tile(this.tileCoordinates, this.bytes, this.config){
    image = TileProvider.decodeImg(bytes,config);
    
  }
}

String addSeparators(String number){
  var returnString = "";
  final separator = " ";
  for (int i = 1; i<=number.length; i++){
    returnString = number[number.length-i] + returnString;
    if (i % 3 == 0 && i != number.length){
      returnString = separator + returnString;
    }
  }
  return returnString;
}

String padNumber(int number, int padLength){
  final ownLen = number.toString().length;
  return "0"*(padLength-ownLen) + number.toString();
}

String formatMeters(num meters){
  var suffix = " m";
  if (meters >= 10000){
    suffix = " km";
    meters = meters/1000;
  }
  return addSeparators(meters.round().toString()) + suffix;


}
