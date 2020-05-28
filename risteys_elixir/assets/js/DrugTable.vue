<template>
	<div>
		<div class="drugs-grid thead">
			<div>Name <br>
				<input
					type="text"
					placeholder="filter by drug name or ATC"
					v-model="drug_filter"
					v-on:keyup="refresh_table()"
					>
			</div>
			<div>
				<div style="position: relative; left: -34px"><HelpDrugScore v-bind:phenocode="this.phenocode" /> Score</div>
				<input type="radio" id="score_desc" value="score_desc" v-model="sorter" v-on:change="refresh_table()" checked><label for="score_desc" class="radio-left">▼</label><input type="radio" id="score_asc" value="score_asc" v-model="sorter" v-on:change="refresh_table()"><label for="score_asc" class="radio-right">▲</label>
			</div>
			<div>[95% CI] <br>
			</div>
			<div>p <br>
			<input type="radio" id="pvalue_desc" value="pvalue_desc" v-model="sorter" v-on:change="refresh_table()"><label for="pvalue_desc" class="radio-left">▼</label><input type="radio" id="pvalue_asc" value="pvalue_asc" v-model="sorter" v-on:change="refresh_table()"><label for="pvalue_asc" class="radio-right">▲</label></div>
			<div>N <br>
			<input type="radio" id="nindivs_desc" value="nindivs_desc" v-model="sorter" v-on:change="refresh_table()"><label for="nindivs_desc" class="radio-left">▼</label><input type="radio" id="nindivs_asc" value="nindivs_asc" v-model="sorter" v-on:change="refresh_table()"><label for="nindivs_asc" class="radio-right">▲</label></div>
			<div>ATC code <br>
			<input type="radio" id="atc_desc" value="atc_desc" v-model="sorter" v-on:change="refresh_table()"><label for="atc_desc" class="radio-left">▼</label><input type="radio" id="atc_asc" value="atc_asc" v-model="sorter" v-on:change="refresh_table()"><label for="atc_asc" class="radio-right">▲</label></div>
		</div>

		<div v-if="drug_table.length > 0"
			class="drugs-grid drugs-data">
			<template v-for="(drug, idx) in drug_table">
				<div v-bind:class="bg_class(idx)">{{ drug.name }}</div>
				<div v-bind:class="bg_class(idx)">{{ drug.score_str }}</div>
				<div v-bind:class="bg_class(idx)">[{{ drug.ci_min_str }}, {{ drug.ci_max_str }}]</div>
				<div v-bind:class="bg_class(idx)">{{ drug.pvalue_str }}</div>
				<div v-bind:class="bg_class(idx)">{{ drug.n_indivs }}</div>
				<div v-bind:class="bg_class(idx)">
					<a v-bind:href="drug.atc_link" target="_blank" rel="noopener noreferrer external">{{ drug.atc }}</a>
				</div>
			</template>
		</div>
		<div v-else
			class="drugs-grid drugs-data">
			<p>No data.</p>
		</div>
	</div>
</template>

<script>
import { filter, reverse, sortBy } from 'lodash-es';
import HelpDrugScore from './HelpDrugScore.vue';


let compute_table = (data, drug_filter, sorter) => {
	var res = data;

	// Filter rows
	if (drug_filter !== "") {
		console.log("filtering:", drug_filter);
		res = filter(
			data,
			(drug) => {
				return drug.name.toLowerCase().includes(drug_filter.toLowerCase())
				|| drug.atc.toLowerCase().includes(drug_filter.toLowerCase())
			}
		);
	}

	// Sort rows
	switch (sorter) {
		case "score_desc":
			res = sortBy(res, (drug) => drug.score_num);
			res = reverse(res);
			break;
		case "score_asc":
			res = sortBy(res, (drug) => drug.score_num);
			break;
		case "pvalue_desc":
			res = sortBy(res, (drug) => drug.pvalue_num);
			res = reverse(res);
			break;
		case "pvalue_asc":
			res = sortBy(res, (drug) => drug.pvalue_num);
			break;
		case "nindivs_desc":
			res = sortBy(res, (drug) => drug.n_indivs);
			res = reverse(res);
			break;
		case "nindivs_asc":
			res = sortBy(res, (drug) => drug.n_indivs);
			break;
		case "atc_desc":
			res = sortBy(res, (drug) => drug.atc);
			res = reverse(res);
			break;
		case "atc_asc":
			res = sortBy(res, (drug) => drug.atc);
			break;
		default:
			console.log("Unrecognized sorter:", sorter);
	}

	return res
};

export default {
	data () {
		return {
			sorter: "score_desc",
			drug_filter: "",
			drug_table: []
		}
	},
	props: {
		drug_data: Array,
		phenocode: String
	},
	methods: {
		bg_class(idx) {
			if (idx % 2 === 1) {
				return "bg-grey-lightest"
			}
		},
		refresh_table() {
			this.drug_table = compute_table(this.drug_data, this.drug_filter, this.sorter);
		}
	},
	created() {
		// Keep the original values in drug_data.
		// The current view is kept in drug_table.
		// We do this because using only drug_table would lead to information loss when filtering out by drugs.
		this.drug_table = this.drug_data;
	},
	components: {
		HelpDrugScore
	}
}
</script>


<style>
.drugs-grid {
    display: grid;
    grid-template-columns:
        590px
        116px
        130px
        104px
        87px
        113px;
}

.drugs-grid.thead {
    @apply font-bold;
    @apply bg-grey-lightest;
    @apply border-t;
    @apply border-b;
    margin-bottom: 1px;
}

.drugs-data {
    max-height: 500px;
    overflow: auto;
}
.drugs-data > div, .drugs-grid.thead > div {
    @apply py-1;
}
</style>
