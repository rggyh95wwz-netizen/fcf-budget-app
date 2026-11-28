set client_min_messages = warning;
-- FCF Budget & Löhne – Datenbank für Supabase
-- Einmal im Supabase SQL Editor ausführen (ganzer Inhalt). Danach import.sql (Daten) ausführen.
-- Rollen: admin (alles), sportchef (alles ausser IBAN/AHV, Einstellungen, Auszahlungsstatus), trainer (eigene Teams).

-- ---------- Tabellen ----------
create table if not exists benutzer (
  email text primary key,
  rolle text not null default 'trainer' check (rolle in ('admin', 'sportchef', 'trainer')),
  "personId" text,
  aktiv boolean not null default true,
  notiz text
);

create table if not exists einstellungen (id int primary key default 1 check (id = 1), data json not null default '{}');

create table if not exists personen (
  id text primary key, anrede text, vorname text, nachname text, "ahvPflicht" text, eintritt numeric, aktiv boolean default true, notiz text
);
create table if not exists personen_privat (
  id text primary key references personen(id) on delete cascade,
  adresse text, plz text, ort text, email text, telefon text, iban text, "ahvNr" text
);
create table if not exists teams (id text primary key, name text, kategorie text, aktiv boolean default true);
create table if not exists funktionen (
  id text primary key, name text, bereich text, abrechnung text,
  spesenanteil numeric, "pauschaleHJ" numeric, "ansatzEinsatz" numeric, "bonusAb" numeric, bonus numeric
);
create table if not exists budgetpositionen (id text primary key, gruppe text, art text, name text);

create table if not exists saisons (id text primary key, name text, status text, notiz text);
create table if not exists zuordnungen (
  "saisonId" text not null references saisons(id) on delete cascade, id text not null,
  "personId" text, "teamId" text, "funktionId" text, rolle text,
  trainings numeric, spiele numeric, "einheitenBudget" numeric, grund numeric, js numeric, treue numeric, faktor numeric,
  "pauschaleH1" numeric, "pauschaleH2" numeric, "ansatzEinsatz" numeric, "budgetEinsaetze" numeric, "budgetManuell" numeric, notiz text,
  primary key ("saisonId", id)
);
create table if not exists teambudget (
  "saisonId" text not null references saisons(id) on delete cascade, "teamId" text not null, "positionId" text not null, betrag numeric,
  primary key ("saisonId", "teamId", "positionId")
);
create table if not exists team_eckdaten (
  "saisonId" text not null references saisons(id) on delete cascade, "teamId" text not null, feld text not null, wert numeric,
  primary key ("saisonId", "teamId", feld)
);
create table if not exists erfassung (
  "saisonId" text not null references saisons(id) on delete cascade, halbjahr text not null check (halbjahr in ('H1', 'H2')), "zuordnungId" text not null,
  einheiten numeric, einsaetze numeric, ok boolean, manuell numeric, korrektur numeric, bemerkung text,
  primary key ("saisonId", halbjahr, "zuordnungId")
);
create table if not exists belege (
  "saisonId" text not null references saisons(id) on delete cascade, halbjahr text not null check (halbjahr in ('H1', 'H2')), "personId" text not null,
  status text, datum text,
  primary key ("saisonId", halbjahr, "personId")
);
-- Reihenfolge der Anzeige (wie in der App sortiert)
alter table teams add column if not exists pos int;
alter table funktionen add column if not exists pos int;
alter table budgetpositionen add column if not exists pos int;
create index if not exists zuordnungen_person on zuordnungen ("personId");
create index if not exists zuordnungen_team on zuordnungen ("teamId");

-- ---------- Änderungsprotokoll: wer hat wann geändert ----------
create table if not exists meta (id int primary key default 1 check (id = 1), version bigint not null default 0, geaendert timestamptz, von text);
insert into meta (id) values (1) on conflict do nothing;
create table if not exists protokoll (id bigserial primary key, zeit timestamptz not null default now(), von text, tabelle text, aktion text, schluessel jsonb);

create or replace function protokolliere() returns trigger language plpgsql security definer set search_path = public as $$
declare r record; k jsonb;
begin
  if tg_op = 'DELETE' then r := old; else r := new; end if;
  select jsonb_object_agg(key, value) into k from jsonb_each(to_jsonb(r))
    where key in ('id', 'saisonId', 'halbjahr', 'teamId', 'positionId', 'feld', 'zuordnungId', 'personId', 'email');
  update meta set version = version + 1, geaendert = now(), von = auth.jwt() ->> 'email' where id = 1;
  insert into protokoll (von, tabelle, aktion, schluessel) values (auth.jwt() ->> 'email', tg_table_name, tg_op, k);
  return null;
end $$;

do $$ declare t text; begin
  foreach t in array array['benutzer','einstellungen','personen','personen_privat','teams','funktionen','budgetpositionen','saisons','zuordnungen','teambudget','team_eckdaten','erfassung','belege'] loop
    execute format('drop trigger if exists protokoll_trg on %I', t);
    execute format('create trigger protokoll_trg after insert or update or delete on %I for each row execute function protokolliere()', t);
  end loop;
end $$;

-- ---------- Wer bin ich? ----------
create or replace function app_rolle() returns text language sql stable security definer set search_path = public as $$
  select rolle from benutzer where lower(email) = lower(auth.jwt() ->> 'email') and aktiv
$$;
create or replace function app_person() returns text language sql stable security definer set search_path = public as $$
  select "personId" from benutzer where lower(email) = lower(auth.jwt() ->> 'email') and aktiv
$$;
create or replace function ist_admin() returns boolean language sql stable as $$ select coalesce(app_rolle() = 'admin', false) $$;
create or replace function ist_leitung() returns boolean language sql stable as $$ select coalesce(app_rolle() in ('admin', 'sportchef'), false) $$;
create or replace function ist_benutzer() returns boolean language sql stable as $$ select app_rolle() is not null $$;
-- Teams, in denen ich (in irgendeiner Saison) eine Zuordnung habe
create or replace function app_teams() returns setof text language sql stable security definer set search_path = public as $$
  select distinct "teamId" from zuordnungen where "personId" = app_person() and "personId" is not null
$$;
-- Personen, die in meinen Teams eine Zuordnung haben
create or replace function team_personen() returns setof text language sql stable security definer set search_path = public as $$
  select distinct "personId" from zuordnungen where "teamId" in (select app_teams()) and "personId" is not null
$$;
-- Meine Zuordnungen (für Erfassung)
create or replace function meine_zuordnung(sid text, zid text) returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from zuordnungen where "saisonId" = sid and id = zid and "personId" = app_person())
$$;

-- Ist mein Beleg für dieses Halbjahr schon ausbezahlt? Dann keine Änderungen mehr durch Trainer.
create or replace function ausbezahlt(sid text, hj text) returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from belege where "saisonId" = sid and halbjahr = hj and "personId" = app_person() and status = 'ausbezahlt')
$$;

-- Für die App: Rolle, Person und Datenstand
create or replace function app_info() returns json language sql stable security definer set search_path = public as $$
  select json_build_object('email', auth.jwt() ->> 'email', 'rolle', app_rolle(), 'personId', app_person(), 'version', (select version from meta where id = 1))
$$;
create or replace function data_version() returns bigint language sql stable security definer set search_path = public as $$
  select version from meta where id = 1
$$;
-- Besetzung meiner Teams (ohne Beträge), damit Trainer sehen, wer im Team mitarbeitet
create or replace function team_besetzung() returns table ("saisonId" text, "teamId" text, "personId" text, vorname text, nachname text, rolle text, funktion text)
language sql stable security definer set search_path = public as $$
  select z."saisonId", z."teamId", z."personId", p.vorname, p.nachname, z.rolle, f.name
  from zuordnungen z left join personen p on p.id = z."personId" left join funktionen f on f.id = z."funktionId"
  where ist_benutzer() and (ist_leitung() or z."teamId" in (select app_teams()))
$$;

-- Trainer dürfen bei der Erfassung nur Einheiten/Einsätze/Bemerkung setzen, nicht "bestätigt", "Betrag manuell" oder "Korrektur"
create or replace function erfassung_schutz() returns trigger language plpgsql as $$
begin
  if auth.jwt() ->> 'email' is not null and not ist_leitung() then
    if tg_op = 'INSERT' then new.ok := null; new.manuell := null; new.korrektur := null;
    else new.ok := old.ok; new.manuell := old.manuell; new.korrektur := old.korrektur; end if;
  end if;
  return new;
end $$;
drop trigger if exists erfassung_schutz on erfassung;
create trigger erfassung_schutz before insert or update on erfassung for each row execute function erfassung_schutz();

-- ---------- Regeln (Row Level Security) ----------
do $$ declare t text; begin
  foreach t in array array['benutzer','einstellungen','personen','personen_privat','teams','funktionen','budgetpositionen','saisons','zuordnungen','teambudget','team_eckdaten','erfassung','belege','meta','protokoll'] loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists lesen on %I', t);
    execute format('drop policy if exists schreiben on %I', t);
    execute format('drop policy if exists aendern on %I', t);
    execute format('drop policy if exists loeschen on %I', t);
  end loop;
end $$;

-- Benutzer: nur Admin verwaltet; jede Person sieht den eigenen Eintrag
create policy lesen on benutzer for select using (ist_admin() or lower(email) = lower(auth.jwt() ->> 'email'));
create policy schreiben on benutzer for all using (ist_admin()) with check (ist_admin());

-- Allgemeine Stammdaten: alle Angemeldeten lesen, Leitung schreibt
create policy lesen on teams for select using (ist_benutzer());
create policy schreiben on teams for all using (ist_leitung()) with check (ist_leitung());
create policy lesen on funktionen for select using (ist_benutzer());
create policy schreiben on funktionen for all using (ist_leitung()) with check (ist_leitung());
create policy lesen on budgetpositionen for select using (ist_benutzer());
create policy schreiben on budgetpositionen for all using (ist_leitung()) with check (ist_leitung());
create policy lesen on saisons for select using (ist_benutzer());
create policy schreiben on saisons for all using (ist_leitung()) with check (ist_leitung());
create policy lesen on einstellungen for select using (ist_benutzer());
create policy schreiben on einstellungen for all using (ist_admin()) with check (ist_admin());

-- Personen: Leitung alle; Trainer sich selbst und die Personen in den eigenen Teams (nur Name)
create policy lesen on personen for select using (
  ist_leitung() or id = app_person()
  or id in (select team_personen()));
create policy schreiben on personen for all using (ist_leitung()) with check (ist_leitung());

-- Adresse, IBAN, AHV-Nr: nur Admin und die Person selbst
create policy lesen on personen_privat for select using (ist_admin() or id = app_person());
create policy schreiben on personen_privat for insert with check (ist_admin() or id = app_person());
create policy aendern on personen_privat for update using (ist_admin() or id = app_person()) with check (ist_admin() or id = app_person());
create policy loeschen on personen_privat for delete using (ist_admin());

-- Zuordnungen (Ansätze, Budget): Leitung alle, Trainer nur die eigenen
create policy lesen on zuordnungen for select using (ist_leitung() or "personId" = app_person());
create policy schreiben on zuordnungen for all using (ist_leitung()) with check (ist_leitung());

-- Teambudget und Eckdaten: Leitung alle, Trainer die eigenen Teams (nur lesen)
create policy lesen on teambudget for select using (ist_leitung() or "teamId" in (select app_teams()));
create policy schreiben on teambudget for all using (ist_leitung()) with check (ist_leitung());
create policy lesen on team_eckdaten for select using (ist_leitung() or "teamId" in (select app_teams()));
create policy schreiben on team_eckdaten for all using (ist_leitung()) with check (ist_leitung());

-- Erfassung: Leitung alle; Trainer liest und erfasst die eigenen Einheiten/Einsätze, solange nicht ausbezahlt
create policy lesen on erfassung for select using (ist_leitung() or meine_zuordnung("saisonId", "zuordnungId"));
create policy schreiben on erfassung for insert with check (ist_leitung() or (meine_zuordnung("saisonId", "zuordnungId") and not ausbezahlt("saisonId", halbjahr)));
create policy aendern on erfassung for update using (ist_leitung() or (meine_zuordnung("saisonId", "zuordnungId") and not ausbezahlt("saisonId", halbjahr)))
  with check (ist_leitung() or (meine_zuordnung("saisonId", "zuordnungId") and not ausbezahlt("saisonId", halbjahr)));
create policy loeschen on erfassung for delete using (ist_leitung());

-- Belege / Auszahlung: Leitung liest alle, Admin setzt den Status; Trainer sieht die eigenen
create policy lesen on belege for select using (ist_leitung() or "personId" = app_person());
create policy schreiben on belege for all using (ist_admin()) with check (ist_admin());

-- Protokoll: nur Admin
create policy lesen on protokoll for select using (ist_admin());

-- ---------- Zugriff über die API (unabhängig von den Projekteinstellungen) ----------
grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;
grant execute on all functions in schema public to authenticated;
revoke all on all tables in schema public from anon;

-- Härtung (Supabase Security Advisor)
alter function public.ist_admin() set search_path = public;
alter function public.ist_leitung() set search_path = public;
alter function public.ist_benutzer() set search_path = public;
alter function public.erfassung_schutz() set search_path = public;
revoke execute on function public.app_info(), public.app_person(), public.app_rolle(), public.app_teams(), public.ausbezahlt(text, text), public.data_version(), public.meine_zuordnung(text, text), public.protokolliere(), public.team_besetzung(), public.team_personen() from public, anon;
revoke execute on function public.protokolliere() from authenticated;
