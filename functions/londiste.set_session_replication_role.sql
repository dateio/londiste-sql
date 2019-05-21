
create or replace function londiste.set_session_replication_role(val text, is_local bool) returns void as $$
begin
end;
$$ language plpgsql security definer;

grant execute on function londiste.set_session_replication_role(text, bool) to londiste_writer;
