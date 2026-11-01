-- Phase 3: Path A spend multi-select + survey answers (≤8 Qs).
-- Apply after Phase 2 lab_documents migration. See docs/phase3-spend-survey.md.
-- Reuses public.spend_bucket enum from Phase 1.

-- ---------------------------------------------------------------------------
-- path_a_sessions: one intake per confirmed lab document
-- ---------------------------------------------------------------------------
create table if not exists public.path_a_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  lab_document_id uuid not null references public.lab_documents (id) on delete cascade,
  spend_completed_at timestamptz,
  survey_completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint path_a_sessions_lab_document_unique unique (lab_document_id)
);

create index if not exists path_a_sessions_user_id_idx
  on public.path_a_sessions (user_id, created_at desc);

alter table public.path_a_sessions enable row level security;

drop policy if exists "path_a_sessions_select_own" on public.path_a_sessions;
create policy "path_a_sessions_select_own"
  on public.path_a_sessions for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "path_a_sessions_insert_own" on public.path_a_sessions;
create policy "path_a_sessions_insert_own"
  on public.path_a_sessions for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "path_a_sessions_update_own" on public.path_a_sessions;
create policy "path_a_sessions_update_own"
  on public.path_a_sessions for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "path_a_sessions_delete_own" on public.path_a_sessions;
create policy "path_a_sessions_delete_own"
  on public.path_a_sessions for delete
  to authenticated
  using (auth.uid() = user_id);

comment on table public.path_a_sessions is
  'Phase 3 Path A intake session tied to a confirmed lab PDF. Match (Phase 4) requires spend + survey complete.';

-- ---------------------------------------------------------------------------
-- path_a_spend_selections: multi-select of locked spend buckets (≥1 in app)
-- ---------------------------------------------------------------------------
create table if not exists public.path_a_spend_selections (
  session_id uuid not null references public.path_a_sessions (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  spend_bucket public.spend_bucket not null,
  created_at timestamptz not null default now(),
  primary key (session_id, spend_bucket)
);

create index if not exists path_a_spend_selections_user_id_idx
  on public.path_a_spend_selections (user_id);

alter table public.path_a_spend_selections enable row level security;

drop policy if exists "path_a_spend_selections_select_own" on public.path_a_spend_selections;
create policy "path_a_spend_selections_select_own"
  on public.path_a_spend_selections for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "path_a_spend_selections_insert_own" on public.path_a_spend_selections;
create policy "path_a_spend_selections_insert_own"
  on public.path_a_spend_selections for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "path_a_spend_selections_delete_own" on public.path_a_spend_selections;
create policy "path_a_spend_selections_delete_own"
  on public.path_a_spend_selections for delete
  to authenticated
  using (auth.uid() = user_id);

comment on table public.path_a_spend_selections is
  'Phase 3 locked spend buckets the user already spends on (upsell keys). Multi-select; app requires ≥1.';

-- ---------------------------------------------------------------------------
-- path_a_survey_answers: ≤8 clinical + skin/hair questions
-- ---------------------------------------------------------------------------
create table if not exists public.path_a_survey_answers (
  session_id uuid not null references public.path_a_sessions (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  question_key text not null,
  answer text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (session_id, question_key),
  constraint path_a_survey_answers_question_key_nonempty
    check (char_length(question_key) > 0),
  constraint path_a_survey_answers_answer_nonempty
    check (char_length(answer) > 0)
);

create index if not exists path_a_survey_answers_user_id_idx
  on public.path_a_survey_answers (user_id);

alter table public.path_a_survey_answers enable row level security;

drop policy if exists "path_a_survey_answers_select_own" on public.path_a_survey_answers;
create policy "path_a_survey_answers_select_own"
  on public.path_a_survey_answers for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "path_a_survey_answers_insert_own" on public.path_a_survey_answers;
create policy "path_a_survey_answers_insert_own"
  on public.path_a_survey_answers for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "path_a_survey_answers_update_own" on public.path_a_survey_answers;
create policy "path_a_survey_answers_update_own"
  on public.path_a_survey_answers for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "path_a_survey_answers_delete_own" on public.path_a_survey_answers;
create policy "path_a_survey_answers_delete_own"
  on public.path_a_survey_answers for delete
  to authenticated
  using (auth.uid() = user_id);

comment on table public.path_a_survey_answers is
  'Phase 3 survey answers (≤8 clinical + skin/hair keys). Feeds Phase 4 rule-based match.';
