-- ============================================================
-- Metromind Hospital — FULL SYSTEM demo data
-- ============================================================
-- Run this ONCE in the Supabase Dashboard → SQL Editor.
-- Not a migration — it is data, not schema, and it is NOT picked
-- up by `supabase/migrations/` or the CI migration replay.
--
-- WHAT THIS DOES, for 10 neuropsychiatric demo patients
-- (Psychiatry, Neurology, Child & Adolescent Psychiatry,
-- De-addiction):
--   1. Creates 6 tags (department + status) if they don't exist.
--   2. Creates each patient as a Contact — SKIPPED if a contact
--      with that phone number already exists for your account,
--      so this never overwrites a real patient.
--   3. Tags each contact and adds one clinical/admin note.
--   4. Creates one WhatsApp Conversation per patient with a short
--      realistic message thread — SKIPPED if that contact already
--      has a conversation (the app allows only one conversation
--      per contact, so existing threads are left untouched).
--   5. Rebuilds the "Patient Journey" pipeline (5 stages) and
--      seeds one Patient Case per patient, linked to their
--      conversation.
--
-- SAFETY
--   - Contacts and conversations are ADDITIVE and idempotent —
--     safe to re-run, and never touches an existing contact's
--     conversation.
--   - Pipelines/deals ARE deleted and recreated (Section B) —
--     this is the same destructive step as before. Section A is
--     a read-only preview; check it before running Section B/C.
-- ============================================================

-- ------------------------------------------------------------
-- EDIT ME: this script targets the Supabase Dashboard's web SQL
-- Editor, which doesn't support psql \set variables — so use
-- Find & Replace (Ctrl/Cmd+F) to replace every occurrence of
-- YOUR_LOGIN_EMAIL_HERE below with the email you log into the
-- CRM with. There are 3 occurrences total.
-- ------------------------------------------------------------

-- ============================================================
-- SECTION A — PREVIEW (read-only, safe to run any time)
-- ============================================================
SELECT
  (SELECT count(*) FROM contacts c
     JOIN profiles pr ON pr.account_id = c.account_id
     WHERE pr.email = 'YOUR_LOGIN_EMAIL_HERE') AS existing_contacts,
  (SELECT count(*) FROM pipelines p
     JOIN profiles pr ON pr.account_id = p.account_id
     WHERE pr.email = 'YOUR_LOGIN_EMAIL_HERE') AS existing_pipelines,
  (SELECT count(*) FROM deals d
     JOIN profiles pr ON pr.account_id = d.account_id
     WHERE pr.email = 'YOUR_LOGIN_EMAIL_HERE') AS existing_deals;

-- Review the output above. Section B deletes existing
-- pipelines/deals (not contacts/conversations). Only continue
-- once you've confirmed that's safe for your account.

-- ============================================================
-- SECTION B — DELETE existing pipelines/deals for this account
-- (contacts, tags, notes, and conversations are left untouched)
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
-- SECTION C — FULL SEED: tags, contacts, notes, conversations,
-- messages, pipeline + patient cases
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

  v_tag_psychiatry       UUID;
  v_tag_neurology        UUID;
  v_tag_child_psychiatry UUID;
  v_tag_deaddiction      UUID;
  v_tag_new_patient      UUID;
  v_tag_followup         UUID;

  v_contact_id      UUID;
  v_conversation_id UUID;
  v_is_new_contact      BOOLEAN;
  v_is_new_conversation BOOLEAN;
BEGIN
  SELECT account_id, user_id INTO v_account_id, v_user_id
  FROM profiles
  WHERE email = 'YOUR_LOGIN_EMAIL_HERE';

  IF v_account_id IS NULL THEN
    RAISE EXCEPTION 'No account found for that email — check EDIT ME above';
  END IF;

  -- ------------------------------------------------------------
  -- Tags (idempotent — reuse if already created by a prior run)
  -- ------------------------------------------------------------
  SELECT id INTO v_tag_psychiatry FROM tags WHERE user_id = v_user_id AND name = 'Psychiatry';
  IF v_tag_psychiatry IS NULL THEN
    INSERT INTO tags (user_id, name, color) VALUES (v_user_id, 'Psychiatry', '#8b5cf6') RETURNING id INTO v_tag_psychiatry;
  END IF;

  SELECT id INTO v_tag_neurology FROM tags WHERE user_id = v_user_id AND name = 'Neurology';
  IF v_tag_neurology IS NULL THEN
    INSERT INTO tags (user_id, name, color) VALUES (v_user_id, 'Neurology', '#3b82f6') RETURNING id INTO v_tag_neurology;
  END IF;

  SELECT id INTO v_tag_child_psychiatry FROM tags WHERE user_id = v_user_id AND name = 'Child Psychiatry';
  IF v_tag_child_psychiatry IS NULL THEN
    INSERT INTO tags (user_id, name, color) VALUES (v_user_id, 'Child Psychiatry', '#f97316') RETURNING id INTO v_tag_child_psychiatry;
  END IF;

  SELECT id INTO v_tag_deaddiction FROM tags WHERE user_id = v_user_id AND name = 'De-addiction';
  IF v_tag_deaddiction IS NULL THEN
    INSERT INTO tags (user_id, name, color) VALUES (v_user_id, 'De-addiction', '#ef4444') RETURNING id INTO v_tag_deaddiction;
  END IF;

  SELECT id INTO v_tag_new_patient FROM tags WHERE user_id = v_user_id AND name = 'New Patient';
  IF v_tag_new_patient IS NULL THEN
    INSERT INTO tags (user_id, name, color) VALUES (v_user_id, 'New Patient', '#eab308') RETURNING id INTO v_tag_new_patient;
  END IF;

  SELECT id INTO v_tag_followup FROM tags WHERE user_id = v_user_id AND name = 'Follow-up';
  IF v_tag_followup IS NULL THEN
    INSERT INTO tags (user_id, name, color) VALUES (v_user_id, 'Follow-up', '#22c55e') RETURNING id INTO v_tag_followup;
  END IF;

  -- ------------------------------------------------------------
  -- Pipeline + stages (fresh — Section B already cleared old ones)
  -- ------------------------------------------------------------
  INSERT INTO pipelines (user_id, account_id, name)
  VALUES (v_user_id, v_account_id, 'Patient Journey')
  RETURNING id INTO v_pipeline_id;

  INSERT INTO pipeline_stages (pipeline_id, name, color, position) VALUES
    (v_pipeline_id, 'New Inquiry',        '#3b82f6', 0) RETURNING id INTO v_stage_inquiry;
  INSERT INTO pipeline_stages (pipeline_id, name, color, position) VALUES
    (v_pipeline_id, 'Appointment Booked', '#8b5cf6', 1) RETURNING id INTO v_stage_booked;
  INSERT INTO pipeline_stages (pipeline_id, name, color, position) VALUES
    (v_pipeline_id, 'Consultation Done',  '#f97316', 2) RETURNING id INTO v_stage_consulted;
  INSERT INTO pipeline_stages (pipeline_id, name, color, position) VALUES
    (v_pipeline_id, 'Treatment Planned',  '#eab308', 3) RETURNING id INTO v_stage_planned;
  INSERT INTO pipeline_stages (pipeline_id, name, color, position) VALUES
    (v_pipeline_id, 'Admitted',           '#22c55e', 4) RETURNING id INTO v_stage_admitted;

  -- ============================================================
  -- Patient 1 — Anjali Menon, Psychiatry (Anxiety & insomnia)
  -- ============================================================
  SELECT id INTO v_contact_id FROM contacts WHERE account_id = v_account_id AND phone_normalized = '919847123456';
  v_is_new_contact := v_contact_id IS NULL;
  IF v_is_new_contact THEN
    INSERT INTO contacts (user_id, account_id, phone, name)
    VALUES (v_user_id, v_account_id, '919847123456', 'Anjali Menon')
    RETURNING id INTO v_contact_id;
  END IF;

  INSERT INTO contact_tags (contact_id, tag_id) VALUES (v_contact_id, v_tag_psychiatry) ON CONFLICT DO NOTHING;
  INSERT INTO contact_tags (contact_id, tag_id) VALUES (v_contact_id, v_tag_new_patient) ON CONFLICT DO NOTHING;

  IF NOT EXISTS (SELECT 1 FROM contact_notes WHERE contact_id = v_contact_id AND note_text LIKE 'Anxiety and sleep%') THEN
    INSERT INTO contact_notes (contact_id, user_id, note_text)
    VALUES (v_contact_id, v_user_id, 'Anxiety and sleep disturbance for 2 months. Requested a female doctor. WhatsApp is preferred contact method.');
  END IF;

  SELECT id INTO v_conversation_id FROM conversations WHERE account_id = v_account_id AND contact_id = v_contact_id;
  v_is_new_conversation := v_conversation_id IS NULL;
  IF v_is_new_conversation THEN
    INSERT INTO conversations (user_id, account_id, contact_id, status)
    VALUES (v_user_id, v_account_id, v_contact_id, 'open')
    RETURNING id INTO v_conversation_id;

    INSERT INTO messages (conversation_id, sender_type, content_type, content_text, status, created_at) VALUES
      (v_conversation_id, 'customer', 'text', 'Hi, I''ve been having trouble sleeping and feeling anxious for the past 2 months. Can I book a psychiatry consultation?', 'read', NOW() - INTERVAL '2 hours'),
      (v_conversation_id, 'agent',    'text', 'Hi Anjali, thank you for reaching out to Metromind Hospital. We can definitely help. Would you prefer a male or female doctor?', 'read', NOW() - INTERVAL '1 hour 55 minutes'),
      (v_conversation_id, 'customer', 'text', 'A female doctor would be more comfortable for me, thank you.', 'read', NOW() - INTERVAL '1 hour 50 minutes'),
      (v_conversation_id, 'agent',    'text', 'Understood. Dr. Meera is available on 5th Sept morning. Shall I book that slot for you?', 'delivered', NOW() - INTERVAL '1 hour 48 minutes');

    UPDATE conversations SET
      last_message_text = 'Understood. Dr. Meera is available on 5th Sept morning. Shall I book that slot for you?',
      last_message_at = NOW() - INTERVAL '1 hour 48 minutes',
      unread_count = 0
    WHERE id = v_conversation_id;
  END IF;

  INSERT INTO deals (user_id, account_id, pipeline_id, stage_id, contact_id, conversation_id, title, value, currency, notes, expected_close_date, status)
  VALUES (v_user_id, v_account_id, v_pipeline_id, v_stage_inquiry, v_contact_id, v_conversation_id,
    'Psychiatry Consultation – Anjali Menon', 800, 'INR',
    'Anxiety and sleep disturbance for 2 months. Prefers a female doctor. WhatsApp preferred contact.',
    CURRENT_DATE + 4, 'open');

  -- ============================================================
  -- Patient 2 — Ravi Chandran, Neurology (Epilepsy / seizures)
  -- ============================================================
  SELECT id INTO v_contact_id FROM contacts WHERE account_id = v_account_id AND phone_normalized = '919895567234';
  v_is_new_contact := v_contact_id IS NULL;
  IF v_is_new_contact THEN
    INSERT INTO contacts (user_id, account_id, phone, name)
    VALUES (v_user_id, v_account_id, '919895567234', 'Ravi Chandran')
    RETURNING id INTO v_contact_id;
  END IF;

  INSERT INTO contact_tags (contact_id, tag_id) VALUES (v_contact_id, v_tag_neurology) ON CONFLICT DO NOTHING;
  INSERT INTO contact_tags (contact_id, tag_id) VALUES (v_contact_id, v_tag_new_patient) ON CONFLICT DO NOTHING;

  IF NOT EXISTS (SELECT 1 FROM contact_notes WHERE contact_id = v_contact_id AND note_text LIKE 'Recurrent seizure%') THEN
    INSERT INTO contact_notes (contact_id, user_id, note_text)
    VALUES (v_contact_id, v_user_id, 'Recurrent seizure episodes over the last month, first-time evaluation. Bringing a prior EEG report.');
  END IF;

  SELECT id INTO v_conversation_id FROM conversations WHERE account_id = v_account_id AND contact_id = v_contact_id;
  v_is_new_conversation := v_conversation_id IS NULL;
  IF v_is_new_conversation THEN
    INSERT INTO conversations (user_id, account_id, contact_id, status)
    VALUES (v_user_id, v_account_id, v_contact_id, 'open')
    RETURNING id INTO v_conversation_id;

    INSERT INTO messages (conversation_id, sender_type, content_type, content_text, status, created_at) VALUES
      (v_conversation_id, 'customer', 'text', 'I''ve had 2 seizure episodes in the last month. I need to see a neurologist urgently.', 'read', NOW() - INTERVAL '5 hours'),
      (v_conversation_id, 'agent',    'text', 'We''re sorry to hear that, Ravi. We''ve booked you an appointment on 3rd Sept evening with Dr. Nandakumar. Please bring any previous EEG reports.', 'read', NOW() - INTERVAL '4 hours 50 minutes'),
      (v_conversation_id, 'customer', 'text', 'Yes, I have an EEG from last year. I''ll bring it.', 'read', NOW() - INTERVAL '4 hours 45 minutes'),
      (v_conversation_id, 'agent',    'text', 'Perfect, see you then. Please arrive 15 minutes early for registration.', 'delivered', NOW() - INTERVAL '4 hours 43 minutes');

    UPDATE conversations SET
      last_message_text = 'Perfect, see you then. Please arrive 15 minutes early for registration.',
      last_message_at = NOW() - INTERVAL '4 hours 43 minutes',
      unread_count = 0
    WHERE id = v_conversation_id;
  END IF;

  INSERT INTO deals (user_id, account_id, pipeline_id, stage_id, contact_id, conversation_id, title, value, currency, notes, expected_close_date, status)
  VALUES (v_user_id, v_account_id, v_pipeline_id, v_stage_booked, v_contact_id, v_conversation_id,
    'Neurology Consultation – Ravi Chandran', 900, 'INR',
    'Recurrent seizure episodes over the last month, first-time evaluation. Bringing prior EEG report.',
    CURRENT_DATE + 2, 'open');

  -- ============================================================
  -- Patient 3 — Fathima Rasheed, Psychiatry (Postpartum depression)
  -- ============================================================
  SELECT id INTO v_contact_id FROM contacts WHERE account_id = v_account_id AND phone_normalized = '919744890123';
  v_is_new_contact := v_contact_id IS NULL;
  IF v_is_new_contact THEN
    INSERT INTO contacts (user_id, account_id, phone, name)
    VALUES (v_user_id, v_account_id, '919744890123', 'Fathima Rasheed')
    RETURNING id INTO v_contact_id;
  END IF;

  INSERT INTO contact_tags (contact_id, tag_id) VALUES (v_contact_id, v_tag_psychiatry) ON CONFLICT DO NOTHING;
  INSERT INTO contact_tags (contact_id, tag_id) VALUES (v_contact_id, v_tag_followup) ON CONFLICT DO NOTHING;

  IF NOT EXISTS (SELECT 1 FROM contact_notes WHERE contact_id = v_contact_id AND note_text LIKE 'Postpartum depression%') THEN
    INSERT INTO contact_notes (contact_id, user_id, note_text)
    VALUES (v_contact_id, v_user_id, 'Postpartum depression, 6 weeks after delivery. Referred by her gynecologist.');
  END IF;

  SELECT id INTO v_conversation_id FROM conversations WHERE account_id = v_account_id AND contact_id = v_contact_id;
  v_is_new_conversation := v_conversation_id IS NULL;
  IF v_is_new_conversation THEN
    INSERT INTO conversations (user_id, account_id, contact_id, status)
    VALUES (v_user_id, v_account_id, v_contact_id, 'open')
    RETURNING id INTO v_conversation_id;

    INSERT INTO messages (conversation_id, sender_type, content_type, content_text, status, created_at) VALUES
      (v_conversation_id, 'customer', 'text', 'My gynecologist referred me for postpartum depression symptoms.', 'read', NOW() - INTERVAL '1 day 2 hours'),
      (v_conversation_id, 'agent',    'text', 'Thanks Fathima, your consultation with Dr. Meera is complete. She has recommended a treatment plan — we''ll share the details shortly.', 'read', NOW() - INTERVAL '1 day 1 hour'),
      (v_conversation_id, 'customer', 'text', 'Thank you, please send it over WhatsApp.', 'read', NOW() - INTERVAL '1 day'),
      (v_conversation_id, 'agent',    'text', 'Sure, sharing the treatment plan document now.', 'delivered', NOW() - INTERVAL '23 hours 55 minutes');

    UPDATE conversations SET
      last_message_text = 'Sure, sharing the treatment plan document now.',
      last_message_at = NOW() - INTERVAL '23 hours 55 minutes',
      unread_count = 0
    WHERE id = v_conversation_id;
  END IF;

  INSERT INTO deals (user_id, account_id, pipeline_id, stage_id, contact_id, conversation_id, title, value, currency, notes, expected_close_date, status)
  VALUES (v_user_id, v_account_id, v_pipeline_id, v_stage_consulted, v_contact_id, v_conversation_id,
    'Psychiatry Consultation – Fathima Rasheed', 800, 'INR',
    'Postpartum depression, 6 weeks after delivery. Initial consultation done; awaiting treatment plan.',
    CURRENT_DATE + 6, 'open');

  -- ============================================================
  -- Patient 4 — Arjun Nair, Child & Adolescent Psychiatry (ADHD)
  -- ============================================================
  SELECT id INTO v_contact_id FROM contacts WHERE account_id = v_account_id AND phone_normalized = '919633445678';
  v_is_new_contact := v_contact_id IS NULL;
  IF v_is_new_contact THEN
    INSERT INTO contacts (user_id, account_id, phone, name)
    VALUES (v_user_id, v_account_id, '919633445678', 'Arjun Nair (parent: Sunitha Nair)')
    RETURNING id INTO v_contact_id;
  END IF;

  INSERT INTO contact_tags (contact_id, tag_id) VALUES (v_contact_id, v_tag_child_psychiatry) ON CONFLICT DO NOTHING;
  INSERT INTO contact_tags (contact_id, tag_id) VALUES (v_contact_id, v_tag_new_patient) ON CONFLICT DO NOTHING;

  IF NOT EXISTS (SELECT 1 FROM contact_notes WHERE contact_id = v_contact_id AND note_text LIKE 'Parents report%') THEN
    INSERT INTO contact_notes (contact_id, user_id, note_text)
    VALUES (v_contact_id, v_user_id, 'Parents report inattention and hyperactivity at school (age 8). Referred by school counselor for ADHD evaluation.');
  END IF;

  SELECT id INTO v_conversation_id FROM conversations WHERE account_id = v_account_id AND contact_id = v_contact_id;
  v_is_new_conversation := v_conversation_id IS NULL;
  IF v_is_new_conversation THEN
    INSERT INTO conversations (user_id, account_id, contact_id, status)
    VALUES (v_user_id, v_account_id, v_contact_id, 'open')
    RETURNING id INTO v_conversation_id;

    INSERT INTO messages (conversation_id, sender_type, content_type, content_text, status, created_at) VALUES
      (v_conversation_id, 'customer', 'text', 'My son''s school counselor suggested we get him evaluated for ADHD. Can you help?', 'read', NOW() - INTERVAL '3 hours'),
      (v_conversation_id, 'agent',    'text', 'Of course. We have a dedicated Child & Adolescent Psychiatry unit. Could you share his age and any specific concerns?', 'read', NOW() - INTERVAL '2 hours 50 minutes'),
      (v_conversation_id, 'customer', 'text', 'He''s 8, very inattentive and hyperactive in class.', 'read', NOW() - INTERVAL '2 hours 40 minutes');

    UPDATE conversations SET
      last_message_text = 'He''s 8, very inattentive and hyperactive in class.',
      last_message_at = NOW() - INTERVAL '2 hours 40 minutes',
      unread_count = 1
    WHERE id = v_conversation_id;
  END IF;

  INSERT INTO deals (user_id, account_id, pipeline_id, stage_id, contact_id, conversation_id, title, value, currency, notes, expected_close_date, status)
  VALUES (v_user_id, v_account_id, v_pipeline_id, v_stage_inquiry, v_contact_id, v_conversation_id,
    'Child Psychiatry Consultation – Arjun Nair (age 8)', 750, 'INR',
    'Parents report inattention and hyperactivity at school. Referred by school counselor for ADHD evaluation.',
    CURRENT_DATE + 5, 'open');

  -- ============================================================
  -- Patient 5 — Manoj Pillai, Neurology / Memory Clinic (Dementia)
  -- ============================================================
  SELECT id INTO v_contact_id FROM contacts WHERE account_id = v_account_id AND phone_normalized = '919744223344';
  v_is_new_contact := v_contact_id IS NULL;
  IF v_is_new_contact THEN
    INSERT INTO contacts (user_id, account_id, phone, name)
    VALUES (v_user_id, v_account_id, '919744223344', 'Manoj Pillai')
    RETURNING id INTO v_contact_id;
  END IF;

  INSERT INTO contact_tags (contact_id, tag_id) VALUES (v_contact_id, v_tag_neurology) ON CONFLICT DO NOTHING;
  INSERT INTO contact_tags (contact_id, tag_id) VALUES (v_contact_id, v_tag_followup) ON CONFLICT DO NOTHING;

  IF NOT EXISTS (SELECT 1 FROM contact_notes WHERE contact_id = v_contact_id AND note_text LIKE 'Progressive memory loss%') THEN
    INSERT INTO contact_notes (contact_id, user_id, note_text)
    VALUES (v_contact_id, v_user_id, 'Progressive memory loss over 6 months, suspected early-stage dementia. MMSE and MRI brain ordered.');
  END IF;

  SELECT id INTO v_conversation_id FROM conversations WHERE account_id = v_account_id AND contact_id = v_contact_id;
  v_is_new_conversation := v_conversation_id IS NULL;
  IF v_is_new_conversation THEN
    INSERT INTO conversations (user_id, account_id, contact_id, status)
    VALUES (v_user_id, v_account_id, v_contact_id, 'pending')
    RETURNING id INTO v_conversation_id;

    INSERT INTO messages (conversation_id, sender_type, content_type, content_text, status, created_at) VALUES
      (v_conversation_id, 'customer', 'text', 'My father has been forgetting things frequently. We''re worried it might be dementia.', 'read', NOW() - INTERVAL '2 days'),
      (v_conversation_id, 'agent',    'text', 'We understand your concern. Our Memory Clinic team has evaluated him and shared an initial treatment plan with MRI and MMSE test recommendations.', 'read', NOW() - INTERVAL '1 day 20 hours'),
      (v_conversation_id, 'customer', 'text', 'Can we get a printed copy for our records?', 'read', NOW() - INTERVAL '1 day 19 hours'),
      (v_conversation_id, 'agent',    'text', 'Yes, we''ll have it ready at the front desk for your next visit.', 'delivered', NOW() - INTERVAL '1 day 18 hours 55 minutes');

    UPDATE conversations SET
      last_message_text = 'Yes, we''ll have it ready at the front desk for your next visit.',
      last_message_at = NOW() - INTERVAL '1 day 18 hours 55 minutes',
      unread_count = 0
    WHERE id = v_conversation_id;
  END IF;

  INSERT INTO deals (user_id, account_id, pipeline_id, stage_id, contact_id, conversation_id, title, value, currency, notes, expected_close_date, status)
  VALUES (v_user_id, v_account_id, v_pipeline_id, v_stage_planned, v_contact_id, v_conversation_id,
    'Memory Clinic – Manoj Pillai', 1200, 'INR',
    'Progressive memory loss over 6 months, suspected early-stage dementia. MMSE and MRI brain ordered; treatment plan shared with family.',
    CURRENT_DATE + 10, 'open');

  -- ============================================================
  -- Patient 6 — Priya Varma, Psychiatry (Panic disorder)
  -- ============================================================
  SELECT id INTO v_contact_id FROM contacts WHERE account_id = v_account_id AND phone_normalized = '919946778812';
  v_is_new_contact := v_contact_id IS NULL;
  IF v_is_new_contact THEN
    INSERT INTO contacts (user_id, account_id, phone, name)
    VALUES (v_user_id, v_account_id, '919946778812', 'Priya Varma')
    RETURNING id INTO v_contact_id;
  END IF;

  INSERT INTO contact_tags (contact_id, tag_id) VALUES (v_contact_id, v_tag_psychiatry) ON CONFLICT DO NOTHING;
  INSERT INTO contact_tags (contact_id, tag_id) VALUES (v_contact_id, v_tag_new_patient) ON CONFLICT DO NOTHING;

  IF NOT EXISTS (SELECT 1 FROM contact_notes WHERE contact_id = v_contact_id AND note_text LIKE 'Recurrent panic%') THEN
    INSERT INTO contact_notes (contact_id, user_id, note_text)
    VALUES (v_contact_id, v_user_id, 'Recurrent panic attacks with palpitations, triggered mostly at work. Prefers evening slots after 6 PM.');
  END IF;

  SELECT id INTO v_conversation_id FROM conversations WHERE account_id = v_account_id AND contact_id = v_contact_id;
  v_is_new_conversation := v_conversation_id IS NULL;
  IF v_is_new_conversation THEN
    INSERT INTO conversations (user_id, account_id, contact_id, status)
    VALUES (v_user_id, v_account_id, v_contact_id, 'open')
    RETURNING id INTO v_conversation_id;

    INSERT INTO messages (conversation_id, sender_type, content_type, content_text, status, created_at) VALUES
      (v_conversation_id, 'customer', 'text', 'I keep having panic attacks with palpitations, mostly at work.', 'read', NOW() - INTERVAL '6 hours'),
      (v_conversation_id, 'agent',    'text', 'That sounds difficult, Priya. We''ve booked an evening slot on 4th Sept for you with Dr. Meera.', 'read', NOW() - INTERVAL '5 hours 50 minutes'),
      (v_conversation_id, 'customer', 'text', 'Thank you, evening works best for me.', 'read', NOW() - INTERVAL '5 hours 45 minutes');

    UPDATE conversations SET
      last_message_text = 'Thank you, evening works best for me.',
      last_message_at = NOW() - INTERVAL '5 hours 45 minutes',
      unread_count = 0
    WHERE id = v_conversation_id;
  END IF;

  INSERT INTO deals (user_id, account_id, pipeline_id, stage_id, contact_id, conversation_id, title, value, currency, notes, expected_close_date, status)
  VALUES (v_user_id, v_account_id, v_pipeline_id, v_stage_booked, v_contact_id, v_conversation_id,
    'Psychiatry Consultation – Priya Varma', 800, 'INR',
    'Recurrent panic attacks with palpitations, triggered mostly at work. Appointment booked for evening slot.',
    CURRENT_DATE + 3, 'open');

  -- ============================================================
  -- Patient 7 — Sarath Kumar, De-addiction Psychiatry (Alcohol)
  -- ============================================================
  SELECT id INTO v_contact_id FROM contacts WHERE account_id = v_account_id AND phone_normalized = '919895667788';
  v_is_new_contact := v_contact_id IS NULL;
  IF v_is_new_contact THEN
    INSERT INTO contacts (user_id, account_id, phone, name)
    VALUES (v_user_id, v_account_id, '919895667788', 'Sarath Kumar')
    RETURNING id INTO v_contact_id;
  END IF;

  INSERT INTO contact_tags (contact_id, tag_id) VALUES (v_contact_id, v_tag_deaddiction) ON CONFLICT DO NOTHING;
  INSERT INTO contact_tags (contact_id, tag_id) VALUES (v_contact_id, v_tag_followup) ON CONFLICT DO NOTHING;

  IF NOT EXISTS (SELECT 1 FROM contact_notes WHERE contact_id = v_contact_id AND note_text LIKE 'Seeking help for alcohol%') THEN
    INSERT INTO contact_notes (contact_id, user_id, note_text)
    VALUES (v_contact_id, v_user_id, 'Seeking help for alcohol dependence, family-initiated enquiry. Discussing inpatient de-addiction program.');
  END IF;

  SELECT id INTO v_conversation_id FROM conversations WHERE account_id = v_account_id AND contact_id = v_contact_id;
  v_is_new_conversation := v_conversation_id IS NULL;
  IF v_is_new_conversation THEN
    INSERT INTO conversations (user_id, account_id, contact_id, status)
    VALUES (v_user_id, v_account_id, v_contact_id, 'open')
    RETURNING id INTO v_conversation_id;

    INSERT INTO messages (conversation_id, sender_type, content_type, content_text, status, created_at) VALUES
      (v_conversation_id, 'customer', 'text', 'My brother needs help with alcohol dependence. Can we discuss admission?', 'read', NOW() - INTERVAL '1 day 3 hours'),
      (v_conversation_id, 'agent',    'text', 'We''re here to help. His initial consultation is complete. Our team is now discussing options for the inpatient de-addiction program.', 'read', NOW() - INTERVAL '1 day 2 hours'),
      (v_conversation_id, 'customer', 'text', 'How long does the program usually take?', 'read', NOW() - INTERVAL '1 day 1 hour 50 minutes'),
      (v_conversation_id, 'agent',    'text', 'Typically 2-3 weeks depending on the case. Our counselor will call you to explain in detail.', 'delivered', NOW() - INTERVAL '1 day 1 hour 45 minutes');

    UPDATE conversations SET
      last_message_text = 'Typically 2-3 weeks depending on the case. Our counselor will call you to explain in detail.',
      last_message_at = NOW() - INTERVAL '1 day 1 hour 45 minutes',
      unread_count = 0
    WHERE id = v_conversation_id;
  END IF;

  INSERT INTO deals (user_id, account_id, pipeline_id, stage_id, contact_id, conversation_id, title, value, currency, notes, expected_close_date, status)
  VALUES (v_user_id, v_account_id, v_pipeline_id, v_stage_consulted, v_contact_id, v_conversation_id,
    'De-addiction Consultation – Sarath Kumar', 1000, 'INR',
    'Seeking help for alcohol dependence, family-initiated enquiry. Initial consultation complete, discussing inpatient de-addiction program.',
    CURRENT_DATE + 7, 'open');

  -- ============================================================
  -- Patient 8 — Deepa Krishnan, Neurology (Chronic migraine) — Admitted
  -- ============================================================
  SELECT id INTO v_contact_id FROM contacts WHERE account_id = v_account_id AND phone_normalized = '919847001122';
  v_is_new_contact := v_contact_id IS NULL;
  IF v_is_new_contact THEN
    INSERT INTO contacts (user_id, account_id, phone, name)
    VALUES (v_user_id, v_account_id, '919847001122', 'Deepa Krishnan')
    RETURNING id INTO v_contact_id;
  END IF;

  INSERT INTO contact_tags (contact_id, tag_id) VALUES (v_contact_id, v_tag_neurology) ON CONFLICT DO NOTHING;
  INSERT INTO contact_tags (contact_id, tag_id) VALUES (v_contact_id, v_tag_followup) ON CONFLICT DO NOTHING;

  IF NOT EXISTS (SELECT 1 FROM contact_notes WHERE contact_id = v_contact_id AND note_text LIKE 'Chronic migraine%') THEN
    INSERT INTO contact_notes (contact_id, user_id, note_text)
    VALUES (v_contact_id, v_user_id, 'Chronic migraine, 15+ headache days/month. Admitted for a 2-day observation and preventive therapy titration.');
  END IF;

  SELECT id INTO v_conversation_id FROM conversations WHERE account_id = v_account_id AND contact_id = v_contact_id;
  v_is_new_conversation := v_conversation_id IS NULL;
  IF v_is_new_conversation THEN
    INSERT INTO conversations (user_id, account_id, contact_id, status)
    VALUES (v_user_id, v_account_id, v_contact_id, 'closed')
    RETURNING id INTO v_conversation_id;

    INSERT INTO messages (conversation_id, sender_type, content_type, content_text, status, created_at) VALUES
      (v_conversation_id, 'customer', 'text', 'I''m having headaches almost every day, it''s affecting my work.', 'read', NOW() - INTERVAL '3 days'),
      (v_conversation_id, 'agent',    'text', 'We''ve admitted you for a 2-day observation to titrate your preventive migraine therapy, Deepa.', 'read', NOW() - INTERVAL '2 days 12 hours'),
      (v_conversation_id, 'customer', 'text', 'Thank you, feeling better already after admission.', 'read', NOW() - INTERVAL '1 day'),
      (v_conversation_id, 'agent',    'text', 'Glad to hear that. Our neurologist will review your progress tomorrow.', 'read', NOW() - INTERVAL '23 hours');

    UPDATE conversations SET
      last_message_text = 'Glad to hear that. Our neurologist will review your progress tomorrow.',
      last_message_at = NOW() - INTERVAL '23 hours',
      unread_count = 0
    WHERE id = v_conversation_id;
  END IF;

  INSERT INTO deals (user_id, account_id, pipeline_id, stage_id, contact_id, conversation_id, title, value, currency, notes, expected_close_date, status)
  VALUES (v_user_id, v_account_id, v_pipeline_id, v_stage_admitted, v_contact_id, v_conversation_id,
    'Neurology – Deepa Krishnan', 1500, 'INR',
    'Chronic migraine, 15+ headache days/month, admitted for a 2-day observation and preventive therapy titration.',
    CURRENT_DATE - 1, 'won');

  -- ============================================================
  -- Patient 9 — Vishnu Prasad, Psychiatry (OCD)
  -- ============================================================
  SELECT id INTO v_contact_id FROM contacts WHERE account_id = v_account_id AND phone_normalized = '919633009988';
  v_is_new_contact := v_contact_id IS NULL;
  IF v_is_new_contact THEN
    INSERT INTO contacts (user_id, account_id, phone, name)
    VALUES (v_user_id, v_account_id, '919633009988', 'Vishnu Prasad')
    RETURNING id INTO v_contact_id;
  END IF;

  INSERT INTO contact_tags (contact_id, tag_id) VALUES (v_contact_id, v_tag_psychiatry) ON CONFLICT DO NOTHING;
  INSERT INTO contact_tags (contact_id, tag_id) VALUES (v_contact_id, v_tag_new_patient) ON CONFLICT DO NOTHING;

  IF NOT EXISTS (SELECT 1 FROM contact_notes WHERE contact_id = v_contact_id AND note_text LIKE 'Intrusive thoughts%') THEN
    INSERT INTO contact_notes (contact_id, user_id, note_text)
    VALUES (v_contact_id, v_user_id, 'Intrusive thoughts and repetitive checking behaviour for over a year. Self-referred after reading about OCD online.');
  END IF;

  SELECT id INTO v_conversation_id FROM conversations WHERE account_id = v_account_id AND contact_id = v_contact_id;
  v_is_new_conversation := v_conversation_id IS NULL;
  IF v_is_new_conversation THEN
    INSERT INTO conversations (user_id, account_id, contact_id, status)
    VALUES (v_user_id, v_account_id, v_contact_id, 'open')
    RETURNING id INTO v_conversation_id;

    INSERT INTO messages (conversation_id, sender_type, content_type, content_text, status, created_at) VALUES
      (v_conversation_id, 'customer', 'text', 'I''ve been having intrusive thoughts and repetitive checking behaviour for over a year. I think it might be OCD.', 'read', NOW() - INTERVAL '40 minutes'),
      (v_conversation_id, 'agent',    'text', 'Thank you for sharing, Vishnu. We''d like to schedule a consultation with our psychiatrist to evaluate this properly.', 'read', NOW() - INTERVAL '30 minutes'),
      (v_conversation_id, 'customer', 'text', 'Sure, I''m available this week.', 'delivered', NOW() - INTERVAL '25 minutes');

    UPDATE conversations SET
      last_message_text = 'Sure, I''m available this week.',
      last_message_at = NOW() - INTERVAL '25 minutes',
      unread_count = 1
    WHERE id = v_conversation_id;
  END IF;

  INSERT INTO deals (user_id, account_id, pipeline_id, stage_id, contact_id, conversation_id, title, value, currency, notes, expected_close_date, status)
  VALUES (v_user_id, v_account_id, v_pipeline_id, v_stage_inquiry, v_contact_id, v_conversation_id,
    'Psychiatry Consultation – Vishnu Prasad', 800, 'INR',
    'Intrusive thoughts and repetitive checking behaviour for over a year, self-referred after reading about OCD online.',
    CURRENT_DATE + 8, 'open');

  -- ============================================================
  -- Patient 10 — Sarah Thomas, Neurology (Parkinson's follow-up)
  -- ============================================================
  SELECT id INTO v_contact_id FROM contacts WHERE account_id = v_account_id AND phone_normalized = '919846556677';
  v_is_new_contact := v_contact_id IS NULL;
  IF v_is_new_contact THEN
    INSERT INTO contacts (user_id, account_id, phone, name)
    VALUES (v_user_id, v_account_id, '919846556677', 'Sarah Thomas')
    RETURNING id INTO v_contact_id;
  END IF;

  INSERT INTO contact_tags (contact_id, tag_id) VALUES (v_contact_id, v_tag_neurology) ON CONFLICT DO NOTHING;
  INSERT INTO contact_tags (contact_id, tag_id) VALUES (v_contact_id, v_tag_followup) ON CONFLICT DO NOTHING;

  IF NOT EXISTS (SELECT 1 FROM contact_notes WHERE contact_id = v_contact_id AND note_text LIKE 'Existing Parkinson%') THEN
    INSERT INTO contact_notes (contact_id, user_id, note_text)
    VALUES (v_contact_id, v_user_id, 'Existing Parkinson''s disease patient, medication review and physiotherapy plan being finalized.');
  END IF;

  SELECT id INTO v_conversation_id FROM conversations WHERE account_id = v_account_id AND contact_id = v_contact_id;
  v_is_new_conversation := v_conversation_id IS NULL;
  IF v_is_new_conversation THEN
    INSERT INTO conversations (user_id, account_id, contact_id, status)
    VALUES (v_user_id, v_account_id, v_contact_id, 'open')
    RETURNING id INTO v_conversation_id;

    INSERT INTO messages (conversation_id, sender_type, content_type, content_text, status, created_at) VALUES
      (v_conversation_id, 'customer', 'text', 'I''m due for my regular Parkinson''s medication review.', 'read', NOW() - INTERVAL '4 days'),
      (v_conversation_id, 'agent',    'text', 'Hi Sarah, we''ve scheduled your follow-up for 10th Sept morning along with a physiotherapy plan review.', 'read', NOW() - INTERVAL '3 days 23 hours'),
      (v_conversation_id, 'customer', 'text', 'Great, thank you for the reminder.', 'read', NOW() - INTERVAL '3 days 22 hours 50 minutes');

    UPDATE conversations SET
      last_message_text = 'Great, thank you for the reminder.',
      last_message_at = NOW() - INTERVAL '3 days 22 hours 50 minutes',
      unread_count = 0
    WHERE id = v_conversation_id;
  END IF;

  INSERT INTO deals (user_id, account_id, pipeline_id, stage_id, contact_id, conversation_id, title, value, currency, notes, expected_close_date, status)
  VALUES (v_user_id, v_account_id, v_pipeline_id, v_stage_planned, v_contact_id, v_conversation_id,
    'Neurology Follow-up – Sarah Thomas', 900, 'INR',
    'Existing Parkinson''s disease patient, medication review and physiotherapy plan being finalized.',
    CURRENT_DATE + 9, 'open');

END $$;
