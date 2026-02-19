-- =====================================================
-- Delete Pending Mechanic Invitation
-- =====================================================
-- This will delete the pending invitation so you can try again

-- Check current invitations first
SELECT 
    id,
    email,
    first_name,
    last_name,
    status,
    created_at,
    sent_at
FROM mechanic_invitations
WHERE email = 'yujirofuma28@gmail.com'
ORDER BY created_at DESC;

-- Delete the pending invitation
DELETE FROM mechanic_invitations
WHERE email = 'yujirofuma28@gmail.com'
AND status IN ('pending', 'sent');

-- Also delete associated email notifications (optional cleanup)
DELETE FROM email_notifications
WHERE recipient_email = 'yujirofuma28@gmail.com'
AND email_type = 'welcome_mechanic';

-- Verify deletion
SELECT 
    id,
    email,
    status
FROM mechanic_invitations
WHERE email = 'yujirofuma28@gmail.com';

-- If no rows returned, invitation successfully deleted!
