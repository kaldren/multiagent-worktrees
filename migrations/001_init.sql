create table if not exists features (
  id          serial primary key,
  title       text not null,
  status      text not null default 'todo' check (status in ('todo', 'doing', 'done')),
  created_by  text not null,
  created_at  timestamptz not null default now()
);
