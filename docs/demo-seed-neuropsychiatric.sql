-- ============================================================
-- Metromind Hospital — Neuropsychiatric demo pipeline seed
-- ============================================================
-- Run this ONCE in the Supabase Dashboard → SQL Editor.
-- Not a migration — it is data, not schema, and it is NOT picked
-- up by `supabase/migrations/` or the CI migration replay.
--
-- WHAT THIS DOES
--   1. Finds your account via your login email (edit the line
--      below marked "EDIT ME").
--   2. Shows you what's currently in your pipelines so you can
--      confirm before anything is deleted (Section A is a
--      SELECT-only preview — nothing is removed until Section B).
--   3. Deletes every existing deal/pipeline for your account
--      (Section B) — this removes the old generic demo cards.
--   4. Creates one fresh "Patient Journey" pipeline with the
--      standard 5-stage flow and seeds it with 10 neuropsychiatric
--      patient cases spanning Psychiatry, Neurology, Child &
--      Adolescent Psychiatry, and De-addiction (Section C).
--
-- SAFETY: this deletes ALL pipelines/deals for the matched
-- account. If you have real (non-demo) patient cases already in
-- the system, stop after Section A and do NOT run Section B.
-- ============================================================

-- ------------------------------------------------------------
-- EDIT ME: this script is written for the Supabase Dashboard's
-- web SQL Editor, which does not support psql \set variables —
-- so instead, use Find & Replace (Ctrl/Cmd+F in the editor, or
-- in your own text editor before pasting) to replace every
-- occurrence of YOUR_LOGIN_EMAIL_HERE below with the email you
-- log into the CRM with. There are 3 occurrences total.
-- ------------------------------------------------------------

-- ============================================================
-- SECTION A — PREVIEW (read-only, safe to run any time)
-- ============================================================
SELECT p.id AS pipeline_id, p.name AS pipeline_name,
       count(d.id) AS deal_count
FROM pipelines p
JOIN profiles pr ON pr.account_id = p.account_id
LEFT JOIN deals d ON d.pipeline_id = p.id
WHERE pr.email = 'YOUR_LOGIN_EMAIL_HERE'
GROUP BY p.id, p.name;

-- Review the output above. Only continue to Section B once
-- you've confirmed it's safe to delete those pipelines.

-- ============================================================
-- SECTION B — DELETE existing pipelines/deals for this account
-- ============================================================
DO $$
DECLARE
  v_account_id UUID;
BEGIN
  SELECT account_id INTO v_account_id
  FROM profiles
  WHERE email = 'YOUR_LOGIN_EMAIL_HERE';

  IF v_account_id IS NULL THEN
    RAISE EXCEPTION 'No account found for that email — check EDIT ME above';
  END IF;

  DELETE FROM deals WHERE account_id = v_account_id;
  DELETE FROM pipeline_stages WHERE pipeline_id IN (
    SELECT id FROM pipelines WHERE account_id = v_account_id
  );
  DELETE FROM pipelines WHERE account_id = v_account_id;
END $$;

-- ============================================================
-- SECTION C — CREATE pipeline + seed neuropsychiatric demo cases
-- ============================================================
DO $$
DECLARE
  v_account_id  UUID;
  v_user_id     UUID;
  v_pipeline_id UUID;

  v_stage_inquiry   UUID;
  v_stage_booked    UUID;
  v_stage_consulted UUID;
  v_stage_planned   UUID;
  v_stage_admitted  UUID;

  v_contact_id UUID;
BEGIN
  SELECT account_id, user_id INTO v_account_id, v_user_id
  FROM profiles
  WHERE email = 'YOUR_LOGIN_EMAIL_HERE';

  IF v_account_id IS NULL THEN
    RAISE EXCEPTION 'No account found for that email — check EDIT ME above';
  END IF;

  -- Pipeline
  INSERT INTO pipelines (user_id, account_id, name)
  VALUES (v_user_id, v_account_id, 'Patient Journey')
  RETURNING id INTO v_pipeline_id;

  -- Stages (same 5-stage flow used across the app)
  INSERT INTO pipeline_stages (pipeline_id, name, color, position) VALUES
    (v_pipeline_id, 'New Inquiry',        '#3b82f6', 0)
    RETURNING id INTO v_stage_inquiry;
  INSERT INTO pipeline_stages (pipeline_id, name, color, position) VALUES
    (v_pipeline_id, 'Appointment Booked', '#8b5cf6', 1)
    RETURNING id INTO v_stage_booked;
  INSERT INTO pipeline_stages (pipeline_id, name, color, position) VALUES
    (v_pipeline_id, 'Consultation Done',  '#f97316', 2)
    RETURNING id INTO v_stage_consulted;
  INSERT INTO pipeline_stages (pipeline_id, name, color, position) VALUES
    (v_pipeline_id, 'Treatment Planned',  '#eab308', 3)
    RETURNING id INTO v_stage_planned;
  INSERT INTO pipeline_stages (pipeline_id, name, color, position) VALUES
    (v_pipeline_id, 'Admitted',           '#22c55e', 4)
    RETURNING id INTO v_stage_admitted;

  -- ------------------------------------------------------------
  -- Patient 1 — Anjali Menon, Psychiatry (Anxiety & insomnia)
  -- ------------------------------------------------------------
  INSERT INTO contacts (user_id, account_id, phone, name)
  VALUES (v_user_id, v_account_id, '919847123456', 'Anjali Menon')
  RETURNING id INTO v_contact_id;
  INSERT INTO deals (user_id, account_id, pipeline_id, stage_id, contact_id, title, value, currency, notes, expected_close_date, status)
  VALUES (v_user_id, v_account_id, v_pipeline_id, v_stage_inquiry, v_contact_id,
    'Psychiatry Consultation – Anjali Menon', 800, 'INR',
    'Anxiety and sleep disturbance for 2 months. Prefers a female doctor. WhatsApp preferred contact.',
    CURRENT_DATE + 4, 'open');

  -- ------------------------------------------------------------
  -- Patient 2 — Ravi Chandran, Neurology (Epilepsy / seizures)
  -- ------------------------------------------------------------
  INSERT INTO contacts (user_id, account_id, phone, name)
  VALUES (v_user_id, v_account_id, '919895567234', 'Ravi Chandran')
  RETURNING id INTO v_contact_id;
  INSERT INTO deals (user_id, account_id, pipeline_id, stage_id, contact_id, title, value, currency, notes, expected_close_date, status)
  VALUES (v_user_id, v_account_id, v_pipeline_id, v_stage_booked, v_contact_id,
    'Neurology Consultation – Ravi Chandran', 900, 'INR',
    'Recurrent seizure episodes over the last month, first-time evaluation. Bringing prior EEG report.',
    CURRENT_DATE + 2, 'open');

  -- ------------------------------------------------------------
  -- Patient 3 — Fathima Rasheed, Psychiatry (Postpartum depression)
  -- ------------------------------------------------------------
  INSERT INTO contacts (user_id, account_id, phone, name)
  VALUES (v_user_id, v_account_id, '919744890123', 'Fathima Rasheed')
  RETURNING id INTO v_contact_id;
  INSERT INTO deals (user_id, account_id, pipeline_id, stage_id, contact_id, title, value, currency, notes, expected_close_date, status)
  VALUES (v_user_id, v_account_id, v_pipeline_id, v_stage_consulted, v_contact_id,
    'Psychiatry Consultation – Fathima Rasheed', 800, 'INR',
    'Postpartum depression, 6 weeks after delivery. Initial consultation done; awaiting treatment plan.',
    CURRENT_DATE + 6, 'open');

  -- ------------------------------------------------------------
  -- Patient 4 — Arjun Nair, Child & Adolescent Psychiatry (ADHD)
  -- ------------------------------------------------------------
  INSERT INTO contacts (user_id, account_id, phone, name)
  VALUES (v_user_id, v_account_id, '919633445678', 'Arjun Nair')
  RETURNING id INTO v_contact_id;
  INSERT INTO deals (user_id, account_id, pipeline_id, stage_id, contact_id, title, value, currency, notes, expected_close_date, status)
  VALUES (v_user_id, v_account_id, v_pipeline_id, v_stage_inquiry, v_contact_id,
    'Child Psychiatry Consultation – Arjun Nair (age 8)', 750, 'INR',
    'Parents report inattention and hyperactivity at school. Referred by school counselor for ADHD evaluation.',
    CURRENT_DATE + 5, 'open');

  -- ------------------------------------------------------------
  -- Patient 5 — Manoj Pillai, Neurology / Memory Clinic (Dementia)
  -- ------------------------------------------------------------
  INSERT INTO contacts (user_id, account_id, phone, name)
  VALUES (v_user_id, v_account_id, '919744223344', 'Manoj Pillai')
  RETURNING id INTO v_contact_id;
  INSERT INTO deals (user_id, account_id, pipeline_id, stage_id, contact_id, title, value, currency, notes, expected_close_date, status)
  VALUES (v_user_id, v_account_id, v_pipeline_id, v_stage_planned, v_contact_id,
    'Memory Clinic – Manoj Pillai', 1200, 'INR',
    'Progressive memory loss over 6 months, suspected early-stage dementia. MMSE and MRI brain ordered; treatment plan shared with family.',
    CURRENT_DATE + 10, 'open');

  -- ------------------------------------------------------------
  -- Patient 6 — Priya Varma, Psychiatry (Panic disorder)
  -- ------------------------------------------------------------
  INSERT INTO contacts (user_id, account_id, phone, name)
  VALUES (v_user_id, v_account_id, '919946778812', 'Priya Varma')
  RETURNING id INTO v_contact_id;
  INSERT INTO deals (user_id, account_id, pipeline_id, stage_id, contact_id, title, value, currency, notes, expected_close_date, status)
  VALUES (v_user_id, v_account_id, v_pipeline_id, v_stage_booked, v_contact_id,
    'Psychiatry Consultation – Priya Varma', 800, 'INR',
    'Recurrent panic attacks with palpitations, triggered mostly at work. Appointment booked for evening slot.',
    CURRENT_DATE + 3, 'open');

  -- ------------------------------------------------------------
  -- Patient 7 — Sarath Kumar, De-addiction Psychiatry (Alcohol)
  -- ------------------------------------------------------------
  INSERT INTO contacts (user_id, account_id, phone, name)
  VALUES (v_user_id, v_account_id, '919895667788', 'Sarath Kumar')
  RETURNING id INTO v_contact_id;
  INSERT INTO deals (user_id, account_id, pipeline_id, stage_id, contact_id, title, value, currency, notes, expected_close_date, status)
  VALUES (v_user_id, v_account_id, v_pipeline_id, v_stage_consulted, v_contact_id,
    'De-addiction Consultation – Sarath Kumar', 1000, 'INR',
    'Seeking help for alcohol dependence, family-initiated enquiry. Initial consultation complete, discussing inpatient de-addiction program.',
    CURRENT_DATE + 7, 'open');

  -- ------------------------------------------------------------
  -- Patient 8 — Deepa Krishnan, Neurology (Chronic migraine) — Admitted
  -- ------------------------------------------------------------
  INSERT INTO contacts (user_id, account_id, phone, name)
  VALUES (v_user_id, v_account_id, '919847001122', 'Deepa Krishnan')
  RETURNING id INTO v_contact_id;
  INSERT INTO deals (user_id, account_id, pipeline_id, stage_id, contact_id, title, value, currency, notes, expected_close_date, status)
  VALUES (v_user_id, v_account_id, v_pipeline_id, v_stage_admitted, v_contact_id,
    'Neurology – Deepa Krishnan', 1500, 'INR',
    'Chronic migraine, 15+ headache days/month, admitted for a 2-day observation and preventive therapy titration.',
    CURRENT_DATE - 1, 'won');

  -- ------------------------------------------------------------
  -- Patient 9 — Vishnu Prasad, Psychiatry (OCD)
  -- ------------------------------------------------------------
  INSERT INTO contacts (user_id, account_id, phone, name)
  VALUES (v_user_id, v_account_id, '919633009988', 'Vishnu Prasad')
  RETURNING id INTO v_contact_id;
  INSERT INTO deals (user_id, account_id, pipeline_id, stage_id, contact_id, title, value, currency, notes, expected_close_date, status)
  VALUES (v_user_id, v_account_id, v_pipeline_id, v_stage_inquiry, v_contact_id,
    'Psychiatry Consultation – Vishnu Prasad', 800, 'INR',
    'Intrusive thoughts and repetitive checking behaviour for over a year, self-referred after reading about OCD online.',
    CURRENT_DATE + 8, 'open');

  -- ------------------------------------------------------------
  -- Patient 10 — Sarah Thomas, Neurology (Parkinson's follow-up)
  -- ------------------------------------------------------------
  INSERT INTO contacts (user_id, account_id, phone, name)
  VALUES (v_user_id, v_account_id, '919846556677', 'Sarah Thomas')
  RETURNING id INTO v_contact_id;
  INSERT INTO deals (user_id, account_id, pipeline_id, stage_id, contact_id, title, value, currency, notes, expected_close_date, status)
  VALUES (v_user_id, v_account_id, v_pipeline_id, v_stage_planned, v_contact_id,
    'Neurology Follow-up – Sarah Thomas', 900, 'INR',
    'Existing Parkinson''s disease patient, medication review and physiotherapy plan being finalized.',
    CURRENT_DATE + 9, 'open');

END $$;
