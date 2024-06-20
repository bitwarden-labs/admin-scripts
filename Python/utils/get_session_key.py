import os
import re
import subprocess
from utils.decrypt_env import decrypt_secrets

bw = '/Users/adambramley/.nvm/versions/node/v19.9.0/bin/bw'

def get_session_key():
  decrypt_secrets()
  owner_username = os.environ['owner_username']
  owner_masterpassword = os.environ['owner_masterpassword']

  logout = subprocess.run([bw, 'logout'])

  login_command = [bw, 'login', owner_username, owner_masterpassword]

  login = subprocess.run(login_command, capture_output=True, text=True)
  session_key = re.search(r'"[^"]+"', login.stdout).group(0)
  return session_key
