-- Экспорт оплат в CSV (stdout). Запуск: export_audit_log.sh
COPY (
  SELECT
    p.id AS purchase_id,
    p.created_at AS created_at,
    p.paid_at AS paid_at,
    p.status AS status,
    p.amount::text AS amount,
    p.currency AS currency,
    p.month AS months,
    p.invoice_type AS payment_method,
    c.telegram_id AS buyer_telegram_id,
    c.id AS buyer_customer_id
  FROM purchase p
  LEFT JOIN customer c ON c.id = p.customer_id
  ORDER BY p.id DESC
  LIMIT 10000
) TO STDOUT WITH CSV HEADER;
