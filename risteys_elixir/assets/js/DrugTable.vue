<template>
	<div class="scrolling">
		<table class="w-full">
			<thead>
				<tr>
					<th>
						<div class="h-full border-b border-t pl-2 pt-4">  <!-- div hack to have the borders stay in place on scroll -->
							Name <br>
							<input
								type="text"
								placeholder="filter by drug name or ATC"
								v-model="drug_filter"
								v-on:keyup.stop="refresh_table()"
								>
						</div>
					</th>
					<th>
						<div class="h-full border-t border-b">
							<div><HelpDrugScore v-bind:phenocode="this.phenocode" /> Score</div>
					<input type="radio" id="score_asc" value="score_asc" v-model="sorter" v-on:change="refresh_table()" checked><label for="score_asc" class="radio-left">▲</label><input type="radio" id="score_desc" value="score_desc" v-model="sorter" v-on:change="refresh_table()"><label for="score_desc" class="radio-right">▼</label>
						</div>
					</th>
					<th>
						<div class="h-full border-t border-b">
							[95% CI]
						</div>
					</th>
					<th>
						<div class="h-full border-t border-b">
							p <br>
				<input type="radio" id="pvalue_asc" value="pvalue_asc" v-model="sorter" v-on:change="refresh_table()"><label for="pvalue_asc" class="radio-left">▲</label><input type="radio" id="pvalue_desc" value="pvalue_desc" v-model="sorter" v-on:change="refresh_table()"><label for="pvalue_desc" class="radio-right">▼</label>
						</div>
					</th>
					<th>
						<div class="h-full border-t border-b">
							N <br>
				<input type="radio" id="nindivs_asc" value="nindivs_asc" v-model="sorter" v-on:change="refresh_table()"><label for="nindivs_asc" class="radio-left">▲</label><input type="radio" id="nindivs_desc" value="nindivs_desc" v-model="sorter" v-on:change="refresh_table()"><label for="nindivs_desc" class="radio-right">▼</label>
						</div>
					</th>
					<th>
						<div class="h-full border-t border-b">
							ATC code <br>
				<input type="radio" id="atc_asc" value="atc_asc" v-model="sorter" v-on:change="refresh_table()"><label for="atc_asc" class="radio-left">▲</label><input type="radio" id="atc_desc" value="atc_desc" v-model="sorter" v-on:change="refresh_table()"><label for="atc_desc" class="radio-right">▼</label>
						</div>
					</th>
				</tr>
			</thead>
			<tbody>
				<template v-for="(drug, idx) in drug_table">
					<tr v-bind:class="bg_class(idx)">
						<th v-bind:class="bg_class(idx)">{{ drug.name }}</th>
						<td>{{ drug.score_str }}</td>
						<td>[{{ drug.ci_min_str }}, {{ drug.ci_max_str }}]</td>
						<td>{{ drug.pvalue_str }}</td>
						<td>{{ drug.n_indivs }}</td>
						<td><a v-bind:href="drug.atc_link" target="_blank" rel="noopener noreferrer external">{{ drug.atc }}</a></td>
					</tr>
				</template>
			</tbody>
		</table>
		<template v-if="drug_table.length == 0">
			<p>No data.</p>
		</template>
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
			} else {
				return "bg-white"
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


<style scoped>
div.scrolling {
	max-width: 100%;
	max-height: 500px;
	overflow: scroll;
	position: relative;

	font-size: 0.8rem;
}

.scrolling table {
	position: relative;
	border-collapse: collapse;
}

.scrolling th, .scrolling td {
	@apply px-1;
}

/* Allow div hack that shows borders on scroll */
.scrolling thead th, .scrolling thead td {
	padding: 0;
}

/* thead gray background */
.scrolling thead th {
	@apply bg-grey-lightest;
}

/* thead: drug cell */
.scrolling thead tr:first-child th:first-child {
	left: 0;
	z-index: 1;
	height: 80px;
}

/* thead: row */
.scrolling thead tr th {
	position: sticky;

	top: 0;
	line-height: 1.5;
	height: 80px;
}

/* tbody: leftmost column */
.scrolling tbody th {
  position: -webkit-sticky; /* for Safari */
  position: sticky;
  left: 0;
  font-weight: normal;
}

@media (min-width: 650px) {
	div.scrolling {
		font-size: 1rem;
	}

	.scrolling th, .scrolling td {
		@apply px-3;
	}
}
</style>
