from dotenv import load_dotenv
import ast
import datetime
import os
import subprocess

load_dotenv()
bw = os.getenv("bw")
outputDir = os.getenv("output_directory")
organizations = ast.literal_eval(os.getenv("organizations"))

# set variables
os.environ["BW_CLIENTID"] = os.getenv("client_id")
os.environ["BW_CLIENTSECRET"] = os.getenv("client_secret")
masterPassword = os.getenv("masterPassword")

# login
login = subprocess.run([bw, "login", "--apikey"], stdout=subprocess.PIPE, text=True)

# set session key
sessionKey = subprocess.run(
    [bw, "unlock", masterPassword, "--raw"], stdout=subprocess.PIPE
).stdout.decode("utf-8")
os.environ["BW_SESSION"] = sessionKey

# export vault
for org in organizations:
    filename = f"{outputDir}/{org}-{datetime.datetime.now().strftime('%Y-%m-%d-%H:%M')}.json"
    subprocess.run([bw, "export", masterPassword, "--output", filename, "--organizationid", org, "--format", "encrypted_json"])

# log out
subprocess.run([bw, "logout"])