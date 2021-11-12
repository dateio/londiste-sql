
create or replace function londiste.get_table_pending_fkeys(i_table_name text) 
returns setof londiste.pending_fkeys as $$
-- ----------------------------------------------------------------------
-- Function: londiste.get_table_pending_fkeys(1)
--
--      Return dropped fkeys for table.
--
-- Parameters:
--      i_table_name - fqname
--
-- Returns:
--      desc
-- ----------------------------------------------------------------------
declare
    fkeys   record;
begin
    for fkeys in
        select *
        from londiste.pending_fkeys
        where from_table = i_table_name or to_table = i_table_name
        order by 1,2,3
    loop
        return next fkeys;
    end loop;
    return;
end;
$$ language plpgsql strict stable;


create or replace function londiste.get_valid_pending_fkeys(i_queue_name text)
returns setof londiste.pending_fkeys as $$
-- ----------------------------------------------------------------------
-- Function: londiste.get_valid_pending_fkeys(1)
--
--      Returns dropped fkeys where both sides are in sync now.
--
-- Parameters:
--      i_queue_name - cascaded queue name
--
-- Returns:
--      desc
-- ----------------------------------------------------------------------
declare
    fkeys           record;
    from_info       record;
    to_info         record;
    min_queue_name  text;
begin
    for fkeys in
        select pf.*
        from londiste.pending_fkeys pf
        order by from_table, to_table, fkey_name
    loop
        select count(1) as num_total,
            sum(case when t.queue_name = i_queue_name then 1 else 0 end) as num_matching,
            sum(case when t.merge_state = 'ok' and t.custom_snapshot is null then 1 else 0 end) as num_ok
           from londiste.table_info t
          where coalesce(t.dest_table, t.table_name) = fkeys.from_table
            and t.local
          into from_info;

        -- skip fkeys without known status
        if from_info.num_total = 0 then
            continue;
        end if;

        select count(1) as num_total,
            sum(case when t.queue_name = i_queue_name then 1 else 0 end) as num_matching,
            sum(case when t.merge_state = 'ok' and t.custom_snapshot is null then 1 else 0 end) as num_ok
           from londiste.table_info t
          where coalesce(t.dest_table, t.table_name) = fkeys.to_table
            and t.local
          into to_info;

        -- skip fkeys without known status
        if to_info.num_total = 0 then
            continue;
        end if;

        -- skip if not all copies are finished
        if from_info.num_ok < from_info.num_total then
            continue;
        end if;
        if to_info.num_ok < to_info.num_total then
            continue;
        end if;

        -- skip if table is not owned by i_queue_name
        if from_info.num_matching = 0 and to_info.num_matching = 0 then
            continue;
        end if;

        -- pick right queue
        -- combined_root: first leaf node
        -- combined_branch: branch node
        -- default: first node
        select coalesce(
            min(case when c.node_type = 'root' then t.queue_name else null end),
            min(case when c.node_type = 'branch' then c.queue_name else null end),
            min(t.queue_name))
          into min_queue_name
          from londiste.table_info t
          join pgq_node.node_info n on (n.queue_name = t.queue_name)
          left join pgq_node.node_info c on (c.queue_name = n.combined_queue)
         where coalesce(t.dest_table, t.table_name) in (fkeys.to_table, fkeys.from_table)
           and t.local;

        if i_queue_name = min_queue_name then
            return next fkeys;
        end if;
    end loop;
    
    return;
end;
$$ language plpgsql strict stable;


create or replace function londiste.drop_table_fkey(i_from_table text, i_fkey_name text)
returns integer as $$
-- ----------------------------------------------------------------------
-- Function: londiste.drop_table_fkey(2)
--
--      Drop one fkey, save in pending table.
-- ----------------------------------------------------------------------
declare
    fkey       record;
begin        
    select * into fkey
    from londiste.find_table_fkeys(i_from_table) 
    where fkey_name = i_fkey_name and from_table = i_from_table;
    
    if not found then
        return 0;
    end if;
            
    insert into londiste.pending_fkeys values (fkey.from_table, fkey.to_table, i_fkey_name, fkey.fkey_def);
        
    execute 'alter table only ' || londiste.quote_fqname(fkey.from_table)
            || ' drop constraint ' || quote_ident(i_fkey_name);
    
    return 1;
end;
$$ language plpgsql strict;


create or replace function londiste.restore_table_fkey(i_from_table text, i_fkey_name text)
returns integer as $$
-- ----------------------------------------------------------------------
-- Function: londiste.restore_table_fkey(2)
--
--      Restore dropped fkey.
--
-- Parameters:
--      i_from_table - source table
--      i_fkey_name  - fkey name
--
-- Returns:
--      nothing
-- ----------------------------------------------------------------------
declare
    fkey    record;
begin
    select * into fkey
    from londiste.pending_fkeys 
    where fkey_name = i_fkey_name and from_table = i_from_table
    for update;
    
    if not found then
        return 0;
    end if;

    execute fkey.fkey_def;

    delete from londiste.pending_fkeys where fkey_name = fkey.fkey_name;
        
    return 1;
end;
$$ language plpgsql strict;

