-- Одна «лента» событий: покупки (все статусы) + регистрации по реф-ссылке.
COPY (
  SELECT *
  FROM (
    SELECT
      p.created_at AS event_time,
      'purchase' AS event_type,
      COALESCE(c.telegram_id::text, '') AS telegram_id,
      CONCAT(
        'status=', COALESCE(p.status::text, ''),
        ' amount=', p.amount::text,
        COALESCE(' ' || p.currency::text, ''),
        ' months=', p.month::text,
        ' method=', COALESCE(p.invoice_type::text, '')
      ) AS detail,
      p.id::text AS ref_id
    FROM purchase p
    LEFT JOIN customer c ON c.id = p.customer_id
    UNION ALL
    SELECT
      r.used_at AS event_time,
      'referral_invite' AS event_type,
      r.referee_id::text AS telegram_id,
      CONCAT(
        'referrer=', r.referrer_id::text,
        ' bonus_granted=', r.bonus_granted::text
      ) AS detail,
      r.id::text AS ref_id
    FROM referral r
  ) ev
  ORDER BY event_time DESC NULLS LAST
  LIMIT 15000
) TO STDOUT WITH CSV HEADER;
