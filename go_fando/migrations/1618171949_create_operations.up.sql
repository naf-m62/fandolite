-- migrate create -ext sql -dir migrations create_operations
-- migrate -path migrations -database "postgres://postgres:postgres@127.0.0.1:5432/rest_api_dev?sslmode=disable" up

CREATE TABLE IF NOT EXISTS operations
(
    id           BIGSERIAL,
    user_id      BIGINT                   NOT NULL,
    barcode      TEXT                     NOT NULL,
    container_id BIGINT                   NOT NULL,
    created_at   timestamp with time zone not null default now(),
    updated_at   timestamp with time zone not null default now()
);

CREATE TYPE container_types AS ENUM ('paper', 'plastic');

CREATE TABLE IF NOT EXISTS containers
(
    id               BIGSERIAL,
    type             container_types          NOT NULL,
    allowed_barcodes TEXT[],
    created_at       timestamp with time zone not null default now(),
    updated_at       timestamp with time zone not null default now()
);

ALTER TABLE users ADD COLUMN balls BIGINT;
ALTER TABLE users ADD COLUMN created_at timestamptz default now();
ALTER TABLE users ADD COLUMN updated_at timestamptz default now();