import 'package:femm_app/models/clinic.dart';
import 'package:femm_app/models/clinical_specialty.dart';
import 'package:femm_app/screens/match_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('demo doctor names are specialty-stable fakes', () {
    expect(
      MatchScreen.demoDoctorName(ClinicalSpecialty.gynaeEndocrine),
      'Dr. Mei Chen',
    );
    expect(
      MatchScreen.demoDoctorName(ClinicalSpecialty.menopauseAwareGp),
      'Dr. Ava Wong',
    );
    expect(
      MatchScreen.demoDoctorName(ClinicalSpecialty.sleepMood),
      'Dr. Priya Shah',
    );
    expect(
      MatchScreen.demoDoctorName(ClinicalSpecialty.boneHeartRisk),
      'Dr. Leo Tan',
    );
  });

  test('slot label uses am/pm local time', () {
    final morning = AppointmentSlot(
      id: 's1',
      clinicId: 'c1',
      startsAt: DateTime(2026, 11, 4, 10, 30).toUtc(),
      endsAt: DateTime(2026, 11, 4, 11, 0).toUtc(),
      status: 'held',
    );
    final morningLabel = MatchScreen.formatSlotAmPm(morning);
    expect(morningLabel, contains('4 Nov'));
    expect(morningLabel.toLowerCase(), contains('10:30'));
    expect(morningLabel.toLowerCase(), contains('am'));
    expect(morningLabel, isNot(contains('(local)')));

    final evening = AppointmentSlot(
      id: 's2',
      clinicId: 'c1',
      startsAt: DateTime(2026, 11, 4, 15, 0).toUtc(),
      endsAt: DateTime(2026, 11, 4, 15, 30).toUtc(),
      status: 'held',
    );
    expect(MatchScreen.formatSlotAmPm(evening).toLowerCase(), contains('pm'));
    expect(MatchScreen.formatSlotAmPm(null), 'Slot unavailable');
  });

  test('clinical header label uses Clinical booking while hold is alive', () {
    expect(
      MatchScreen.clinicalHeaderLabel(booked: false, holdAlive: true),
      'Clinical booking',
    );
    expect(
      MatchScreen.clinicalHeaderLabel(booked: true, holdAlive: false),
      'Clinical · booked',
    );
    expect(
      MatchScreen.clinicalHeaderLabel(booked: false, holdAlive: false),
      'Clinical',
    );
  });

  test('hold countdown caption prefixes live mm:ss', () {
    expect(MatchScreen.formatHoldCountdown(const Duration(minutes: 14, seconds: 32)), '14:32');
    expect(MatchScreen.formatHoldCountdown(Duration.zero), '00:00');
    expect(
      MatchScreen.holdCountdownCaption(const Duration(minutes: 9, seconds: 5)),
      'Current booking held for: 09:05',
    );
    expect(
      MatchScreen.holdCountdownCaption(const Duration(seconds: -3)),
      'Current booking held for: 00:00',
    );
  });
}
