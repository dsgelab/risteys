import http.client
import json


# 1. Get list of all endpoints
conn = http.client.HTTPConnection("localhost:4000")

conn.request("GET", "/api/endpoints/")

resp = conn.getresponse()
assert resp.status == 200
data = resp.read()

endpoints = json.loads(data)


# 2. Query all endpoint pages to check their status
for idx, endpoint in enumerate(endpoints):
    print(f"{idx + 1}/{len(endpoints)}", end="\r")

    conn.request("GET", f"/endpoints/{endpoint}")
    resp = conn.getresponse()

    if resp.status != 200:
        print(resp.status, endpoint, f"http://localhost:4000/endpoints/{endpoint}")

    resp.read()  # mandatory before sending next request to avoid ResponseNotReady
