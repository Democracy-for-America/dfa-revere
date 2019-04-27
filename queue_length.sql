SELECT
  COUNT(*) AS queue_length
FROM core_user u
JOIN core_action a ON u.id = a.user_id
JOIN core_page p ON p.id = a.page_id
JOIN core_actionfield f ON a.id = f.parent_id AND f.name = 'sms_opt_in'
JOIN core_actionfield g ON a.id = g.parent_id AND g.name IN ('provided_mobile_phone', 'provided_phone')
LEFT JOIN core_pagefield h ON p.id = h.parent_id AND h.name = 'revere_mobile_flow_id'
LEFT JOIN core_userfield i ON u.id = i.parent_id AND i.name = 'most_recent_revere_sync' AND a.created_at <= i.value
WHERE
  i.id IS NULL AND
  g.value RLIKE REPEAT('[0-9]{1}.*', 10) # 10-digit number
;
