CREATE EXTENSION IF NOT EXISTS dblink;

DROP FUNCTION IF EXISTS create_role_if_not_exists(TEXT);
CREATE FUNCTION create_role_if_not_exists(IN name TEXT)
RETURNS VOID AS $$
BEGIN
IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = name) THEN
  EXECUTE format('CREATE ROLE %I', name);
END IF;
END;
$$ LANGUAGE PLPGSQL;

DROP FUNCTION IF EXISTS create_db_if_not_exists(TEXT);
CREATE FUNCTION create_db_if_not_exists(IN dbname TEXT)
RETURNS VOID AS $$
DECLARE port INT;
DECLARE junk TEXT;
BEGIN
IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_database WHERE datname = dbname) THEN
  SELECT setting FROM pg_settings WHERE name = 'port' INTO port;
  SELECT dblink_exec('user=postgres dbname=postgres port=' || port, 'CREATE DATABASE ' || quote_ident(dbname)) INTO junk;
END IF;
END;
$$ LANGUAGE PLPGSQL;

