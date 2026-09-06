import 'package:flutter/material.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';

import '../data/appointment_repository.dart';
import '../models/appointment.dart';
import '../models/call_log.dart';
import '../screens/post_call_screen.dart';

Future<void> startCall({
  required BuildContext context,
  required Appointment appointment,
  required AppointmentRepository repository,
  required String doctorName,
}) async {
  final callLog = CallLog(appointmentId: appointment.id);
  final jitsiMeet = JitsiMeet();
  var postCallOpened = false;

  final options = JitsiMeetConferenceOptions(
    serverURL: 'https://meet.jit.si',
    room: 'consult_${appointment.id}',
    configOverrides: const {
      'startWithAudioMuted': false,
      'startWithVideoMuted': false,
      'subject': 'Consultation',
      'prejoinPageEnabled': false,
    },
    featureFlags: const {
      'chat.enabled': false,
      'invite.enabled': false,
      'add-people.enabled': false,
      'calendar.enabled': false,
      'live-streaming.enabled': false,
      'recording.enabled': false,
      'meeting-name.enabled': false,
      'meeting-password.enabled': false,
      'raise-hand.enabled': false,
      'tile-view.enabled': false,
      'pip.enabled': true,
    },
    userInfo: JitsiMeetUserInfo(displayName: doctorName),
  );

  await jitsiMeet.join(
    options,
    JitsiMeetEventListener(
      conferenceWillJoin: (url) async {
        callLog.startedAt = DateTime.now();
        await repository.updateAppointmentStatus(
          appointment.id,
          AppointmentStatus.inCall,
        );
      },
      conferenceTerminated: (url, error) async {
        callLog.endedAt = DateTime.now();
        callLog.hadError = error != null;
        await repository.saveCallLog(callLog);
        await repository.updateAppointmentStatus(
          appointment.id,
          error == null
              ? AppointmentStatus.completed
              : AppointmentStatus.missed,
        );
      },
      readyToClose: () {
        if (postCallOpened || !context.mounted) return;
        postCallOpened = true;
        Navigator.of(context).pushReplacement<void, void>(
          MaterialPageRoute(
            builder: (_) => PostCallScreen(
              appointment: appointment,
              callLog: callLog,
              repository: repository,
            ),
          ),
        );
      },
    ),
  );
}
