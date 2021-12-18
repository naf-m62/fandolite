CREATE TABLE users (
    id bigserial not null primary key,
    email varchar(255) not null unique,
    encrypted_password varchar(255) not null
);