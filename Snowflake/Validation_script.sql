list @sb_project_db.raw_data.sb_named_stage; -- list of staged files

select * from sb_project_db.raw_data.sb_stream; -- check stream status

SELECT SYSTEM$PIPE_STATUS('sb_project_db.raw_data.sb_pipe'); -- check pipe status

SELECT *
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
  SCHEDULED_TIME_RANGE_START => DATEADD('HOUR', -1, CURRENT_TIMESTAMP()),
  TASK_NAME => 'sb_task_1'
)); -- check task details

-- validate tables
select * from sb_project_db.raw_data.hybrid_table;
select * from sb_project_db.raw_data.temp_table;
select * from sb_project_db.raw_data.sb_processed_data;
select * from sb_project_db.raw_data.proc_logs;
