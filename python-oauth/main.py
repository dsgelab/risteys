"""
Script to check if a given account is part of the finngen risteys group.

Usage:
    python main.py <group-email> <user-email>

Note:
    Not working, never worked. Due an authorization error, even when domain-wide delegation was setup.
"""
from sys import argv

from google.oauth2 import service_account
from googleapiclient.discovery import build

SCOPES = [
	'https://www.googleapis.com/auth/admin.directory.group.member.readonly',
	'https://www.googleapis.com/auth/admin.directory.group.readonly',
]

SERVICE_ACCOUNT_FILE = '/home/local/vllorens/Downloads/finngen-risteys-ffa10a34d509.json'

credentials = service_account.Credentials.from_service_account_file(SERVICE_ACCOUNT_FILE, scopes=SCOPES)

service = build('admin', 'directory_v1', credentials=credentials)
results = service.members().hasMember(groupKey=argv[1], memberKey=argv[2]).execute()
