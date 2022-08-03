import 'package:osm_atlas/osm_atlas_configuration.dart';
import 'package:osm_atlas/utils.dart';

class AtlasBuilder{
  final AtlasConfiguration config;
  AtlasBuilder(this.config);

  void build(){
    config.tileProvider.getTileTC(TileCoordinates(17879, 11360, 15));
    print(TileCoordinates(17879, 11360, 15).tileSize);
    config.tileProvider.getTileSC(Coordinates(48.253175,16.339637), 18);
  }
}