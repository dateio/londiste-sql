
create or replace function londiste.set_session_replication_role(val text, is_local bool) returns void as $$
begin
    if is_local then
        if val = 'origin' then
            set local session_replication_role = 'origin';
        elsif val = 'replica' then
            set local session_replication_role = 'replica';
        elsif val = 'local' then
            set local session_replication_role = 'local';
        else
            raise exception 'bad value for session_replication_role';
        end if;
    else
        if val = 'origin' then
            set session_replication_role = 'origin';
        elsif val = 'replica' then
            set session_replication_role = 'replica';
        elsif val = 'local' then
            set session_replication_role = 'local';
        else
            raise exception 'bad value for session_replication_role';
        end if;
    end if;
end;
$$ language plpgsql security definer;

