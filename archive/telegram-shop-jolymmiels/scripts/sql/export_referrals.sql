-- Рефералы: кто кого пригласил, выдан ли бонус пригласившему (= приглашённый оплатил).
COPY (
  SELECT
    r.id AS referral_id,
    r.referrer_id AS referrer_telegram_id,
    r.referee_id AS referee_telegram_id,
    r.used_at AS invited_at,
    r.bonus_granted AS referrer_bonus_granted,
    (
      SELECT COUNT(*)::int
      FROM purchase p
      JOIN customer cu ON cu.id = p.customer_id
      WHERE cu.telegram_id = r.referee_id
        AND p.status = 'paid'
    ) AS referee_paid_purchase_count
  FROM referral r
  ORDER BY r.id DESC
  LIMIT 10000
) TO STDOUT WITH CSV HEADER;
