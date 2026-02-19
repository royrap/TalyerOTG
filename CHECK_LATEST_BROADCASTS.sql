-- Check who was notified for the LATEST request
SELECT 
  '📤 Notified for LATEST Request' as info,
  rb.request_id,
  up.first_name || ' ' || up.last_name as mechanic_name,
  s.shop_name as their_shop,
  rb.notification_sent_at
FROM request_broadcasts rb
JOIN user_profiles up ON up.id = rb.mechanic_id
LEFT JOIN shops s ON s.id = rb.shop_id
WHERE rb.request_id = '105d1069-aea7-4449-840a-18d46909de47'
ORDER BY rb.notification_sent_at DESC;

-- If no results, that's PERFECT! It means NO mechanics were notified (as expected for 0 mechanics shop)
