<template>
	<div role="table" class="drug-scrolling">
		<div role="rowgroup">
			<div role="row" class="grid-drug-header">
				<div role="columnheader">
					<p>Name</p>
					<p class="end-align">
						<input
							type="text"
							class="filter-input"
							placeholder="filter by drug name or ATC"
							v-model="drug_filter"
							v-on:keyup.stop="refresh_table()"
						>
					</p>
				</div>
				<div role="columnheader">
					<p>
						<p><a class="help-button" href="#dialog-drug-help" onclick="openDialog('drug-help')">?</a></p>
						Score
					</p>

					<p class="end-align">
						<input type="radio" id="score_asc" value="score_asc" v-model="sorter" v-on:change="refresh_table()" checked><label for="score_asc" class="radio-left">▲</label><input type="radio" id="score_desc" value="score_desc" v-model="sorter" v-on:change="refresh_table()"><label for="score_desc" class="radio-right">▼</label>
					</p>
				</div>
				<div role="columnheader">
					<p>[95% CI]</p>
				</div>
				<div role="columnheader">
					<p>p </p>
					<p class="end-align">
						<input type="radio" id="pvalue_asc" value="pvalue_asc" v-model="sorter" v-on:change="refresh_table()"><label for="pvalue_asc" class="radio-left">▲</label><input type="radio" id="pvalue_desc" value="pvalue_desc" v-model="sorter" v-on:change="refresh_table()"><label for="pvalue_desc" class="radio-right">▼</label>
					</p>
				</div>
				<div role="columnheader">
					<p>N <p>
					<p class="end-align">
						<input type="radio" id="nindivs_asc" value="nindivs_asc" v-model="sorter" v-on:change="refresh_table()"><label for="nindivs_asc" class="radio-left">▲</label><input type="radio" id="nindivs_desc" value="nindivs_desc" v-model="sorter" v-on:change="refresh_table()"><label for="nindivs_desc" class="radio-right">▼</label>
					</p>
				</div>
				<div role="columnheader">
					<p>ATC code </p>
					<p class="end-align">
						<input type="radio" id="atc_asc" value="atc_asc" v-model="sorter" v-on:change="refresh_table()"><label for="atc_asc" class="radio-left">▲</label><input type="radio" id="atc_desc" value="atc_desc" v-model="sorter" v-on:change="refresh_table()"><label for="atc_desc" class="radio-right">▼</label>
					</p>
				</div>
			</div>
		</div>
		<div role="rowgroup">
			<template v-for="(drug, idx) in drug_table">
				<div role="row" v-bind:class="bg_class(idx) + ' grid-drug-body'">
					<div role="cell" v-bind:class="bg_class(idx)">{{ drug.name }}</div>
					<div role="cell">{{ drug.score_str }}</div>
					<div role="cell">[{{ drug.ci_min_str }}, {{ drug.ci_max_str }}]</div>
					<div role="cell">{{ drug.pvalue_str }}</div>
					<div role="cell">{{ drug.n_indivs }}</div>
					<div role="cell"><a v-bind:href="drug.atc_link" target="_blank" rel="noopener noreferrer external">{{ drug.atc }}</a></div>
				</div>
			</template>
		</div>

		<template v-if="drug_table.length == 0">
			<p>No data.</p>
		</template>

		<!-- this need to be the last child of the parent <div> element to make the help box always appear -->
        <div id="drug-help" class="dialog-backdrop hidden" tabindex="0">
            <div role="dialog"
                aria-labelledby="drug-help-label"
                aria-modal="true"
            >
            	<div class="dialog-header">
	                <h2 id="drug-help-label" class="dialog-label">Drug Score </h2>
	            	<button class="button-faded" onclick="closeDialog('drug-help')">Close</button>
            	</div>

                <article>
					<p>
						Probability of getting the drug after <i>{{ phenocode }}</i> conditional on not having this drug before <i>{{ phenocode }}</i>.
					</p>
					<p>
						See <i>Drug Statistics</i> on the <a href="/documentation#drug-stats">Documentation page</a> for more information.
					</p>
                </article>
            </div>
         </div>
	</div>
</template>

<script>
import { filter, reverse, sortBy } from 'lodash-es';


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
	}
}
</script>


<style scoped>
.drug-scrolling {
	max-width: 100%;
	max-height: 500px;
	overflow: scroll;
	position: relative;

	/* If not set, scrolled text will appear above the table header.
    We could have used padding-top: 0; only, but it actually looks better
	with no padding at all.*/
	padding: 0;
}

 /* Reset default display: table; from browsers */
[role="table"] {
	display: block;
}

[role="rowgroup"]:nth-child(1) {
	position: sticky;
	top: 0;
	background-color: #fafafa;
	border-top-width: 1px;
	border-bottom-width: 1px;

	font-weight: bold;
}

/* Grid table layout */
.grid-drug-header {
	display: grid;
	grid-template-columns: 9fr 2fr 2fr 2fr 2fr 2fr;  /* first column spans 2 body columns */
}
.grid-drug-body {
	display: grid;
	grid-template-columns: 9fr 2fr 2fr 2fr 2fr 2fr;
}

/* Place table header widget near the bottom */
[role="columnheader"] {
	display: grid;
	grid-template-columns: 1fr;
}
.end-align {
	align-self: end;
	margin-top: 0.25rem;
}

/* Hide overflowing endpoint code name */
[role="cell"]:nth-child(1) {
	overflow: hidden;
}

.filter-input {
	width: 40%;
}
</style>
