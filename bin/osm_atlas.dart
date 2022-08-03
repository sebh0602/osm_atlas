import 'dart:io';

import 'package:yaml/yaml.dart';

import 'package:osm_atlas/osm_atlas_configuration.dart';
import 'package:osm_atlas/atlas_builder.dart';
import 'package:osm_atlas/utils.dart';

void main(List<String> arguments) {
  //read configuration
  if (arguments.length > 1){
    printUsage();
    return;
  }
  final config = AtlasConfiguration();

  var configFilePath = "osm_atlas_configuration.yaml";
  if (arguments.length == 1){
    configFilePath = arguments[0];
  }

  final configFile = File(configFilePath);
  if (configFile.existsSync()){
    final yamlString = configFile.readAsStringSync();
    final yamlMap = loadYaml(yamlString);
    config.importYamlConfiguration(yamlMap);
  } else{
    if (arguments.length == 1){
      print("File not found!\n");
      printUsage();
      return;
    }
  }

  AtlasBuilder(config).build();
  
}

void printUsage(){
  print("Usage:");
  print("osm_atlas [config_file]");
}