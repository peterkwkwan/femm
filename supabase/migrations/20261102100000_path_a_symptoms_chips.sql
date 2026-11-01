-- Path A UX: symptoms multi-select chips map into path_a_survey_answers.
-- Keeps existing table shape; Path C snapshot exposes goals.symptoms for packs.
-- Apply after Phase 5. See docs/phase3-spend-survey.md.

comment on table public.path_a_survey_answers is
  'Path A intake answers. After symptoms-chip UX: one row per selected symptom '
  '(question_key = chip key, answer = label) plus optional primary_goal derived '
  'from rule-based match for Path C. Legacy ≤8-question rows may still exist.';

comment on table public.path_a_sessions is
  'Path A intake session tied to a confirmed lab PDF. Match requires spend + '
  'symptoms (survey_completed_at) complete.';

-- ---------------------------------------------------------------------------
-- Path C snapshot: include symptoms[] alongside primary_goal + answers
-- ---------------------------------------------------------------------------
create or replace function public._path_c_session_snapshot(p_session_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_session public.path_a_sessions%rowtype;
  v_doc public.lab_documents%rowtype;
  v_goals jsonb := '{}'::jsonb;
  v_answers jsonb := '{}'::jsonb;
  v_symptoms jsonb := '[]'::jsonb;
  v_spend jsonb := '[]'::jsonb;
  v_flagged jsonb := '[]'::jsonb;
  v_labs jsonb := '[]'::jsonb;
  v_match_reason text;
  v_patient_email text;
  v_patient_display_name text;
  r record;
begin
  select * into v_session
  from public.path_a_sessions
  where id = p_session_id;

  if not found then
    raise exception 'session not found';
  end if;

  select * into v_doc
  from public.lab_documents
  where id = v_session.lab_document_id;

  select p.email, p.display_name
  into v_patient_email, v_patient_display_name
  from public.profiles p
  where p.id = v_session.user_id;

  for r in
    select question_key, answer
    from public.path_a_survey_answers
    where session_id = p_session_id
    order by question_key
  loop
    v_answers := v_answers || jsonb_build_object(r.question_key, r.answer);
    if r.question_key is distinct from 'primary_goal' then
      v_symptoms := v_symptoms || to_jsonb(r.answer);
    end if;
  end loop;

  v_goals := jsonb_build_object(
    'primary_goal', coalesce(v_answers->>'primary_goal', ''),
    'symptoms', v_symptoms,
    'answers', v_answers
  );

  select coalesce(jsonb_agg(s.spend_bucket::text order by s.spend_bucket::text), '[]'::jsonb)
  into v_spend
  from public.path_a_spend_selections s
  where s.session_id = p_session_id;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'name', b.name,
        'value', b.value,
        'unit', b.unit,
        'ref_range', b.ref_range,
        'flag', b.flag,
        'sort_order', b.sort_order
      )
      order by b.sort_order, b.name
    ),
    '[]'::jsonb
  )
  into v_labs
  from public.lab_biomarker_rows b
  where b.lab_document_id = v_session.lab_document_id
    and b.is_deleted = false;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'name', b.name,
        'value', b.value,
        'unit', b.unit,
        'ref_range', b.ref_range,
        'flag', b.flag,
        'sort_order', b.sort_order
      )
      order by b.sort_order, b.name
    ),
    '[]'::jsonb
  )
  into v_flagged
  from public.lab_biomarker_rows b
  where b.lab_document_id = v_session.lab_document_id
    and b.is_deleted = false
    and b.flag in ('H', 'L');

  select m.why_copy into v_match_reason
  from public.path_a_matches m
  where m.session_id = p_session_id;

  return jsonb_build_object(
    'session_id', v_session.id,
    'user_id', v_session.user_id,
    'lab_document_id', v_session.lab_document_id,
    'storage_path', v_doc.storage_path,
    'original_filename', v_doc.original_filename,
    'patient_email', v_patient_email,
    'patient_display_name', v_patient_display_name,
    'goals', v_goals,
    'spend_buckets', v_spend,
    'match_reason', v_match_reason,
    'flagged_labs', v_flagged,
    'labs', v_labs
  );
end;
$$;

revoke all on function public._path_c_session_snapshot(uuid) from public;

comment on function public._path_c_session_snapshot(uuid) is
  'Path C internal: gather goals (primary_goal + symptoms[] + answers), spend, labs snapshot.';
