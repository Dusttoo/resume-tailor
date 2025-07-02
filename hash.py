import hashlib
import json

resp = json.load(open("response.json"))
key = resp["key"].encode("utf-8")
traits = resp["traits"]

hashes = [
    hashlib.blake2b(trait.encode(), key=key, digest_size=64).hexdigest()
    for trait in traits
]

print(json.dumps(hashes, indent=2))
