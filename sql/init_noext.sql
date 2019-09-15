\set ECHO none

set log_error_verbosity = 'terse';
create or replace language plpgsql;
set client_min_messages = 'warning';

-- \i ../txid/txid.sql
\i ../pgq/pgq.sql
\i ../pgq_node/pgq_node.sql

\i londiste.sql

\set ECHO all

