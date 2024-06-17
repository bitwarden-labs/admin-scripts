import json
import os
import re
import subprocess
from utils.decrypt_env import decrypt_secrets

bw = '/Users/adambramley/.nvm/versions/node/v19.9.0/bin/bw'

decrypt_secrets()

def get_session_key():
  owner_username = os.environ['owner_username']
  owner_masterpassword = os.environ['owner_masterpassword']

  # print(f"username is: {owner_username}")
  # print(os.environ['owner_masterpassword'])

  logout = subprocess.run([bw, 'logout'])

  login_command = [bw, 'login', owner_username, os.environ['owner_masterpassword']]
  print(f"login command is {login_command}")

  login = subprocess.run(login_command, capture_output=True, text=True)
  session_key = re.search(r'(?=\").*(\")', login.stdout)
  print(session_key)
  os.environ['BW_SESSION'] = session_key
  return session_key

# print(str(match.group(0)))
# print("STDOUT:", login.stdout)
# print("STDERR:", login.stderr)

# unlock_command = [bw, 'unlock', os.environ['owner_masterpassword']]
# unlock = subprocess.run(unlock_command, capture_output=True, text=True)
# session_key = json.loads(unlock.stdout)

# print(session_key)
