-- Invited people's accounts and their sign-in sessions (scripts/cloud/accounts.py).
-- Additive only: nothing above is touched, so existing wallpaper rows and the
-- connection the app and sync scripts use are unaffected.

create table if not exists accounts (
    email           text primary key check (email = lower(email)),
    password_hash   text not null,            -- scrypt, never the password itself
    must_change     boolean not null default true,   -- a temporary password: change it first
    disabled        boolean not null default false,
    created_at      timestamptz not null default now()
);

create table if not exists sessions (
    token_hash      text primary key,         -- SHA-256 of the token; the token is never stored
    email           text not null references accounts (email) on delete cascade,
    expires_at      timestamptz not null
);

create index if not exists sessions_email on sessions (email);
