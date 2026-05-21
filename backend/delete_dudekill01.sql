-- =============================================================
-- SAFE DELETION: dudekill01@gmail.com
-- This user is a team member (not boutique owner).
-- Tenant is SHARED with fillme005@gmail.com — must keep it.
-- =============================================================

-- Step 0: Identify the user
-- (For safety, run this first to confirm the ID matches)
-- SELECT id, full_name, role, tenant_id FROM users WHERE email = 'dudekill01@gmail.com';
-- Expected: id = 8c9ade3f-f8ae-4f15-af3f-e3200627cad3, role = USER

-- Step 1: Delete activity_logs (UUID column, no FK — orphaned data)
DELETE FROM activity_logs
WHERE user_id = (SELECT id FROM users WHERE email = 'dudekill01@gmail.com');

-- Step 2: Delete refresh_tokens (FK user_id -> users(id), NO ACTION — would fail if rows exist)
DELETE FROM refresh_tokens
WHERE user_id = (SELECT id FROM users WHERE email = 'dudekill01@gmail.com');

-- Step 3: Delete team_members (FK user_id -> users(id), ON DELETE CASCADE — explicit delete is clean)
DELETE FROM team_members
WHERE user_id = (SELECT id FROM users WHERE email = 'dudekill01@gmail.com');

-- Step 4: Delete team_invitations (no user_id FK — matched by invited_email column)
DELETE FROM team_invitations
WHERE invited_email = 'dudekill01@gmail.com';

-- Step 5: Delete the user (FK tenant_id -> tenants(id), NO ACTION — tenant is shared, NOT deleted)
DELETE FROM users
WHERE email = 'dudekill01@gmail.com';

-- =============================================================
-- VERIFICATION
-- =============================================================
-- All of the following should return 0 rows:

-- SELECT * FROM users WHERE email = 'dudekill01@gmail.com';
-- SELECT * FROM refresh_tokens WHERE user_id = '8c9ade3f-f8ae-4f15-af3f-e3200627cad3';
-- SELECT * FROM team_members WHERE user_id = '8c9ade3f-f8ae-4f15-af3f-e3200627cad3';
-- SELECT * FROM team_invitations WHERE invited_email = 'dudekill01@gmail.com';
-- SELECT * FROM activity_logs WHERE user_id = '8c9ade3f-f8ae-4f15-af3f-e3200627cad3';
