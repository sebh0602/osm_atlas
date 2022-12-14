import 'dart:io';

import 'package:yaml/yaml.dart';

import 'package:osm_atlas/atlas_configuration.dart';
import 'package:osm_atlas/atlas_builder.dart';

void main(List<String> arguments) {
  print("Configuring...");
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
    dynamic yamlMap;
    try{
      yamlMap = loadYaml(yamlString);
    } catch (e){
      print("Error in YAML configuration: ${e.toString().split("\n").first}");
      return;
    }
    
    config.importYamlConfiguration(yamlMap);
  } else{
    print("Config file not found!");
    print("($configFilePath)\n");
    printUsage();
    return;
  }

  AtlasBuilder(config).build();
}

void printUsage(){
  print("Usage:");
  print("osm_atlas [config_file]");
}