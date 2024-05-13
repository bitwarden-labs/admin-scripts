# Installation Guide

Welcome to Bitwarden Password Validy Report! This README provides step-by-step instructions for setting up your development environment, including the installation of Python 3 and the Cryptography package. Please follow the instructions for your operating system.

## Prerequisites

- Access to a command-line interface (CLI)
- Internet connection

## Installing Python 3

### Windows

1. Download the latest Python 3 installer from the [official Python website](https://www.python.org/downloads/windows/).
2. Run the installer. Ensure you check the box that says "Add Python 3.x to PATH" at the bottom of the installer window.
3. Click on "Install Now".
4. After installation, open a command prompt and type `python --version` to verify the installation. You should see the Python version number.

### Linux

#### Ubuntu/Debian-based distributions

1. Open your terminal.
2. Update the package list with `sudo apt-get update`.
3. Install Python 3 with `sudo apt-get install python3`.
4. Verify the installation with `python3 --version`.

#### Fedora and similar

1. Open your terminal.
2. Update your package list with `sudo dnf upgrade`.
3. Install Python 3 with `sudo dnf install python3`.
4. Verify the installation with `python3 --version`.

## Installing Cryptography Package

Once Python 3 is installed, you can install the Cryptography package using pip (Python's package installer).

1. Open your command line interface (CLI).
2. Run the following command to install the Cryptography package:

python -m pip install cryptography

- On Windows, you might need to use `python` or `python3`, depending on your system configuration.
- On Linux, you might need to use `python3` and `pip3` instead of `python` and `pip`.

3. Verify the installation by running `python -m pip show cryptography`. You should see details of the installed package.

## Next Steps: Setting up the script configurations

After setting up Python 3 and the Cryptography package, you're ready to setup up the environment. 

Before running the setup, please provide the following detais:

- Organization ID: To obtain the Org ID in GUID format, open the Bitwarden Web App, click the "Organizations" menu, then get the Organization GUID from the URL.

Example URL:
https://vault.bitwarden.com/#/organizations/ee85f86f-bb15-4787-ac64-b03d123dba6e/vault

Org GUID from the URL above is ee85f86f-bb15-4787-ac64-b03d123dba6e

- To log in using CLI, a Bitwarden account is required. Prepare the master password of this account and the API Key (Client ID & Client Secret)

https://bitwarden.com/help/personal-api-key/

- SMTP Server Details: Server/Hostname, Port, Username & Password (if auth is required)
- Email Subject, Sender, and Recipients

After you have all the details above, run the following command to setup the config files:

python3 PasswordExpiryReport.py -c setup

If you choose random passphrase, please take note of the random string given by the script.

## Setting Up `BW_PASSPHRASE` Environment Variable

### Windows

Follow these steps to set up the `BW_PASSPHRASE` environment variable on Windows:

1. Press the Windows key and search for `Environment Variables`, then select **Edit the system environment variables**.
2. In the System Properties window, click the **Environment Variables...** button.
3. Under the **User variables** section, click **New...** to create a new environment variable.
4. For **Variable name**, enter `BW_PASSPHRASE`.
5. For **Variable value**, enter your secure passphrase.
6. Click **OK** to save the variable, and again click **OK** on the remaining open windows to apply the changes.
7. To verify the variable is set, open a Command Prompt window and type `echo %BW_PASSPHRASE%`. You should see your passphrase displayed.

### Linux

To set up the `BW_PASSPHRASE` environment variable on Linux, follow these instructions:

1. Open your terminal.
2. Edit your profile's startup script. Depending on your shell, this might be `~/.bashrc`, `~/.bash_profile`, `~/.zshrc`, etc. For a bash shell, you can use `nano ~/.bashrc` or your preferred text editor.
3. Add the following line at the end of the file:

export BW_PASSPHRASE='your-secure-passphrase'

Replace `your-secure-passphrase` with your actual passphrase.
4. Save and close the file.
5. To apply the changes, run `source ~/.bashrc` (or replace `.bashrc` with your specific profile file).
6. Verify the environment variable is set by running `echo $BW_PASSPHRASE` in the terminal. You should see your passphrase displayed.

## Next Steps: Running the report

Run the following command to run the report. Try running it manually on the CLI (Powershell/Shell) before setting up a cronjob/scheduled task

python3 PermissionsReport.py -c runreport

## Troubleshooting

Please contact Bitwarden Support if you encounter any issues with setting up the script.