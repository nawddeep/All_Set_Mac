-- Access keys for the app's key screen, and the tokens a key is exchanged for
-- (scripts/cloud/accounts.py key ...). One key per person, so one can be
-- revoked without touching the others. Additive only: nothing above changes.

create table if not exists access_keys (
    name            text primary key,         -- who it was given to, as typed at `key create`
    key_hash        text not null unique,     -- SHA-256 of the key; the key is never stored
    created_at      timestamptz not null default now(),
    revoked_at      timestamptz,              -- set: the key and its tokens stop working
    last_used_at    timestamptz
);

create unique index if not exists access_keys_name_lower on access_keys (lower(name));

create table if not exists access_tokens (
    token_hash      text primary key,         -- SHA-256 of the token; the token is never stored
    key_name        text not null references access_keys (name) on delete cascade,
    expires_at      timestamptz not null
);

create index if not exists access_tokens_key_name on access_tokens (key_name);
