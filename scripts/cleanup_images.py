#!/usr/bin/env python3
import os
import requests
from datetime import datetime, timedelta
import sys

GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
OWNER = os.getenv("OWNER", "nvalembois")
PACKAGE_NAME = os.getenv("PACKAGE_NAME", "homeassistant")
THRESHOLD_DAYS = int(os.getenv("THRESHOLD_DAYS", "30"))

if not GITHUB_TOKEN:
    print("❌ GITHUB_TOKEN not set")
    sys.exit(1)

headers = {
    "Accept": "application/vnd.github.v3+json",
    "Authorization": f"token {GITHUB_TOKEN}",
}

print(f"🔍 Fetching container images for {OWNER}/{PACKAGE_NAME}")
print(f"📅 Threshold: {THRESHOLD_DAYS} days")

# Récupère toutes les versions
url = f"https://api.github.com/user/packages/container/{PACKAGE_NAME}/versions"
response = requests.get(url, headers=headers)

if response.status_code != 200:
    print(f"❌ Error fetching versions: {response.status_code} - {response.text}")
    sys.exit(1)

versions = response.json()

if not versions:
    print("✅ No versions found")
    sys.exit(0)

threshold_date = datetime.utcnow() - timedelta(days=THRESHOLD_DAYS)
deleted_count = 0
kept_count = 0

print(f"\n{'='*60}")

for version in versions:
    try:
        created_at = datetime.fromisoformat(version["created_at"].replace("Z", "+00:00"))
        version_id = version["id"]
        tag = version.get("name", "unknown")
        
        if created_at < threshold_date:
            age_days = (datetime.utcnow() - created_at.replace(tzinfo=None)).days
            print(f"🗑️  Deleting: {tag} (created {age_days} days ago)")
            
            delete_url = f"https://api.github.com/user/packages/container/{PACKAGE_NAME}/versions/{version_id}"
            delete_response = requests.delete(delete_url, headers=headers)
            
            if delete_response.status_code in [200, 204]:
                print(f"   ✅ Successfully deleted")
                deleted_count += 1
            else:
                print(f"   ❌ Error: {delete_response.status_code} - {delete_response.text}")
        else:
            age_days = (datetime.utcnow() - created_at.replace(tzinfo=None)).days
            print(f"✅ Keeping: {tag} (created {age_days} days ago)")
            kept_count += 1
    except Exception as e:
        print(f"❌ Error processing version: {e}")

print(f"\n{'='*60}")
print(f"📊 Summary: {deleted_count} deleted, {kept_count} kept")
print(f"{'='*60}")
