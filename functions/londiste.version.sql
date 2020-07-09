
create or replace function londiste.version()
returns text as $$
-- ----------------------------------------------------------------------
-- Function: londiste.version(0)
--
--      Returns version string for londiste.
-- ----------------------------------------------------------------------
declare
    _vers text;
begin
    select extversion from pg_catalog.pg_extension
        where extname = 'londiste' into _vers;
    return _vers;
end;
$$ language plpgsql;

