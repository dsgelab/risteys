# output:
# [
#     {
#         x: 1/2/0/12.5,
#         ...
#     },
#     ...
# ]

import json
from random import choice

res = []

values = {
    # individual characteristics
    "sex": lambda: choice([1, 2]),
    "age": lambda: choice(range(20, 80)),
    "bmi": lambda: choice(range(15, 50)),
    "height": lambda: choice(range(130, 220)),
    "weight": lambda: choice(range(40, 150)),
    "smoking": lambda: choice([True, False]),
    "sbp": lambda: choice(range(10)),

    # medical conditions
    "death": lambda: choice([True, False]),
    "asthma": lambda: choice([True, False]),
    "cancer": lambda: choice([True, False]),
    "cdv": lambda: choice([True, False]),
    "chron": lambda: choice([True, False]),
    "depression": lambda: choice([True, False]),
    "diabetes": lambda: choice([True, False]),
    "epilepsy": lambda: choice([True, False]),
}

# with open("assets/data/myphenos.json") as f:
#     phenos = json.load(f)
# phenos = phenos.keys()

for _ in range(100):
    indiv = {}
    
    for v, fun in values.items():
        indiv[v] = fun()

    # for pheno in phenos:
    #     indiv[pheno] = choice([True, False])

    res.append(indiv)

with open("assets/data/fake_indiv.json", "w") as f:
    json.dump(res, f)
