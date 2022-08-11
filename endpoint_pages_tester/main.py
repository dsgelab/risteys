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
n_success = 0
n_failure = 0
for idx, endpoint in enumerate(endpoints):
    clear_line = "\x1b[K\r"
    print(f"{idx + 1}/{len(endpoints)} ({n_success} OK, {n_failure} fail) {endpoint}", end=clear_line)

    conn.request("GET", f"/endpoints/{endpoint}")
    resp = conn.getresponse()

    if resp.status != 200:
        print(resp.status, endpoint, f"http://localhost:4000/endpoints/{endpoint}")
        n_failure += 1
    else:
        n_success += 1

    resp.read()  # mandatory before sending next request to avoid ResponseNotReady
