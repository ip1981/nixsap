-- These procedures belong to the mysql DB, e. g.
-- CALL mysql.resetSlave('foo');
-- Keep it simple: each procedure should be self-contained.

DELIMITER $$

DROP PROCEDURE IF EXISTS stopSlave $$
CREATE PROCEDURE stopSlave (IN ch VARCHAR(64))
  COMMENT 'Stops slave channel (both I/O and SQL threads)'
BEGIN
  -- Ignore ERROR 1617 (HY000): There is no master connection 'foo'
  DECLARE EXIT HANDLER FOR 1617
    BEGIN
      SELECT 'No such master connection'
        AS warning;
    END;

  SET default_master_connection = ch;
  STOP SLAVE;
END $$

DROP PROCEDURE IF EXISTS startSlave $$
CREATE PROCEDURE startSlave (IN ch VARCHAR(64))
  COMMENT 'Starts slave channel (both I/O and SQL threads)'
BEGIN
  DECLARE EXIT HANDLER FOR 1617
    BEGIN
      SELECT 'No such master connection'
        AS warning;
    END;

  SET default_master_connection = ch;
  START SLAVE;
END $$

DROP PROCEDURE IF EXISTS kickSlave $$
CREATE PROCEDURE kickSlave (IN ch VARCHAR(64))
  COMMENT 'Skips the next event from the master'
BEGIN
  DECLARE EXIT HANDLER FOR 1617
    BEGIN
      SELECT 'No such master connection'
        AS warning;
    END;

  SET default_master_connection = ch;
  STOP SLAVE;
  SET GLOBAL sql_slave_skip_counter = 1;
  START SLAVE;
END $$

DROP PROCEDURE IF EXISTS pauseSlave $$
CREATE PROCEDURE pauseSlave (IN ch VARCHAR(64))
  COMMENT 'Stops SQL thread of the slave channel'
BEGIN
  DECLARE EXIT HANDLER FOR 1617
    BEGIN
      SELECT 'No such master connection'
        AS warning;
    END;

  SET default_master_connection = ch;
  STOP SLAVE SQL_THREAD;
END $$

DROP PROCEDURE IF EXISTS resetSlave $$
CREATE PROCEDURE resetSlave (IN ch VARCHAR(64))
  COMMENT 'Stops and deletes slave channel'
BEGIN
  DECLARE EXIT HANDLER FOR 1617
    BEGIN
      SELECT 'No such master connection'
        AS warning;
    END;

  SET default_master_connection = ch;
  STOP SLAVE;
  RESET SLAVE ALL;
END $$

DROP PROCEDURE IF EXISTS stopAllSlaves $$
CREATE PROCEDURE stopAllSlaves ()
  COMMENT 'Stops all slaves'
BEGIN
  STOP ALL SLAVES;
END $$

DROP PROCEDURE IF EXISTS pauseAllSlaves $$
CREATE PROCEDURE pauseAllSlaves ()
  COMMENT 'Stops SQL thread of all slaves'
BEGIN
  STOP ALL SLAVES SQL_THREAD;
END $$

DROP PROCEDURE IF EXISTS startAllSlaves $$
CREATE PROCEDURE startAllSlaves ()
  COMMENT 'Starts all slaves'
BEGIN
  START ALL SLAVES;
END $$

DROP PROCEDURE IF EXISTS enableGeneralLog $$
CREATE PROCEDURE enableGeneralLog ()
BEGIN
  SET GLOBAL general_log = ON;
END $$

DROP PROCEDURE IF EXISTS disableGeneralLog $$
CREATE PROCEDURE disableGeneralLog ()
BEGIN
  SET GLOBAL general_log = OFF;
END $$

DROP PROCEDURE IF EXISTS truncateGeneralLog $$
CREATE PROCEDURE truncateGeneralLog ()
BEGIN
  TRUNCATE mysql.general_log;
END $$

DROP PROCEDURE IF EXISTS truncateSlowLog $$
CREATE PROCEDURE truncateSlowLog ()
BEGIN
  TRUNCATE mysql.slow_log;
END $$

DROP PROCEDURE IF EXISTS showEvents $$
CREATE PROCEDURE showEvents ()
  COMMENT 'Shows all events for the mysql schema'
BEGIN
  SHOW EVENTS IN mysql;
END $$

DELIMITER ;

