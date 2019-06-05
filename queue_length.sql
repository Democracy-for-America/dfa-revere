SELECT
  COUNT(DISTINCT a.id) AS queue_length
FROM core_user u
JOIN core_action a ON u.id = a.user_id
JOIN core_page p ON p.id = a.page_id
JOIN core_actionfield f ON a.id = f.parent_id AND f.name = 'sms_opt_in'
JOIN core_actionfield g ON a.id = g.parent_id AND g.name IN ('provided_mobile_phone', 'provided_phone')
LEFT JOIN core_pagefield h ON p.id = h.parent_id AND h.name = 'revere_mobile_flow_id'
WHERE
  g.value RLIKE REPEAT('[0-9].*', 10) # 10-digit number
;
