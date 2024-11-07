from dotenv import load_dotenv
import os
import subprocess
from variables import bw_path

load_dotenv()

master_password = os.getenv("master_password")

session_key = subprocess.run(
  bw_path + ["unlock", master_password, "--raw"],
  stdout=subprocess.PIPE,
  text=True
).stdout.strip()
