import snowflake.connector
import configparser
import os

class sf_file_upload:
    def __init__(self):
        self.config_file = 'config.ini'
        self.dir_path = os.path.abspath(os.path.dirname(__file__))
        self.config_path = os.path.abspath(os.path.join(self.dir_path, '..', 'config', self.config_file))
        
        # Read config
        self.config = configparser.ConfigParser()
        self.config.read(self.config_path)

        #self.file_dir = os.path.abspath(os.path.join(self.dir_path, '..', 'csv'))

    def file_upload(self, file):
        conn = snowflake.connector.connect(
            user=self.config.get('SNOWFLAKE_CONN', 'user'),
            password=self.config.get('SNOWFLAKE_CONN', 'pass'),
            account=self.config.get('SNOWFLAKE_CONN', 'account')
        )
        cur = conn.cursor()
        #file=os.path.join(self.file_dir,file)

        # Upload a file to Named Stage
        cur.execute(f"PUT file://{file} @sb_project_db.raw_data.sb_named_stage")

        print("File successfully uploaded to Snowflake Named Stage.")
        cur.close()
        conn.close()

if __name__=='__main__':
    uploader = sf_file_upload()
    print('main run')
    #uploader.file_upload("C:/path_to_file/data.csv")
