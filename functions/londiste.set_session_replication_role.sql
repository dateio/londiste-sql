
create or replace function londiste.set_session_replication_role(val text, is_local bool) returns void as $$
begin
    perform set_config('session_replication_role', val, is_local);
end;
$$ language plpgsql security definer;

