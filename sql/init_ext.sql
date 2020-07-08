\set ECHO none

set log_error_verbosity = 'terse';
set client_min_messages = 'warning';

create extension pgq;
create extension pgq_node;

\set ECHO all

create extension londiste;
select array_length(extconfig, 1) as dumpable from pg_catalog.pg_extension where extname = 'londiste';

