-- ==========================================================
-- Set environment variable (change here for DEV / TST / PRD)
-- ==========================================================
SET env = 'DEV';

-- ==========================================================
-- Switch to SYSADMIN role
-- ==========================================================
USE ROLE SYSADMIN;

-- ==========================================================
-- 1. Create an Extra Small Warehouse
-- ==========================================================
CREATE WAREHOUSE IF NOT EXISTS GENERAL_XS_WH
WITH WAREHOUSE_SIZE = 'XSMALL'
AUTO_SUSPEND = 60
AUTO_RESUME = TRUE
INITIALLY_SUSPENDED = TRUE;

USE WAREHOUSE GENERAL_XS_WH;
-- ==========================================================
-- 2. Create the NACC_DEV Database
-- ==========================================================
SET env_db = 'NACC_'||$env;

CREATE DATABASE IF NOT EXISTS IDENTIFIER($env_db);

USE DATABASE IDENTIFIER($env_db);
-- ==========================================================
-- 3. Create Schemas in the NACC Database
-- ==========================================================
CREATE SCHEMA IF NOT EXISTS NACC;
CREATE SCHEMA IF NOT EXISTS NACC_FIN;
CREATE SCHEMA IF NOT EXISTS NACC_OPS;
CREATE SCHEMA IF NOT EXISTS NACC_HR;

-- ==========================================================
-- 4. Create Roles
-- ==========================================================
USE ROLE USERADMIN;

BEGIN
  DECLARE env_local STRING := GET_VARIABLE('env');
  DECLARE role_name STRING;

  -- Loop over your dynamic list of role names based on schemas
  FOR rec IN
    (
      SELECT
        CASE 
          WHEN schema_name = 'NACC' THEN 'EDP'
          ELSE REPLACE(schema_name, 'NACC_', '')
        END || '_' || env_local || '_RO' AS role_name
      FROM information_schema.schemata
      WHERE catalog_name = CURRENT_DATABASE()
        AND schema_name LIKE 'NACC%'
    )
  DO
    -- For each role_name from the query, run CREATE ROLE IF NOT EXISTS
    CREATE ROLE IF NOT EXISTS rec.role_name;
  END FOR;
END;


DECLARE
    c1 CURSOR FOR SELECT price FROM invoices;
BEGIN
    total_price := 0.0;
    OPEN c1;
    FOR rec IN c1 DO
        total_price := total_price + rec.price;
    END FOR;
    CLOSE c1;
    RETURN total_price;
END;


BEGIN
    LET env_local STRING = $env;
    LET prefixes ARRAY = ARRAY_CONSTRUCT('FIN', 'OPS', 'HR', 'EDP');

    FOR idx INT IN 0 .. ARRAY_SIZE(prefixes)-1 DO
        LET role_name STRING = prefixes[idx] || '_' || env_local || '_RO';
        CREATE ROLE IF NOT EXISTS role_name;
    END FOR;

    -- Grant child roles to parent
    FOR idx INT IN 0 .. 2 DO  -- FIN, OPS, HR only
        LET child STRING = prefixes[idx] || '_' || env_local || '_RO';
        LET parent STRING = 'EDP_' || env_local || '_RO';
        GRANT ROLE child TO ROLE parent;
    END FOR;
END;


CREATE ROLE IF NOT EXISTS IDENTIFIER('FIN_' || $env ||'_RO');
CREATE ROLE IF NOT EXISTS IDENTIFIER('OPS_' || $env ||'_RO');
CREATE ROLE IF NOT EXISTS IDENTIFIER('HR_' || $env ||'_RO');
CREATE ROLE IF NOT EXISTS IDENTIFIER('EDP_' || $env ||'_RO');
CREATE ROLE IF NOT EXISTS IDENTIFIER('EDP_' || $env ||'_RW');

-- ==========================================================
-- 5. Assign Roles to Parent Role
-- ==========================================================
GRANT ROLE IDENTIFIER('FIN_' || $env ||'_RO') TO ROLE IDENTIFIER('EDP_' || $env ||'_RO');
GRANT ROLE IDENTIFIER('OPS_' || $env ||'_RO') TO ROLE IDENTIFIER('EDP_' || $env ||'_RO');
GRANT ROLE IDENTIFIER('HR_' || $env ||'_RO') TO ROLE IDENTIFIER('EDP_' || $env ||'_RO');
GRANT ROLE IDENTIFIER('EDP_' || $env ||'_RO') TO ROLE IDENTIFIER('EDP_' || $env ||'_RW');
GRANT ROLE IDENTIFIER('EDP_' || $env ||'_RW') TO ROLE SYSADMIN;

-- ==========================================================
-- 6. (Optional) Grant Warehouse Usage to Parent Role
-- ==========================================================
GRANT USAGE ON WAREHOUSE GENERAL_XS_WH TO ROLE IDENTIFIER('EDP_' || $env ||'_RW');

-- ==========================================================
-- 7. (Optional) Grant Database/Schema Privileges to Roles
-- ==========================================================
-- Example: Give FIN_DEV_RO read-only access to NACC_FIN schema
GRANT USAGE ON DATABASE NACC_DEV TO ROLE FIN_DEV_RO;
GRANT USAGE ON SCHEMA NACC_DEV.NACC_FIN TO ROLE FIN_DEV_RO;
GRANT SELECT ON ALL TABLES IN SCHEMA NACC_DEV.NACC_FIN TO ROLE FIN_DEV_RO;
GRANT SELECT ON FUTURE TABLES IN SCHEMA NACC_DEV.NACC_FIN TO ROLE FIN_DEV_RO;

-- Repeat for HR_DEV_RO as needed...
GRANT USAGE ON DATABASE NACC_DEV TO ROLE HR_DEV_RO;
GRANT USAGE ON SCHEMA NACC_DEV.NACC_HR TO ROLE HR_DEV_RO;
GRANT SELECT ON ALL TABLES IN SCHEMA NACC_DEV.NACC_HR TO ROLE HR_DEV_RO;
GRANT SELECT ON FUTURE TABLES IN SCHEMA NACC_DEV.NACC_HR TO ROLE HR_DEV_RO;

-- Repeat for OPS_DEV_RO 
GRANT USAGE ON DATABASE NACC_DEV TO ROLE OPS_DEV_RO;
GRANT USAGE ON SCHEMA NACC_DEV.NACC_OPS TO ROLE OPS_DEV_RO;
GRANT SELECT ON ALL TABLES IN SCHEMA NACC_DEV.NACC_OPS TO ROLE OPS_DEV_RO;
GRANT SELECT ON FUTURE TABLES IN SCHEMA NACC_DEV.NACC_OPS TO ROLE OPS_DEV_RO;
