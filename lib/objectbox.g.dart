// GENERATED CODE - DO NOT MODIFY BY HAND
// This code was generated by ObjectBox. To update it run the generator again
// with `dart run build_runner build`.
// See also https://docs.objectbox.io/getting-started#generate-objectbox-code

// ignore_for_file: camel_case_types, depend_on_referenced_packages
// coverage:ignore-file

import 'dart:typed_data';

import 'package:flat_buffers/flat_buffers.dart' as fb;
import 'package:objectbox/internal.dart'
    as obx_int; // generated code can access "internal" functionality
import 'package:objectbox/objectbox.dart' as obx;
import 'package:objectbox_flutter_libs/objectbox_flutter_libs.dart';

import 'app/core/event.dart';
import 'app/core/rank.dart';
import 'app/core/thing.dart';

export 'package:objectbox/objectbox.dart'; // so that callers only have to import this file

final _entities = <obx_int.ModelEntity>[
  obx_int.ModelEntity(
      id: const obx_int.IdUid(2, 7002050964441799220),
      name: 'Event',
      lastPropertyId: const obx_int.IdUid(3, 8344290899505051100),
      flags: 0,
      properties: <obx_int.ModelProperty>[
        obx_int.ModelProperty(
            id: const obx_int.IdUid(1, 4307723726814652867),
            name: 'id',
            type: 6,
            flags: 1),
        obx_int.ModelProperty(
            id: const obx_int.IdUid(2, 421814647252034290),
            name: 'initialTime',
            type: 10,
            flags: 0),
        obx_int.ModelProperty(
            id: const obx_int.IdUid(3, 8344290899505051100),
            name: 'finalTime',
            type: 10,
            flags: 0)
      ],
      relations: <obx_int.ModelRelation>[],
      backlinks: <obx_int.ModelBacklink>[]),
  obx_int.ModelEntity(
      id: const obx_int.IdUid(4, 3624636574726604689),
      name: 'RankedThing',
      lastPropertyId: const obx_int.IdUid(3, 5705228549106420783),
      flags: 0,
      properties: <obx_int.ModelProperty>[
        obx_int.ModelProperty(
            id: const obx_int.IdUid(1, 4261564895852394679),
            name: 'id',
            type: 6,
            flags: 1),
        obx_int.ModelProperty(
            id: const obx_int.IdUid(2, 2739063483213758185),
            name: 'order',
            type: 6,
            flags: 0),
        obx_int.ModelProperty(
            id: const obx_int.IdUid(3, 5705228549106420783),
            name: 'thingId',
            type: 11,
            flags: 520,
            indexId: const obx_int.IdUid(1, 7303701840037303071),
            relationTarget: 'Thing')
      ],
      relations: <obx_int.ModelRelation>[],
      backlinks: <obx_int.ModelBacklink>[]),
  obx_int.ModelEntity(
      id: const obx_int.IdUid(5, 3534494805469766675),
      name: 'Thing',
      lastPropertyId: const obx_int.IdUid(7, 5163927671201236105),
      flags: 0,
      properties: <obx_int.ModelProperty>[
        obx_int.ModelProperty(
            id: const obx_int.IdUid(1, 8491193594695295887),
            name: 'id',
            type: 6,
            flags: 1),
        obx_int.ModelProperty(
            id: const obx_int.IdUid(2, 8915662527189686512),
            name: 'content',
            type: 9,
            flags: 0),
        obx_int.ModelProperty(
            id: const obx_int.IdUid(3, 8845361712191555473),
            name: 'createdAt',
            type: 10,
            flags: 0),
        obx_int.ModelProperty(
            id: const obx_int.IdUid(4, 4489438415895978020),
            name: 'done',
            type: 1,
            flags: 0),
        obx_int.ModelProperty(
            id: const obx_int.IdUid(5, 3696488773815310160),
            name: 'rank',
            type: 6,
            flags: 0),
        obx_int.ModelProperty(
            id: const obx_int.IdUid(7, 5163927671201236105),
            name: 'category',
            type: 9,
            flags: 0)
      ],
      relations: <obx_int.ModelRelation>[
        obx_int.ModelRelation(
            id: const obx_int.IdUid(3, 5431818547799211746),
            name: 'children',
            targetId: const obx_int.IdUid(5, 3534494805469766675))
      ],
      backlinks: <obx_int.ModelBacklink>[
        obx_int.ModelBacklink(
            name: 'parents', srcEntity: 'Thing', srcField: 'children')
      ])
];

/// Shortcut for [obx.Store.new] that passes [getObjectBoxModel] and for Flutter
/// apps by default a [directory] using `defaultStoreDirectory()` from the
/// ObjectBox Flutter library.
///
/// Note: for desktop apps it is recommended to specify a unique [directory].
///
/// See [obx.Store.new] for an explanation of all parameters.
///
/// For Flutter apps, also calls `loadObjectBoxLibraryAndroidCompat()` from
/// the ObjectBox Flutter library to fix loading the native ObjectBox library
/// on Android 6 and older.
Future<obx.Store> openStore(
    {String? directory,
    int? maxDBSizeInKB,
    int? maxDataSizeInKB,
    int? fileMode,
    int? maxReaders,
    bool queriesCaseSensitiveDefault = true,
    String? macosApplicationGroup}) async {
  await loadObjectBoxLibraryAndroidCompat();
  return obx.Store(getObjectBoxModel(),
      directory: directory ?? (await defaultStoreDirectory()).path,
      maxDBSizeInKB: maxDBSizeInKB,
      maxDataSizeInKB: maxDataSizeInKB,
      fileMode: fileMode,
      maxReaders: maxReaders,
      queriesCaseSensitiveDefault: queriesCaseSensitiveDefault,
      macosApplicationGroup: macosApplicationGroup);
}

/// Returns the ObjectBox model definition for this project for use with
/// [obx.Store.new].
obx_int.ModelDefinition getObjectBoxModel() {
  final model = obx_int.ModelInfo(
      entities: _entities,
      lastEntityId: const obx_int.IdUid(5, 3534494805469766675),
      lastIndexId: const obx_int.IdUid(2, 5876970679639637568),
      lastRelationId: const obx_int.IdUid(3, 5431818547799211746),
      lastSequenceId: const obx_int.IdUid(0, 0),
      retiredEntityUids: const [1631627817501562807, 5074736434067970976],
      retiredIndexUids: const [5876970679639637568],
      retiredPropertyUids: const [
        2840272927915169489,
        958694595439191411,
        4544843419996755169,
        2568087456281045795,
        2964913559125229487,
        2451480565332523315,
        6682837070591412613,
        9035978168206840996,
        2750005277514529752,
        2546292154991111937
      ],
      retiredRelationUids: const [7142782651244064316],
      modelVersion: 5,
      modelVersionParserMinimum: 5,
      version: 1);

  final bindings = <Type, obx_int.EntityDefinition>{
    Event: obx_int.EntityDefinition<Event>(
        model: _entities[0],
        toOneRelations: (Event object) => [],
        toManyRelations: (Event object) => {},
        getId: (Event object) => object.id,
        setId: (Event object, int id) {
          object.id = id;
        },
        objectToFB: (Event object, fb.Builder fbb) {
          fbb.startTable(4);
          fbb.addInt64(0, object.id);
          fbb.addInt64(1, object.initialTime.millisecondsSinceEpoch);
          fbb.addInt64(2, object.finalTime.millisecondsSinceEpoch);
          fbb.finish(fbb.endTable());
          return object.id;
        },
        objectFromFB: (obx.Store store, ByteData fbData) {
          final buffer = fb.BufferContext(fbData);
          final rootOffset = buffer.derefObject(0);
          final initialTimeParam = DateTime.fromMillisecondsSinceEpoch(
              const fb.Int64Reader().vTableGet(buffer, rootOffset, 6, 0));
          final finalTimeParam = DateTime.fromMillisecondsSinceEpoch(
              const fb.Int64Reader().vTableGet(buffer, rootOffset, 8, 0));
          final object = Event(
              initialTime: initialTimeParam, finalTime: finalTimeParam)
            ..id = const fb.Int64Reader().vTableGet(buffer, rootOffset, 4, 0);

          return object;
        }),
    RankedThing: obx_int.EntityDefinition<RankedThing>(
        model: _entities[1],
        toOneRelations: (RankedThing object) => [object.thing],
        toManyRelations: (RankedThing object) => {},
        getId: (RankedThing object) => object.id,
        setId: (RankedThing object, int id) {
          object.id = id;
        },
        objectToFB: (RankedThing object, fb.Builder fbb) {
          fbb.startTable(4);
          fbb.addInt64(0, object.id);
          fbb.addInt64(1, object.order);
          fbb.addInt64(2, object.thing.targetId);
          fbb.finish(fbb.endTable());
          return object.id;
        },
        objectFromFB: (obx.Store store, ByteData fbData) {
          final buffer = fb.BufferContext(fbData);
          final rootOffset = buffer.derefObject(0);
          final orderParam =
              const fb.Int64Reader().vTableGet(buffer, rootOffset, 6, 0);
          final object = RankedThing(order: orderParam)
            ..id = const fb.Int64Reader().vTableGet(buffer, rootOffset, 4, 0);
          object.thing.targetId =
              const fb.Int64Reader().vTableGet(buffer, rootOffset, 8, 0);
          object.thing.attach(store);
          return object;
        }),
    Thing: obx_int.EntityDefinition<Thing>(
        model: _entities[2],
        toOneRelations: (Thing object) => [],
        toManyRelations: (Thing object) => {
              obx_int.RelInfo<Thing>.toMany(3, object.id): object.children,
              obx_int.RelInfo<Thing>.toManyBacklink(3, object.id):
                  object.parents
            },
        getId: (Thing object) => object.id,
        setId: (Thing object, int id) {
          object.id = id;
        },
        objectToFB: (Thing object, fb.Builder fbb) {
          final contentOffset = fbb.writeString(object.content);
          final categoryOffset = object.category == null
              ? null
              : fbb.writeString(object.category!);
          fbb.startTable(8);
          fbb.addInt64(0, object.id);
          fbb.addOffset(1, contentOffset);
          fbb.addInt64(2, object.createdAt.millisecondsSinceEpoch);
          fbb.addBool(3, object.done);
          fbb.addInt64(4, object.rank);
          fbb.addOffset(6, categoryOffset);
          fbb.finish(fbb.endTable());
          return object.id;
        },
        objectFromFB: (obx.Store store, ByteData fbData) {
          final buffer = fb.BufferContext(fbData);
          final rootOffset = buffer.derefObject(0);
          final contentParam = const fb.StringReader(asciiOptimization: true)
              .vTableGet(buffer, rootOffset, 6, '');
          final createdAtParam = DateTime.fromMillisecondsSinceEpoch(
              const fb.Int64Reader().vTableGet(buffer, rootOffset, 8, 0));
          final doneParam =
              const fb.BoolReader().vTableGet(buffer, rootOffset, 10, false);
          final categoryParam = const fb.StringReader(asciiOptimization: true)
              .vTableGetNullable(buffer, rootOffset, 16);
          final object = Thing(
              content: contentParam,
              createdAt: createdAtParam,
              done: doneParam,
              category: categoryParam)
            ..id = const fb.Int64Reader().vTableGet(buffer, rootOffset, 4, 0)
            ..rank =
                const fb.Int64Reader().vTableGet(buffer, rootOffset, 12, 0);
          obx_int.InternalToManyAccess.setRelInfo<Thing>(object.children, store,
              obx_int.RelInfo<Thing>.toMany(3, object.id));
          obx_int.InternalToManyAccess.setRelInfo<Thing>(object.parents, store,
              obx_int.RelInfo<Thing>.toManyBacklink(3, object.id));
          return object;
        })
  };

  return obx_int.ModelDefinition(model, bindings);
}

/// [Event] entity fields to define ObjectBox queries.
class Event_ {
  /// See [Event.id].
  static final id = obx.QueryIntegerProperty<Event>(_entities[0].properties[0]);

  /// See [Event.initialTime].
  static final initialTime =
      obx.QueryDateProperty<Event>(_entities[0].properties[1]);

  /// See [Event.finalTime].
  static final finalTime =
      obx.QueryDateProperty<Event>(_entities[0].properties[2]);
}

/// [RankedThing] entity fields to define ObjectBox queries.
class RankedThing_ {
  /// See [RankedThing.id].
  static final id =
      obx.QueryIntegerProperty<RankedThing>(_entities[1].properties[0]);

  /// See [RankedThing.order].
  static final order =
      obx.QueryIntegerProperty<RankedThing>(_entities[1].properties[1]);

  /// See [RankedThing.thing].
  static final thing =
      obx.QueryRelationToOne<RankedThing, Thing>(_entities[1].properties[2]);
}

/// [Thing] entity fields to define ObjectBox queries.
class Thing_ {
  /// See [Thing.id].
  static final id = obx.QueryIntegerProperty<Thing>(_entities[2].properties[0]);

  /// See [Thing.content].
  static final content =
      obx.QueryStringProperty<Thing>(_entities[2].properties[1]);

  /// See [Thing.createdAt].
  static final createdAt =
      obx.QueryDateProperty<Thing>(_entities[2].properties[2]);

  /// See [Thing.done].
  static final done =
      obx.QueryBooleanProperty<Thing>(_entities[2].properties[3]);

  /// See [Thing.rank].
  static final rank =
      obx.QueryIntegerProperty<Thing>(_entities[2].properties[4]);

  /// See [Thing.category].
  static final category =
      obx.QueryStringProperty<Thing>(_entities[2].properties[5]);

  /// see [Thing.children]
  static final children =
      obx.QueryRelationToMany<Thing, Thing>(_entities[2].relations[0]);
}
