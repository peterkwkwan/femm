/// Locked ≤8 Path A survey questions (clinical routing + skin/hair).
/// Answers feed Phase 4 rule-based match — no LLM.
class SurveyQuestion {
  const SurveyQuestion({
    required this.key,
    required this.prompt,
    required this.options,
  });

  final String key;
  final String prompt;
  final List<String> options;
}

/// Exactly eight questions — clinical symptoms/goals + skin/hair.
const List<SurveyQuestion> kSurveyQuestions = <SurveyQuestion>[
  SurveyQuestion(
    key: 'primary_goal',
    prompt: 'What do you most want help with right now?',
    options: <String>[
      'General midlife / menopause navigation',
      'Hormones / cycle / gynae review',
      'Sleep or mood',
      'Bone or heart risk concerns',
    ],
  ),
  SurveyQuestion(
    key: 'hot_flushes',
    prompt: 'How bothersome are hot flushes or night sweats?',
    options: <String>[
      'Not an issue',
      'Mild',
      'Moderate',
      'Severe',
    ],
  ),
  SurveyQuestion(
    key: 'sleep',
    prompt: 'How is your sleep lately?',
    options: <String>[
      'Fine',
      'Occasionally disrupted',
      'Often poor',
      'Consistently difficult',
    ],
  ),
  SurveyQuestion(
    key: 'mood',
    prompt: 'Mood, anxiety, or irritability?',
    options: <String>[
      'Stable',
      'Mild changes',
      'Often affected',
      'A main concern',
    ],
  ),
  SurveyQuestion(
    key: 'cycle_bleeding',
    prompt: 'Cycle or bleeding changes you want reviewed?',
    options: <String>[
      'No / not relevant',
      'Mild changes',
      'Noticeable changes',
      'Urgent to discuss',
    ],
  ),
  SurveyQuestion(
    key: 'bone_heart',
    prompt: 'Interest in bone or heart-risk discussion?',
    options: <String>[
      'Not now',
      'Somewhat interested',
      'Yes, a priority',
      'Labs already flagged concern',
    ],
  ),
  SurveyQuestion(
    key: 'skin',
    prompt: 'Skin changes (dryness, itch, flush, texture)?',
    options: <String>[
      'None',
      'Mild',
      'Moderate',
      'A main concern',
    ],
  ),
  SurveyQuestion(
    key: 'hair',
    prompt: 'Hair thinning or texture changes?',
    options: <String>[
      'None',
      'Mild',
      'Moderate',
      'A main concern',
    ],
  ),
];
