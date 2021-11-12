
set client_min_messages = 'warning';
\set VERBOSITY 'terse'

\set ECHO none

create or replace function mkcascade(
    roots text[],
    branches text[], branch_target text,
    leafs text[], leaf_target text,
    tbls text[])
returns text as $$
declare
    node text;
    qname text;
    status int4;
    msg text;
    tbl text;
begin
    for node in select unnest(roots) loop
        qname := node;
        perform pgq_node.register_location(qname, node, 'dbname=' || node, false);
        perform pgq_node.create_node(qname, 'root', node, node || '_worker', null, null, null);
        for tbl in select unnest(tbls) loop
            select ret_code, ret_note into status, msg from londiste.global_add_table(node, tbl);
            if status != 200 then
                raise exception 'global_add_table - %/%', status, msg;
            end if;
        end loop;
    end loop;

    for node in select unnest(branches) loop
        qname := node;
        perform pgq_node.register_location(qname, node, 'dbname=' || node, false);
        perform pgq_node.register_location(qname, node||'-provider', 'dbname=' || node, false);
        perform pgq_node.create_node(qname, 'branch', node, node || '_worker', node||'-provider', 10, branch_target);
        for tbl in select unnest(tbls) loop
            select ret_code, ret_note into status, msg from londiste.global_add_table(node, tbl);
            if status != 200 then
                raise exception 'global_add_table - %/%', status, msg;
            end if;
        end loop;
    end loop;

    for node in select unnest(leafs) loop
        qname := node;
        perform pgq_node.register_location(qname, node, 'dbname=' || node, false);
        perform pgq_node.register_location(qname, node||'-provider', 'dbname=' || node, false);
        perform pgq_node.create_node(qname, 'leaf', node, node || '_worker', node||'-provider', 11, leaf_target);

        for tbl in select unnest(tbls) loop
            select ret_code, ret_note into status, msg from londiste.global_add_table(node, tbl);
            if status != 200 then
                raise exception 'global_add_table - %/%', status, msg;
            end if;
        end loop;
    end loop;
    return 'done';
end;
$$ language plpgsql;

\set ECHO all

-- leaf1/leaf2->root

\set target 'fx1-target'
\set leaf1 'fx1-leaf1'
\set leaf2 'fx1-leaf2'
\set tbl1 'fx1.table1'
\set tbl2 'fx1.table2'

select mkcascade(array[:'target'], array[]::text[], null, array[:'leaf1', :'leaf2'], :'target', array[:'tbl1', :'tbl2']);

insert into londiste.pending_fkeys values (:'tbl1', :'tbl2', 'name', 'def');
select * from londiste.get_table_pending_fkeys(:'tbl1');

update londiste.table_info set merge_state='ok', local=true where table_name in (:'tbl1', :'tbl2');
select * from londiste.get_valid_pending_fkeys(:'target');
select * from londiste.get_valid_pending_fkeys(:'leaf1'); -- pick
select * from londiste.get_valid_pending_fkeys(:'leaf2');

update londiste.table_info set merge_state='catching-up' where table_name = :'tbl1' and queue_name = :'leaf1';
select * from londiste.get_valid_pending_fkeys(:'target');
select * from londiste.get_valid_pending_fkeys(:'leaf1'); -- no
select * from londiste.get_valid_pending_fkeys(:'leaf2');

update londiste.table_info set merge_state=null, local=false where table_name = :'tbl1' and queue_name = :'leaf1';
select * from londiste.get_valid_pending_fkeys(:'target');
select * from londiste.get_valid_pending_fkeys(:'leaf1'); -- pick
select * from londiste.get_valid_pending_fkeys(:'leaf2');

update londiste.table_info set merge_state=null, local=false where table_name = :'tbl2' and queue_name = :'leaf1';
select * from londiste.get_valid_pending_fkeys(:'target');
select * from londiste.get_valid_pending_fkeys(:'leaf1');
select * from londiste.get_valid_pending_fkeys(:'leaf2'); -- pick?

-- leaf1/leaf2->branch

\set target 'fx2-branch'
\set leaf1 'fx2-leaf1'
\set leaf2 'fx2-leaf2'
\set tbl1 'fx2.table1'
\set tbl2 'fx2.table2'

select mkcascade(array[]::text[], array[:'target']::text[], null, array[:'leaf1', :'leaf2'], :'target', array[:'tbl1', :'tbl2']);

insert into londiste.pending_fkeys values (:'tbl1', :'tbl2', 'name', 'def');
select * from londiste.get_table_pending_fkeys(:'tbl1');

update londiste.table_info set merge_state='ok', local=true where table_name in (:'tbl1', :'tbl2');
select * from londiste.get_valid_pending_fkeys(:'target'); -- pick
select * from londiste.get_valid_pending_fkeys(:'leaf1');
select * from londiste.get_valid_pending_fkeys(:'leaf2');

update londiste.table_info set merge_state='catching-up' where table_name = :'tbl1' and queue_name = :'leaf1';
select * from londiste.get_valid_pending_fkeys(:'target'); -- no
select * from londiste.get_valid_pending_fkeys(:'leaf1');
select * from londiste.get_valid_pending_fkeys(:'leaf2');

update londiste.table_info set merge_state=null, local=false where table_name = :'tbl1' and queue_name = :'leaf1';
select * from londiste.get_valid_pending_fkeys(:'target'); -- pick
select * from londiste.get_valid_pending_fkeys(:'leaf1');
select * from londiste.get_valid_pending_fkeys(:'leaf2');


-- leaf1/leaf2->no branch

\set leaf1 'fx3-leaf1'
\set leaf2 'fx3-leaf2'
\set tbl1 'fx3.table1'
\set tbl2 'fx3.table2'

select mkcascade(array[]::text[], array[]::text[], null, array[:'leaf1', :'leaf2'], null, array[:'tbl1', :'tbl2']);

insert into londiste.pending_fkeys values (:'tbl1', :'tbl2', 'name', 'def');
select * from londiste.get_table_pending_fkeys(:'tbl1');

update londiste.table_info set merge_state='ok', local=true where table_name in (:'tbl1', :'tbl2');
select * from londiste.get_valid_pending_fkeys(:'leaf1'); -- pick
select * from londiste.get_valid_pending_fkeys(:'leaf2');

update londiste.table_info set merge_state='catching-up' where table_name = :'tbl1' and queue_name = :'leaf1';
select * from londiste.get_valid_pending_fkeys(:'leaf1');
select * from londiste.get_valid_pending_fkeys(:'leaf2');

update londiste.table_info set merge_state=null, local=false where table_name = :'tbl1' and queue_name = :'leaf1';
select * from londiste.get_valid_pending_fkeys(:'leaf1'); -- pick
select * from londiste.get_valid_pending_fkeys(:'leaf2');

update londiste.table_info set merge_state=null, local=false where table_name = :'tbl2' and queue_name = :'leaf1';
select * from londiste.get_valid_pending_fkeys(:'leaf1');
select * from londiste.get_valid_pending_fkeys(:'leaf2'); -- pick


