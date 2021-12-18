CREATE TABLE IF NOT EXISTS partners
(
    id           BIGSERIAL,
    partner_name TEXT                     NOT NULL,
    description  TEXT                     NOT NULL,
    condition    BIGINT                   NOT NULL,
    image_url    TEXT                     NOT NULL,
    created_at   timestamp with time zone not null default now(),
    updated_at   timestamp with time zone not null default now()
);