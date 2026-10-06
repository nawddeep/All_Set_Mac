-- All Set — cloud catalog schema (Neon Postgres).
-- Metadata only. Actual files (video/still/thumbnail) live in object storage
-- (Cloudflare R2); this table holds a storage key pointing at each one.
-- Mirrors Sources/AllSetCore/Wallpaper/WallpaperLibrary.swift's LibraryVideo —
-- keep the two in sync by hand; there's no codegen between them.

create table if not exists wallpapers (
    id              text primary key,        -- first 16 hex of content SHA-256
    title           text not null,
    kind            text not null check (kind in ('video', 'image')),
    category        text not null,
    tags            text[] not null default '{}',

    -- Local provenance (where it came from on the Mac) — kept for reference,
    -- not needed at run time once the cloud copy exists.
    origin_root     text,
    origin_file     text,

    -- Object storage keys (R2), one per rendered asset. Null until that
    -- asset has actually been uploaded.
    playback_key    text,
    still_key       text,
    thumbnail_key   text,

    duration        double precision,
    width           integer,
    height          integer,
    fps             double precision,
    size_bytes      bigint,

    status          text not null default 'quarantined'
                        check (status in ('quarantined', 'published', 'unsupported')),
    status_reason   text,

    -- Provenance.{source, workshopId, originalTitle, author, license}
    provenance      jsonb,

    content_rating  text,
    added_at        timestamptz,

    -- Bookkeeping for this sync, not part of LibraryVideo.
    uploaded_at     timestamptz,              -- when playback_key etc. were last confirmed in R2
    synced_at       timestamptz not null default now()
);

create index if not exists wallpapers_category_idx on wallpapers (category);
create index if not exists wallpapers_kind_idx on wallpapers (kind);
create index if not exists wallpapers_tags_idx on wallpapers using gin (tags);
