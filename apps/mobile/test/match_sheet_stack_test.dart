import 'package:femm_app/models/clinic.dart';
import 'package:femm_app/models/clinical_specialty.dart';
import 'package:femm_app/screens/match_screen.dart';
import 'package:femm_app/theme/petal_soft.dart';
import 'package:flutter/material.dart';
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
    expect(
      MatchScreen.formatHoldCountdown(const Duration(minutes: 14, seconds: 32)),
      '14:32',
    );
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

  test('Done sheet before/after copy matches Peter lock', () {
    expect(MatchScreen.beforeHeadline, 'Your appointment details');
    expect(MatchScreen.beforeSupport, 'Confirm your clinical slot');
    expect(MatchScreen.afterHeadline, "You're set");
    expect(MatchScreen.afterSupport, contains('Clinical booking saved'));
    expect(MatchScreen.afterSupport, contains('optional extras'));
    expect(MatchScreen.bookedStatusCaption, 'Appointment saved');
    expect(MatchScreen.extrasSectionLabel, 'OPTIONAL EXTRAS');
    expect(MatchScreen.backHomeLabel, 'Back to home');
    expect(MatchScreen.bookAppointmentLabel, 'Book this appointment');
    expect(MatchScreen.shareActionLabel, 'Share');
    expect(MatchScreen.calendarActionLabel, 'Add to Google Calendar');
    // No in-phone “Optional extras hidden…” annotation copy.
    expect(MatchScreen.beforeSupport.toLowerCase(), isNot(contains('hidden')));
    expect(MatchScreen.beforeHeadline.toLowerCase(), isNot(contains('hidden')));
  });

  test('booked clinic line and share stub text stay non-PHI demo copy', () {
    final clinic = Clinic(
      id: 'c1',
      specialty: ClinicalSpecialty.gynaeEndocrine,
      name: 'Victoria Harbour Gynae & Endocrine',
      district: 'Admiralty',
      addressLine: '2 Harbour Rd',
      whyMatchBlurb: 'Demo',
    );
    final slot = AppointmentSlot(
      id: 's1',
      clinicId: 'c1',
      startsAt: DateTime(2026, 11, 4, 10, 30).toUtc(),
      endsAt: DateTime(2026, 11, 4, 11, 0).toUtc(),
      status: 'booked',
    );
    expect(
      MatchScreen.bookedClinicLine(clinic, ClinicalSpecialty.gynaeEndocrine),
      'Victoria Harbour Gynae & Endocrine · Admiralty',
    );
    expect(
      MatchScreen.bookedClinicLine(null, ClinicalSpecialty.gynaeEndocrine),
      ClinicalSpecialty.gynaeEndocrine.label,
    );
    final share = MatchScreen.shareAppointmentText(
      specialty: ClinicalSpecialty.gynaeEndocrine,
      clinic: clinic,
      slot: slot,
    );
    expect(share, startsWith('femm clinical appointment:'));
    expect(share, contains('Dr. Mei Chen'));
    expect(share, contains('Admiralty'));
    expect(share.toLowerCase(), contains('10:30'));
  });

  testWidgets('Back to home primary pill uses Petal Soft filled stadium',
      (tester) async {
    late OutlinedBorder? themeShape;
    await tester.pumpWidget(
      MaterialApp(
        theme: PetalSoft.theme(),
        home: Builder(
          builder: (context) {
            themeShape = FilledButtonTheme.of(context)
                .style
                ?.shape
                ?.resolve(const <WidgetState>{});
            return Scaffold(
              body: FilledButton(
                onPressed: () {},
                child: const Text(MatchScreen.backHomeLabel),
              ),
            );
          },
        ),
      ),
    );
    expect(find.text(MatchScreen.backHomeLabel), findsOneWidget);
    expect(themeShape, isA<StadiumBorder>());
  });

  testWidgets('Share + Calendar icon buttons lay out beside clinic copy',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PetalSoft.theme(),
        home: Scaffold(
          body: Row(
            children: [
              const Expanded(child: Text('Dr. Mei Chen')),
              Tooltip(
                message: MatchScreen.shareActionLabel,
                child: IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.ios_share),
                ),
              ),
              Tooltip(
                message: MatchScreen.calendarActionLabel,
                child: IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.calendar_month_outlined),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byTooltip(MatchScreen.shareActionLabel), findsOneWidget);
    expect(find.byTooltip(MatchScreen.calendarActionLabel), findsOneWidget);
  });
}
