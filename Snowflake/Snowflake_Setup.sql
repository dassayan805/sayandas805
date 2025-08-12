CREATE OR REPLACE DATABASE sb_project_db;
CREATE OR REPLACE SCHEMA raw_data;
CREATE OR REPLACE WAREHOUSE sb_warehouse WITH WAREHOUSE_SIZE = 'X-SMALL' AUTO_SUSPEND = 60;

create or replace stage sb_project_db.raw_data.sb_named_stage;
show stages;
list @sb_project_db.raw_data.sb_named_stage;

create or replace sequence sb_project_db.raw_data.seq_id start=1 increment=1;

create or replace hybrid table sb_project_db.raw_data.hybrid_table(
id INT AUTOINCREMENT,
json_file variant,
filename string,
sync_ind string default 'N',
insert_ts TIMESTAMP default current_timestamp()
);

create or replace table sb_project_db.raw_data.temp_table(
POST_ID INT
,POST_TITLE String
,USER_ID INT
,USER_NAME String
,USER_CITY String
);

CREATE OR REPLACE TABLE sb_project_db.raw_data.proc_logs (
    log_id INT AUTOINCREMENT,
    procedure_name STRING,
    run_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    rows_processed INT,
    status STRING,  -- 'SUCCESS', 'FAILED'
    error_message STRING,
    affected_post_ids ARRAY,  -- Track which records were processed
    duration_seconds FLOAT
);

CREATE OR REPLACE TABLE sb_project_db.raw_data.sb_users (
USER_ID INT
,USER_NAME String
,USER_CITY String
);

alter table sb_project_db.raw_data.sb_users set data_retention_time_in_days=90;

CREATE OR REPLACE TABLE sb_project_db.raw_data.sb_processed_data (
SL_no INT default sb_project_db.raw_data.seq_id.nextval
,POST_ID INT
,POST_TITLE String
,USER_ID INT
,process_ts TIMESTAMP default current_timestamp()
);

alter table sb_project_db.raw_data.sb_processed_data set data_retention_time_in_days=90;

create or replace file format sb_project_db.raw_data.sb_format
type='JSON';

create or replace pipe sb_project_db.raw_data.sb_pipe
auto_ingest=false
as
copy into sb_project_db.raw_data.hybrid_table(json_file,filename)
from (
    SELECT 
        $1,  -- Load full JSON into VARIANT column
        METADATA$FILENAME
    FROM @sb_project_db.raw_data.sb_named_stage)
file_format=sb_project_db.raw_data.sb_format
;

create or replace task sb_task
warehouse = sb_warehouse
schedule = '5 MINUTE'
as
alter pipe sb_project_db.raw_data.sb_pipe refresh;

alter task sb_task resume;

create or replace stream sb_project_db.raw_data.sb_stream
on table sb_project_db.raw_data.hybrid_table;

drop procedure if exists sb_project_db.raw_data.sb_proc();
CREATE OR REPLACE PROCEDURE sb_project_db.raw_data.sb_proc()
  RETURNS STRING
  LANGUAGE SQL
AS
$$
DECLARE
  rows_processed INT DEFAULT 0;
  result_message STRING DEFAULT '';
  proc_start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  post_ids ARRAY DEFAULT [];
  error_msg STRING DEFAULT '';
  rows_affected INT DEFAULT 0;

BEGIN
  set proc_start_time := CURRENT_TIMESTAMP();
  INSERT INTO sb_project_db.raw_data.proc_logs 
    (procedure_name, status, run_timestamp)
  VALUES 
    ('sb_proc', 'STARTED', :proc_start_time);

  BEGIN
    -- Clear temp table
    DELETE FROM sb_project_db.raw_data.temp_table;
    rows_affected := SQLROWCOUNT;
    
    SELECT COUNT(*) INTO rows_processed 
    FROM sb_project_db.raw_data.hybrid_table 
    WHERE sync_ind IN ('N','P');

    IF (rows_processed > 0) THEN
      UPDATE sb_project_db.raw_data.hybrid_table 
      SET sync_ind = 'P' 
      WHERE sync_ind = 'N';
      rows_affected := SQLROWCOUNT;

      INSERT INTO sb_project_db.raw_data.temp_table
        (POST_ID, POST_TITLE, USER_ID, USER_NAME, USER_CITY) 
      SELECT 
        posts.value:postId::INT,
        posts.value:title::STRING,
        posts.value:user.userId::INT,
        posts.value:user.name::STRING,
        posts.value:user.city::STRING
      FROM sb_project_db.raw_data.hybrid_table a,
      LATERAL FLATTEN(JSON_FILE) posts 
      WHERE a.sync_ind = 'P';
      rows_affected := SQLROWCOUNT;

      SELECT ARRAY_AGG(POST_ID) INTO post_ids 
      FROM sb_project_db.raw_data.temp_table;

      INSERT INTO sb_project_db.raw_data.sb_users
        (USER_ID, USER_NAME, USER_CITY) 
      SELECT DISTINCT USER_ID, USER_NAME, USER_CITY
      FROM sb_project_db.raw_data.temp_table
      WHERE USER_ID NOT IN (
        SELECT USER_ID FROM sb_project_db.raw_data.sb_users
      );
      rows_affected := SQLROWCOUNT;

      MERGE INTO sb_project_db.raw_data.sb_processed_data tgt 
      USING (select distinct * from sb_project_db.raw_data.temp_table) src 
      ON src.post_id = tgt.post_id AND src.USER_ID = tgt.USER_ID
      WHEN MATCHED THEN 
        UPDATE SET 
          tgt.post_title = src.post_title, 
          tgt.process_ts = CURRENT_TIMESTAMP()
      WHEN NOT MATCHED THEN 
        INSERT (POST_ID, POST_TITLE, USER_ID) 
        VALUES (src.POST_ID, src.POST_TITLE, src.USER_ID);
      rows_affected := SQLROWCOUNT;

      result_message := 'Processed ' || :rows_processed || ' rows';
      
      UPDATE sb_project_db.raw_data.hybrid_table 
      SET sync_ind = 'Y' 
      WHERE sync_ind = 'P';
      rows_affected := SQLROWCOUNT;
      
      INSERT INTO sb_project_db.raw_data.proc_logs (
        procedure_name, status, rows_processed, 
        affected_post_ids, duration_seconds
      )
      SELECT
        'sb_proc', 
        'SUCCESS', 
        :rows_processed,
        :post_ids,
        DATEDIFF('SECOND', :proc_start_time, CURRENT_TIMESTAMP());
    END IF;

  EXCEPTION
    WHEN OTHER THEN
      error_msg := 'SQLSTATE: ' || SQLSTATE || ' | Error: ' || SQLERRM;
      result_message := 'Failed: ' || :error_msg;
      
      INSERT INTO sb_project_db.raw_data.proc_logs (
        procedure_name, status, rows_processed, 
        error_message, duration_seconds
      )
      SELECT
        'sb_proc', 
        'FAILED', 
        COALESCE(:rows_processed, 0),
        :error_msg,
        DATEDIFF('SECOND', :proc_start_time, CURRENT_TIMESTAMP());
  END;

  RETURN result_message;
END;
$$;


create or replace task sb_project_db.raw_data.sb_task_1
warehouse = sb_warehouse
schedule = '5 minute'
when system$stream_has_data('sb_project_db.raw_data.sb_stream')
as
call sb_project_db.raw_data.sb_proc();

alter task sb_task_1 resume;

CREATE OR REPLACE SHARE sb_data_share;
GRANT USAGE ON DATABASE sb_project_db TO SHARE sb_data_share;
GRANT USAGE ON SCHEMA sb_project_db.raw_data TO SHARE sb_data_share;
GRANT SELECT ON TABLE sb_project_db.raw_data.sb_processed_data TO SHARE sb_data_share;

ALTER SHARE sb_data_share ADD ACCOUNT = <account>; -- update your account here

CREATE DATABASE IF NOT EXISTS my_shared_database FROM SHARE my_share;

GRANT USAGE ON DATABASE my_shared_database TO ROLE my_role;
