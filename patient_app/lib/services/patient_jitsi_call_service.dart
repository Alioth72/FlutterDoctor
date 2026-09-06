import 'package:flutter/material.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';

import '../data/patient_appointment_repository.dart';
import '../models/patient_appointment.dart';
import '../models/patient_call_log.dart';
import '../screens/patient_call_ended_screen.dart';

Future<void> startPatientCall({
  required BuildContext context,
  required PatientAppointment appointment,
  required PatientAppointmentRepository repository,
}) async {
  final callLog = PatientCallLog(appointmentId: appointment.id);
  final jitsiMeet = JitsiMeet();
  var callEndedScreenOpened = false;

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
    userInfo: JitsiMeetUserInfo(displayName: appointment.patientName),
  );

  await jitsiMeet.join(
    options,
    JitsiMeetEventListener(
      conferenceWillJoin: (url) async {
        callLog.startedAt = DateTime.now();
        await repository.updateAppointmentStatus(
          appointment.id,
          PatientAppointmentStatus.inCall,
        );
      },
      conferenceTerminated: (url, error) async {
        callLog.endedAt = DateTime.now();
        callLog.hadError = error != null;
        await repository.saveCallLog(callLog);
        await repository.updateAppointmentStatus(
          appointment.id,
          error == null
              ? PatientAppointmentStatus.completed
              : PatientAppointmentStatus.missed,
        );
      },
      readyToClose: () {
        if (callEndedScreenOpened || !context.mounted) return;
        callEndedScreenOpened = true;
        Navigator.of(context).pushReplacement<void, void>(
          MaterialPageRoute(
            builder: (_) => PatientCallEndedScreen(
              appointment: appointment,
              callLog: callLog,
            ),
          ),
        );
      },
    ),
  );
}
