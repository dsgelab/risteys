import json

res = {}

with open('assets/data/phenos.json') as f:
    content = json.load(f)

for pheno in content:
    res[pheno['phenocode']] = {
        'category': pheno['category'],
        'description': pheno['phenostring'],
        'num_cases': pheno['num_cases'],
        'num_controls': pheno['num_controls'],
        'icd_incl': pheno.get('icd_incl'),
        'icd_excl': pheno.get('icd_excl'),
    }

with open('assets/data/myphenos.json', 'w') as f:
    json.dump(res, f)
