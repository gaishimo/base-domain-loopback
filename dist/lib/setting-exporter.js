'use strict';
var LoopbackRepository, ModelDefinition, SettingExporter, debug, fs;

debug = require('debug')('base-domain-loopback:setting-exporter');

fs = require('fs');

LoopbackRepository = require('./loopback-repository');

ModelDefinition = require('./model-definition');


/**
export model info into loopback-with-admin's format
only available in Node.js

@class SettingExporter
@module base-domain-loopback
 */

SettingExporter = (function() {
  function SettingExporter(facade) {
    this.facade = facade;
  }


  /**
  Create ModelDefinitions
  
  1. load all the entities
  2. check each entity's repository is LoopbackRepository
  3. create ModelDefinition
  4. add "hasMany" relations
  5. add "hasManyThrough" relations
  6. add custom relations
  7. return object
  
  @method export
  @public
  @return {Object}
   */

  SettingExporter.prototype["export"] = function() {
    var EntityModel, EntityRepository, definition, definitions, e, j, lbModelName, len, modelName, name, ref;
    definitions = {};
    ref = this.getAllEntityModels();
    for (j = 0, len = ref.length; j < len; j++) {
      EntityModel = ref[j];
      modelName = EntityModel.getName();
      try {
        EntityRepository = this.facade.require(modelName + '-repository');
        if (!(EntityRepository.prototype instanceof LoopbackRepository)) {
          debug('%s is not instance of LoopbackRepository', modelName + '-repository');
          continue;
        }
      } catch (_error) {
        e = _error;
        if (e.message.match(/model .*? is not found/)) {
          debug('%s does not have Repository', modelName);
        } else {
          debug('Error in reading repository of %s', modelName);
          debug(e.message);
          debug(e.stack);
        }
        continue;
      }
      lbModelName = EntityRepository.getLbModelName();
      debug('model "%s" is added to model definition (loopback name: "%s")', modelName, lbModelName);
      definitions[lbModelName] = new ModelDefinition(EntityModel, EntityRepository, this.facade);
    }
    this.setHasManyRelations(definitions);
    this.setHasManyThroughRelation(definitions);
    for (name in definitions) {
      definition = definitions[name];
      definition.addCustomRelations();
      definitions[name] = definition["export"]();
    }
    debug('models for loopback: %s', Object.keys(definitions).join(', '));
    return definitions;
  };


  /**
  set "hasMany" relations
  
  @private
   */

  SettingExporter.prototype.setHasManyRelations = function(definitions) {
    var definition, lbModelName, prop, relLbModelName, relModelDefinition, results, typeInfo;
    results = [];
    for (lbModelName in definitions) {
      definition = definitions[lbModelName];
      results.push((function() {
        var ref, results1;
        ref = definition.getEntityProps();
        results1 = [];
        for (prop in ref) {
          typeInfo = ref[prop];
          relLbModelName = this.getLbModelName(typeInfo.model);
          if (!relLbModelName) {
            continue;
          }
          relModelDefinition = definitions[relLbModelName];
          results1.push(relModelDefinition != null ? relModelDefinition.setHasManyRelation(lbModelName, typeInfo.idPropName) : void 0);
        }
        return results1;
      }).call(this));
    }
    return results;
  };


  /**
  set "hasManyThrough" relations
  
  @private
   */

  SettingExporter.prototype.setHasManyThroughRelation = function(definitions) {
    var defA, defB, definition, i, lbEntityProps, lbModelName, modelA, modelB, prop, propA, propB, props, ref, results, typeInfo, typeInfoA, typeInfoB;
    results = [];
    for (lbModelName in definitions) {
      definition = definitions[lbModelName];
      lbEntityProps = {};
      ref = definition.getEntityProps();
      for (prop in ref) {
        typeInfo = ref[prop];
        if (this.getLbModelName(typeInfo.model)) {
          lbEntityProps[prop] = typeInfo;
        }
      }
      props = Object.keys(lbEntityProps);
      results.push((function() {
        var j, len, results1;
        results1 = [];
        for (i = j = 0, len = props.length; j < len; i = ++j) {
          propA = props[i];
          propB = props[i + 1];
          if (propB == null) {
            break;
          }
          typeInfoA = lbEntityProps[propA];
          typeInfoB = lbEntityProps[propB];
          modelA = this.getLbModelName(typeInfoA.model);
          modelB = this.getLbModelName(typeInfoB.model);
          defA = definitions[modelA];
          defB = definitions[modelA];
          defA.setHasManyThroughRelation({
            model: modelB,
            foreignKey: typeInfoA.idPropName,
            keyThrough: typeInfoB.idPropName,
            through: lbModelName
          });
          results1.push(defB.setHasManyThroughRelation({
            model: modelA,
            foreignKey: typeInfoB.idPropName,
            keyThrough: typeInfoA.idPropName,
            through: lbModelName
          }));
        }
        return results1;
      }).call(this));
    }
    return results;
  };

  SettingExporter.prototype.getLbModelName = function(modelName) {
    var Repo, e;
    try {
      Repo = this.facade.require(modelName + '-repository');
      if (!(Repo.prototype instanceof LoopbackRepository)) {
        return null;
      }
      return Repo.getLbModelName();
    } catch (_error) {
      e = _error;
      return null;
    }
  };


  /**
  get all entity models registered in domain facade
  
  @private
   */

  SettingExporter.prototype.getAllEntityModels = function() {
    var klass, name;
    this.loadAll();
    return (function() {
      var ref, results;
      ref = this.facade.classes;
      results = [];
      for (name in ref) {
        klass = ref[name];
        if (klass.isEntity) {
          results.push(klass);
        }
      }
      return results;
    }).call(this);
  };


  /**
  load all models in directory
  
  @private
   */

  SettingExporter.prototype.loadAll = function() {
    var domainFiles, e, ext, filename, j, len, name, ref, results;
    if (!fs.existsSync(this.facade.dirname)) {
      return;
    }
    domainFiles = fs.readdirSync(this.facade.dirname);
    results = [];
    for (j = 0, len = domainFiles.length; j < len; j++) {
      filename = domainFiles[j];
      try {
        ref = filename.split('.'), name = ref[0], ext = ref[1];
        if (ext !== 'coffee' && ext !== 'js') {
          continue;
        }
        results.push(this.facade.require(name));
      } catch (_error) {
        e = _error;
        debug('Error in reading file: %s', filename);
        debug(e.message);
        results.push(debug(e.stack));
      }
    }
    return results;
  };

  return SettingExporter;

})();

module.exports = SettingExporter;