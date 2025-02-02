import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'room_name_constraint.dart';
import 'room_name_constraint_type.dart';

import 'package:jitsi_meet_platform_interface/jitsi_meet_platform_interface.dart';

export 'package:jitsi_meet_platform_interface/jitsi_meet_platform_interface.dart'
    show
        JitsiMeetingOptions,
        JitsiMeetingResponse,
        JitsiMeetingListener,
        JitsiGenericListener,
        FeatureFlagHelper,
        FeatureFlagEnum;

class JitsiMeet {
  //static const MethodChannel _channel = const MethodChannel('jitsi_meet');
  //static const EventChannel _eventChannel =
  //  const EventChannel('jitsi_meet_events');

  //static List<JitsiMeetingListener> _listeners = <JitsiMeetingListener>[];
  //static Map<String, JitsiMeetingListener> _perMeetingListeners = {};
  static bool _hasInitialized = false;

  static final Map<RoomNameConstraintType, RoomNameConstraint>
      defaultRoomNameConstraints = {
    RoomNameConstraintType.MIN_LENGTH: new RoomNameConstraint((value) {
      return value.trim().length >= 3;
    }, "Minimum room length is 3"),

//    RoomNameConstraintType.MAX_LENGTH : new RoomNameConstraint(
//            (value) { return value.trim().length <= 50; },
//            "Maximum room length is 50"),

    RoomNameConstraintType.ALLOWED_CHARS: new RoomNameConstraint((value) {
      return RegExp(r"^[a-zA-Z0-9-_]+$", caseSensitive: false, multiLine: false)
          .hasMatch(value);
    }, "Only alphanumeric, dash, and underscore chars allowed"),

//    RoomNameConstraintType.FORBIDDEN_CHARS : new RoomNameConstraint(
//            (value) { return RegExp(r"[\\\/]+", caseSensitive: false, multiLine: false).hasMatch(value) == false; },
//            "Slash and anti-slash characters are forbidden"),
  };

  /// Joins a meeting based on the JitsiMeetingOptions passed in.
  /// A JitsiMeetingListener can be attached to this meeting that will automatically
  /// be removed when the meeting has ended
  static Future<JitsiMeetingResponse> joinMeeting(JitsiMeetingOptions options,
      {JitsiMeetingListener listener,
      Map<RoomNameConstraintType, RoomNameConstraint>
          roomNameConstraints}) async {
    assert(options != null, "options are null");
    assert(options.room != null, "room is null");
    assert(options.room.trim().isNotEmpty, "room is empty");

    // If no constraints given, take default ones
    // (To avoid using constraint, just give an empty Map)
    if (roomNameConstraints == null) {
      roomNameConstraints = defaultRoomNameConstraints;
    }

    // Check each constraint, if it exist
    // (To avoid using constraint, just give an empty Map)
    if (roomNameConstraints.isNotEmpty) {
      for (RoomNameConstraint constraint in roomNameConstraints.values) {
        assert(
            constraint.checkConstraint(options.room), constraint.getMessage());
      }
    }

    // Validate serverURL is absolute if it is not null or empty
    if (options.serverURL?.isNotEmpty ?? false) {
      assert(Uri.parse(options.serverURL).isAbsolute,
          "URL must be of the format <scheme>://<host>[/path], like https://someHost.com");
    }

    /* // Attach a listener if it exists. The key is based on the serverURL + room
    if (listener != null) {
      String serverURL = options.serverURL ?? "https://meet.jit.si";
      String key;
      if (serverURL.endsWith("/")) {
        key = serverURL + options.room;
      } else {
        key = serverURL + "/" + options.room;
      }

      _perMeetingListeners.update(key, (oldListener) => listener,
          ifAbsent: () => listener);
      _initialize();
    } */

    /* return await _channel
        .invokeMethod<String>('joinMeeting', <String, dynamic>{
          'room': options.room?.trim(),
          'serverURL': options.serverURL?.trim(),
          'subject': options.subject,
          'token': options.token,
          'audioMuted': options.audioMuted,
          'audioOnly': options.audioOnly,
          'videoMuted': options.videoMuted,
          'featureFlags': options.getFeatureFlags(),
          'userDisplayName': options.userDisplayName,
          'userEmail': options.userEmail,
          'userAvatarURL': options.userAvatarURL,
        })
        .then((message) =>
            JitsiMeetingResponse(isSuccess: true, message: message))
        .catchError((error) {
          debugPrint("error: $error, type: ${error.runtimeType}");
          return JitsiMeetingResponse(
              isSuccess: false, message: error.toString(), error: error);
        }); */

    return await JitsiMeetPlatform.instance
        .joinMeeting(options, listener: listener);
  }

  /// Initializes the event channel. Call when listeners are added
  static _initialize() {
    if (!_hasInitialized) {
      debugPrint('Jitsi Meet - initializing event channel');
      JitsiMeetPlatform.instance.initialize();
      _hasInitialized = true;
    }
  }

  static closeMeeting() => JitsiMeetPlatform.instance.closeMeeting();

  /// Adds a JitsiMeetingListener that will broadcast conference events
  static addListener(JitsiMeetingListener jitsiMeetingListener) {
    debugPrint('Jitsi Meet - addListener');
    JitsiMeetPlatform.instance.addListener(jitsiMeetingListener);
    _initialize();
  }

  /// Removes the JitsiMeetingListener specified
  static removeListener(JitsiMeetingListener jitsiMeetingListener) {
    JitsiMeetPlatform.instance.removeListener(jitsiMeetingListener);
  }

  /// Removes all JitsiMeetingListeners
  static removeAllListeners() {
    JitsiMeetPlatform.instance.removeAllListeners();
  }

  /// allow execute a command over a Jitsi live session (only for web)
  static executeCommand(String command, List<String> args) {
    JitsiMeetPlatform.instance.executeCommand(command, args);
  }
}

/// Allow create a interface for web view and attach it as a child
/// optional param `extraJS` allows setup another external JS libraries
/// or Javascript embebed code
class JitsiMeetConferencing extends StatelessWidget {
  final List<String> extraJS;
  JitsiMeetConferencing({this.extraJS});

  @override
  Widget build(BuildContext context) {
    return JitsiMeetPlatform.instance.buildView(extraJS);
  }
}

/// Initializes the event channel. Call when listeners are added
/*  static _initialize() {
    if (!_hasInitialized) {
      debugPrint('Jitsi Meet - initializing event channel');
      _eventChannel.receiveBroadcastStream().listen((dynamic message) {
        debugPrint('Jitsi Meet - broadcast event: $message');
        _broadcastToGlobalListeners(message);
        _broadcastToPerMeetingListeners(message);
      }, onError: (dynamic error) {
        debugPrint('Jitsi Meet broadcast error: $error');
        _listeners.forEach((listener) {
          if (listener.onError != null) listener.onError(error);
        });
        _perMeetingListeners.forEach((key, listener) {
          if (listener.onError != null) listener.onError(error);
        });
      });
      _hasInitialized = true;
    }
  } */

/*  static closeMeeting() {
    _channel.invokeMethod('closeMeeting');
  }

  /// Adds a JitsiMeetingListener that will broadcast conference events
  static addListener(JitsiMeetingListener jitsiMeetingListener) {
    debugPrint('Jitsi Meet - addListener');
    _listeners.add(jitsiMeetingListener);
    _initialize();
  }

  /// Sends a broadcast to global listeners added using addListener
  static void _broadcastToGlobalListeners(message) {
    _listeners.forEach((listener) {
      switch (message['event']) {
        case "onConferenceWillJoin":
          if (listener.onConferenceWillJoin != null)
            listener.onConferenceWillJoin(message: message);
          break;
        case "onConferenceJoined":
          if (listener.onConferenceJoined != null)
            listener.onConferenceJoined(message: message);
          break;
        case "onConferenceTerminated":
          if (listener.onConferenceTerminated != null)
            listener.onConferenceTerminated(message: message);
          break;
        case "onPictureInPictureWillEnter":
          if (listener.onPictureInPictureWillEnter != null)
            listener.onPictureInPictureWillEnter(message: message);
          break;
        case "onPictureInPictureTerminated":
          if (listener.onPictureInPictureTerminated != null)
            listener.onPictureInPictureTerminated(message: message);
          break;
      }
    });
  }

  /// Sends a broadcast to per meeting listeners added during joinMeeting
  static void _broadcastToPerMeetingListeners(message) {
    String url = message['url'];
    final listener = _perMeetingListeners[url];
    if (listener != null) {
      switch (message['event']) {
        case "onConferenceWillJoin":
          if (listener.onConferenceWillJoin != null)
            listener.onConferenceWillJoin(message: message);
          break;
        case "onConferenceJoined":
          if (listener.onConferenceJoined != null)
            listener.onConferenceJoined(message: message);
          break;
        case "onConferenceTerminated":
          if (listener.onConferenceTerminated != null)
            listener.onConferenceTerminated(message: message);

          // Remove the listener from the map of _perMeetingListeners on terminate
          _perMeetingListeners.remove(listener);
          break;
        case "onPictureInPictureWillEnter":
          if (listener.onPictureInPictureWillEnter != null)
            listener.onPictureInPictureWillEnter(message: message);
          break;
        case "onPictureInPictureTerminated":
          if (listener.onPictureInPictureTerminated != null)
            listener.onPictureInPictureTerminated(message: message);
          break;
      }
    }
  }

  /// Removes the JitsiMeetingListener specified
  static removeListener(JitsiMeetingListener jitsiMeetingListener) {
    _listeners.remove(jitsiMeetingListener);
  }

  /// Removes all JitsiMeetingListeners
  static removeAllListeners() {
    _listeners.clear();
  }
} */
