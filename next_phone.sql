SELECT
  g.value AS msisdn,
  h.value AS revere_mobile_flow_id,
  u.id AS 'DFA ActionKit ID',
  u.first_name AS First,
  u.last_name AS Last,
  u.email,
  u.zip AS zipcode,
  f.id AS actionfield_id,
  a.created_at
FROM core_user u
JOIN core_action a ON u.id = a.user_id
JOIN core_page p ON p.id = a.page_id
JOIN core_actionfield f ON a.id = f.parent_id AND f.name = 'sms_opt_in'
JOIN core_actionfield g ON a.id = g.parent_id AND g.name IN ('provided_mobile_phone', 'provided_phone')
LEFT JOIN core_pagefield h ON p.id = h.parent_id AND h.name = 'revere_mobile_flow_id'
WHERE
  g.value RLIKE REPEAT('[0-9].*', 10)
ORDER BY a.created_at
LIMIT 1