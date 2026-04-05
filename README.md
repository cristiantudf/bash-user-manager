# bash-user-manager

A command-line user management system written in Bash. It provides a simple interactive menu for registering users, authenticating them, and generating reports — all stored locally using a CSV file.

## Features

User Registration — Creates a new account with a username, email, and password. Passwords are hashed using SHA-256 before being stored. A confirmation email is sent upon successful registration.
Login / Logout — Authenticates users by verifying their hashed password. Tracks currently logged-in users in a hidden file (.logged_users) and updates the last login timestamp in the CSV.
Home Directories — Each user gets a personal home directory automatically created under home/<username>/ upon registration or first login.
Active Users List — Displays all currently logged-in users.
Report Generation — Generates a usage report for a given user (number of files, directories, and total disk size) and saves it as raport.txt in their home directory. The report runs in the background.

## How It Works
All user data is persisted in a local utilizatori.csv file with the following structure:
ID, Username, Email, PasswordHash, LastLogin
User IDs are generated from a SHA-256 hash of the current timestamp. Passwords are never stored in plain text — only their SHA-256 hash is saved.

## Requirements

Bash 4+
mail command (for confirmation emails)
Standard Unix utilities: sha256sum, sed, grep, find, du

## Usage
chmod +x script.sh
./script.sh

Then follow the interactive menu.
