import requests

url = "http://localhost:8088/sm/qc/monitoring"
params = {
    "userId": "admin",
    "divisionId": "2",
    "division": "MECHANIC",
    "limit": 100
}
try:
    resp = requests.get(url, params=params)
    print("Status:", resp.status_code)
    import json
    data = resp.json()
    print(json.dumps(data, indent=2)[:1000])
except Exception as e:
    print(e)
