<template>
	<div role="table" class="assoc-scrolling">
		<div role="rowgroup">
			<div role="row" class="grid-assoc-header-top">
				<div role="columnheader">
					<p>Endpoint</p>
				</div>

				<div role="columnheader" aria-colspan="4">
					<p>Before {{ phenocode }}</p>
				</div>

				<div role="columnheader" aria-colspan="4">
					<p>After {{ phenocode }}</p>
				</div>
			</div>

			<div role="row" class="grid-assoc-header-bottom">
				<div role="columnheader">
					<p>
						<input
								type="text"
								placeholder="filter by name"
								v-on:keyup.stop="refresh_table()"
								v-model="pheno_filter"
								class="mt-2">
						</p>
				</div>

				<div role="columnheader">
					<p>HR [95%&nbsp;CI]</p>
					<p>
						<input type="radio" id="hr_before_asc" value="hr_before_asc" v-model="sorter" v-on:change="refresh_table()" checked><label for="hr_before_asc" class="radio-left">▲</label><input type="radio" id="hr_before_desc" value="hr_before_desc" v-model="sorter" v-on:change="refresh_table()"><label for="hr_before_desc" class="radio-right">▼</label>
					</p>
				</div>

				<div role="columnheader">
					<p>p</p>
					<p>
						<input type="radio" id="pvalue_before_asc" value="pvalue_before_asc" v-model="sorter" v-on:change="refresh_table()"><label for="pvalue_before_asc" class="radio-left">▲</label><input type="radio" id="pvalue_before_desc" value="pvalue_before_desc" v-model="sorter" v-on:change="refresh_table()"><label for="pvalue_before_desc" class="radio-right">▼</label>
					</p>
				</div>

				<div role="columnheader">
					<p><abbr data-title="Number of overlapping individuals">N</abbr></p>
					<p>
						<input type="radio" id="nindivs_before_asc" value="nindivs_before_asc" v-model="sorter" v-on:change="refresh_table()"><label for="nindivs_before_asc" class="radio-left">▲</label><input type="radio" id="nindivs_before_desc" value="nindivs_before_desc" v-model="sorter" v-on:change="refresh_table()"><label for="nindivs_before_desc" class="radio-right">▼</label>
					</p>
				</div>

				<div role="columnheader">
					<p><a class="help-button" href="#dialog-surv-help" onclick="openDialog('surv-help')">?</a></p>

					<p>
						<input type="radio" id="compbox_before_asc" value="compbox_before_asc" v-model="sorter" v-on:change="refresh_table()" checked><label for="compbox_before_asc" class="radio-left">▲</label><input type="radio" id="compbox_before_desc" value="compbox_before_desc" v-model="sorter" v-on:change="refresh_table()"><label for="compbox_before_desc" class="radio-right">▼</label>
					</p>
				</div>

				<div role="columnheader">
					<p>HR [95%&nbsp;CI]</p>
					<p>
						<input type="radio" id="hr_after_asc" value="hr_after_asc" v-model="sorter" v-on:change="refresh_table()"><label for="hr_after_asc" class="radio-left">▲</label><input type="radio" id="hr_after_desc" value="hr_after_desc" v-model="sorter" v-on:change="refresh_table()"><label for="hr_after_desc" class="radio-right">▼</label>
					</p>
				</div>

				<div role="columnheader">
					<p>p</p>
					<p>
						<input type="radio" id="pvalue_after_asc" value="pvalue_after_asc" v-model="sorter" v-on:change="refresh_table()"><label for="pvalue_after_asc" class="radio-left">▲</label><input type="radio" id="pvalue_after_desc" value="pvalue_after_desc" v-model="sorter" v-on:change="refresh_table()"><label for="pvalue_after_desc" class="radio-right">▼</label>
					</p>
				</div>

				<div role="columnheader">
					<p><abbr data-title="Number of overlapping individuals">N</abbr></p>
					<p>
						<input type="radio" id="nindivs_after_asc" value="nindivs_after_asc" v-model="sorter" v-on:change="refresh_table()"><label for="nindivs_after_asc" class="radio-left">▲</label><input type="radio" id="nindivs_after_desc" value="nindivs_after_desc" v-model="sorter" v-on:change="refresh_table()"><label for="nindivs_after_desc" class="radio-right">▼</label>
					</p>
				</div>

				<div role="columnheader">
					<p><a class="help-button" href="#dialog-surv-help" onclick="openDialog('surv-help')">?</a></p>
					<p>
						<input type="radio" id="compbox_after_asc" value="compbox_after_asc" v-model="sorter" v-on:change="refresh_table()" checked><label for="compbox_after_asc" class="radio-left">▲</label><input type="radio" id="compbox_after_desc" value="compbox_after_desc" v-model="sorter" v-on:change="refresh_table()"><label for="compbox_after_desc" class="radio-right">▼</label>
					</p>
				</div>

			</div>
		</div>

		<div v-for="(pheno, idx) in assoc_table" role="rowgroup">
			<!-- LAG: no lag -->
			<div
				role="row"
				v-bind:class="bg_even(idx) + ' grid-assoc-body'"
			>
				<!-- ENDPOINT NAME -->
				<div role="cell">
					<img src="/images/explag.svg" v-on:click="toggle_fold(pheno.name)" alt="expand data" class="cursor-pointer mini-button">
					<a :href="'/phenocode/' + pheno.name" :title="pheno.name">{{ pheno.longname }}</a>
				</div>

				<!-- (before) HR -->
				<div role="cell" v-if="pheno.all.before.hr === null">-</div>
				<div role="cell" v-else-if="pheno.all.before.hr >100">&gt;&nbsp;100</div>
				<div role="cell" v-else>{{ pheno.all.before.hr_str }} [{{ pheno.all.before.ci_min }},&nbsp;{{ pheno.all.before.ci_max }}]</div>

				<!-- (before) P-VALUE -->
				<div role="cell" v-if="pheno.all.before.pvalue === null">-</div>
				<div role="cell" v-else>{{ pheno.all.before.pvalue_str }}</div>

				<!-- (before) N-INDIVS -->
				<div role="cell" v-if="pheno.all.before.nindivs === null">-</div>
				<div role="cell" v-else>{{ pheno.all.before.nindivs }}</div>

				<!-- (before) COMPBOX -->
				<div role="cell" v-if="pheno.all.before.hr_binned === null">-</div>
 				<div role="cell" v-else
 					v-html="compBox(pheno.all.before.hr_binned)"
 					v-bind:title="textPercentile(Math.trunc(pheno.all.before.hr_binned * 100)) + ' percentile'">
				</div>

				<!-- (after) HR -->
				<div role="cell" v-if="pheno.all.after.hr === null">-</div>
				<div role="cell" v-else-if="pheno.all.after.hr > 100">&gt;&nbsp;100</div>
				<div role="cell" v-else>{{ pheno.all.after.hr_str }} [{{ pheno.all.after.ci_min }},&nbsp;{{ pheno.all.after.ci_max }}]</div>

				<!-- (after) P-VALUE -->
				<div role="cell" v-if="pheno.all.after.pvalue === null">-</div>
				<div role="cell" v-else>{{ pheno.all.after.pvalue_str }}</div>

				<!-- (after) N-INDIVS -->
				<div role="cell" v-if="pheno.all.after.nindivs === null">-</div>
				<div role="cell" v-else>{{ pheno.all.after.nindivs }}</div>

				<!-- (after) COMPBOX -->
				<div role="cell" v-if="pheno.all.after.hr_binned === null">-</div>
				<div role="cell" v-else
					v-html="compBox(pheno.all.after.hr_binned)"
					v-bind:title="textPercentile(Math.trunc(pheno.all.after.hr_binned * 100)) + ' percentile'"
					>
				</div>
			</div>

			<!-- LAG: 1 YEAR -->
			<div
				role="row"
				v-bind:class="bg_even(idx) + ' grid-assoc-body'" v-if="unfolded.has(pheno.name)"
			>

				<!-- LAG -->
				<div role="cell" v-bind:class="bg_even(idx)">&lt;1 year follow-up</div>

				<!-- (before) HR -->
				<div role="cell" v-if="pheno.lagged_1y.before.hr === null">-</div>
				<div role="cell" v-else-if="pheno.lagged_1y.before.hr > 100">&gt;&nbsp;100</div>
				<div role="cell" v-else>{{ pheno.lagged_1y.before.hr_str }} [{{ pheno.lagged_1y.before.ci_min }},&nbsp;{{ pheno.lagged_1y.before.ci_max }}]</div>

				<!-- (before) P-VALUE -->
				<div role="cell" v-if="pheno.lagged_1y.before.pvalue === null">-</div>
				<div role="cell" v-else>{{ pheno.lagged_1y.before.pvalue_str }}</div>

				<!-- (before) N-INDIVS -->
				<div role="cell" v-if="pheno.lagged_1y.before.nindivs === null">-</div>
				<div role="cell" v-else>{{ pheno.lagged_1y.before.nindivs }}</div>

				<!-- (before) COMPBOX -->
				<div role="cell">-</div>

				<!-- (after) HR -->
				<div role="cell" v-if="pheno.lagged_1y.after.hr === null">-</div>
				<div role="cell" v-else-if="pheno.lagged_1y.after.hr > 100">&gt;&nbsp;100</div>
				<div role="cell" v-else>{{ pheno.lagged_1y.after.hr_str }} [{{ pheno.lagged_1y.after.ci_min }},&nbsp;{{ pheno.lagged_1y.after.ci_max }}]</div>

				<!-- (after) P-VALUE -->
				<div role="cell" v-if="pheno.lagged_1y.after.pvalue === null">-</div>
				<div role="cell" v-else>{{ pheno.lagged_1y.after.pvalue_str }}</div>

				<!-- (after) N-INDIVS -->
				<div role="cell" v-if="pheno.lagged_1y.after.nindivs === null">-</div>
				<div role="cell" v-else>{{ pheno.lagged_1y.after.nindivs }}</div>

				<!-- (after) COMPBOX -->
				<div role="cell">-</div>
			</div>

			<!-- LAG: 5 YEARS -->
			<div
				role="row"
				v-bind:class="bg_even(idx) + ' grid-assoc-body'" v-if="unfolded.has(pheno.name)"
			>
				<!-- LAG -->
				<div role="cell" v-bind:class="bg_even(idx)">&lt;1-5 year follow-up</div>

				<!-- (before) HR -->
				<div role="cell" v-if="pheno.lagged_5y.before.hr === null">-</div>
				<div role="cell" v-else-if="pheno.lagged_5y.before.hr > 100">&gt;&nbsp;100</div>
				<div role="cell" v-else>{{ pheno.lagged_5y.before.hr_str }} [{{ pheno.lagged_5y.before.ci_min }},&nbsp;{{ pheno.lagged_5y.before.ci_max }}]</div>

				<!-- (before) P-VALUE -->
				<div role="cell" v-if="pheno.lagged_5y.before.pvalue === null">-</div>
				<div role="cell" v-else>{{ pheno.lagged_5y.before.pvalue_str }}</div>

				<!-- (before) N-INDIVS -->
				<div role="cell" v-if="pheno.lagged_5y.before.nindivs === null">-</div>
				<div role="cell" v-else>{{ pheno.lagged_5y.before.nindivs }}</div>

				<!-- (before) COMPBOX -->
				<div role="cell">-</div>

				<!-- (after) HR -->
				<div role="cell" v-if="pheno.lagged_5y.after.hr === null">-</div>
				<div role="cell" v-else-if="pheno.lagged_5y.after.hr > 100">&gt;&nbsp;100</div>
				<div role="cell" v-else>{{ pheno.lagged_5y.after.hr_str }} [{{ pheno.lagged_5y.after.ci_min }},&nbsp;{{ pheno.lagged_5y.after.ci_max }}]</div>

				<!-- (after) P-VALUE -->
				<div role="cell" v-if="pheno.lagged_5y.after.pvalue === null">-</div>
				<div role="cell" v-else>{{ pheno.lagged_5y.after.pvalue_str }}</div>

				<!-- (after) N-INDIVS -->
				<div role="cell" v-if="pheno.lagged_5y.after.nindivs === null">-</div>
				<div role="cell" v-else>{{ pheno.lagged_5y.after.nindivs }}</div>

				<!-- (after) COMPBOX -->
				<div role="cell">-</div>
			</div>

			<!-- LAG: 15 YEARS -->
			<div
				role="row"
				v-bind:class="bg_even(idx) + ' grid-assoc-body'" v-if="unfolded.has(pheno.name)"
			>
				<!-- LAG -->
				<div role="cell" v-bind:class="bg_even(idx)">&lt;5-15 year follow-up</div>

				<!-- (before) HR -->
				<div role="cell" v-if="pheno.lagged_15y.before.hr === null">-</div>
				<div role="cell" v-else-if="pheno.lagged_15y.before.hr > 100">&gt;&nbsp;100</div>
				<div role="cell" v-else>{{ pheno.lagged_15y.before.hr_str }} [{{ pheno.lagged_15y.before.ci_min }},&nbsp;{{ pheno.lagged_15y.before.ci_max }}]</div>

				<!-- (before) P-VALUE -->
				<div role="cell" v-if="pheno.lagged_15y.before.pvalue === null">-</div>
				<div role="cell" v-else>{{ pheno.lagged_15y.before.pvalue_str }}</div>

				<!-- (before) N-INDIVS -->
				<div role="cell" v-if="pheno.lagged_15y.before.nindivs === null">-</div>
				<div role="cell" v-else>{{ pheno.lagged_15y.before.nindivs }}</div>

				<!-- (before) COMPBOX -->
				<div role="cell">-</div>

				<!-- (after) HR -->
				<div role="cell" v-if="pheno.lagged_15y.after.hr === null">-</div>
				<div role="cell" v-else-if="pheno.lagged_15y.after.hr > 100">&gt;&nbsp;100</div>
				<div role="cell" v-else>{{ pheno.lagged_15y.after.hr_str }} [{{ pheno.lagged_15y.after.ci_min }},&nbsp;{{ pheno.lagged_15y.after.ci_max }}]</div>

				<!-- (after) P-VALUE -->
				<div role="cell" v-if="pheno.lagged_15y.after.pvalue === null">-</div>
				<div role="cell" v-else>{{ pheno.lagged_15y.after.pvalue_str }}</div>

				<!-- (after) N-INDIVS -->
				<div role="cell" v-if="pheno.lagged_15y.after.nindivs === null">-</div>
				<div role="cell" v-else>{{ pheno.lagged_15y.after.nindivs }}</div>

				<!-- (after) COMPBOX -->
				<div role="cell">-</div>
			</div>
		</div>

		<!-- this need to be the last child of the parent <div> element to make the help box always appear -->
        <div id="surv-help" class="dialog-backdrop hidden" tabindex="0">
            <div role="dialog"
                aria-labelledby="surv-help-label"
                aria-modal="true"
            >
                <h2 id="surv-help-label" class="dialog-label">Comparable box plot </h2>
                <article>
					<p>
						This plot allows to compare the hazard ratio (HR) for a single survival analysis with the distribution of HRs across all the survival analyses for the same disease endpoint.
					</p>
					<img src="/images/compbox.svg">
					<p>
						This plot shows the distribution of binned HRs:
					</p>
					<ul>
						<li>X axis: percentile distribution of HRs, from 0 to 1.</li>
						<li>light-grey zone: 95% of all HRs are within this interval</li>
						<li>grey zone: 50% of all HRs are within this interval</li>
						<li>dark vertical line: median of HRs</li>
						<li>black dot: HR for a specific survival analysis</li>
					</ul>
					<p>
						If our endpoint of interest is A and we are interested in the survival analysis of A → B (solid dot), we compute the distribution of HRs of type * → B. If the HR for A → B lies inside the distribution of HRs for * → B , this indicates a not too unsurprising association.
					</p>
                </article>

                <div class="bottom"><button class="button-faded" onclick="closeDialog('surv-help')">Close</button></div>
            </div>
         </div>

	</div>
</template>

<script>
import { concat, filter, partition, reverse, sortBy } from 'lodash-es';
import { drawCompBox } from './CompBox.js';


let compute_table = (col_filter, sorter, table) => {
	let result;

	// Filter rows
	if (col_filter === "") {
		result = table;
	} else {
		result = filter(
			table,
			(pheno) => {
				let match_name = pheno.name.toLowerCase().includes(col_filter.toLowerCase())
				|| pheno.longname.toLowerCase().includes(col_filter.toLowerCase());

				return match_name;
			}
		);
	}

	// Sort rows
	switch (sorter) {
		case "hr_before_desc":
			result = sortByNull(result, (pheno) => pheno.all.before.hr, "desc");
			break;
		case "hr_before_asc":
			result = sortByNull(result, (pheno) => pheno.all.before.hr, "asc");
			break;
		case "pvalue_before_desc":
			result = sortByNull(result, (pheno) => pheno.all.before.pvalue, "desc");
			break;
		case "pvalue_before_asc":
			result = sortByNull(result, (pheno) => pheno.all.before.pvalue, "asc");
			break;
		case "nindivs_before_desc":
			result = sortByNull(result, (pheno) => pheno.all.before.nindivs, "desc");
			break;
		case "nindivs_before_asc":
			result = sortByNull(result, (pheno) => pheno.all.before.nindivs, "asc");
			break;
		case "compbox_before_desc":
			result = sortByNull(result, (pheno) => pheno.all.before.hr_binned, "desc");
			break;
		case "compbox_before_asc":
			result = sortByNull(result, (pheno) => pheno.all.before.hr_binned, "asc");
			break;
		case "hr_after_desc":
			result = sortByNull(result, (pheno) => pheno.all.after.hr, "desc");
			break;
		case "hr_after_asc":
			result = sortByNull(result, (pheno) => pheno.all.after.hr, "asc");
			break;
		case "pvalue_after_desc":
			result = sortByNull(result, (pheno) => pheno.all.after.pvalue, "desc");
			break;
		case "pvalue_after_asc":
			result = sortByNull(result, (pheno) => pheno.all.after.pvalue, "asc");
			break;
		case "nindivs_after_desc":
			result = sortByNull(result, (pheno) => pheno.all.after.nindivs, "desc");
			break;
		case "nindivs_after_asc":
			result = sortByNull(result, (pheno) => pheno.all.after.nindivs, "asc");
			break;
		case "compbox_after_desc":
			result = sortByNull(result, (pheno) => pheno.all.after.hr_binned, "desc");
			break;
		case "compbox_after_asc":
			result = sortByNull(result, (pheno) => pheno.all.after.hr_binned, "asc");
			break;
		default:
			console.log("Unrecognized sorter:", sorter);
	}

	return result
};


/**
 * Same as sortBy but keep null values at the end
 */
let sortByNull = (collection, func, order) => {
    let split = partition(collection, (elem) => func(elem) === null);
    let nans = split[0];
    let nums = split[1];
    let sorted = sortBy(nums, func);
    if (order === "desc") {
        sorted = reverse(sorted);
    }
    return concat(sorted, nans);
};

export default {
	data () {
		return {
			full_table: [],  // keep a copy of the original
			assoc_table: [],
			pheno_filter: "",
			sorter: "hr_before_desc",
			unfolded: new Set(),
		}
	},
	props: {
		table: Array,
		phenocode: String,
	},
	methods: {
		compBox(hr_binned) {
			return drawCompBox(hr_binned);
		},
		refresh_table() {
			this.assoc_table = compute_table(
				this.pheno_filter,
				this.sorter,
				this.full_table
			)
		},
		toggle_fold(phenocode) {
			// Create a copy of the set otherwise VueJS doesn't update the HTML
			let ss = new Set(this.unfolded.values());
			if (ss.has(phenocode)) {
				ss.delete(phenocode);
			} else {
				ss.add(phenocode);
			}
			this.unfolded = ss;
		},
		bg_even(index) {
			if (index % 2 === 1) {
				return "bg-grey-lightest"
			} else {
				return "bg-white"
			}
		},
		textPercentile(n) {
			var ending;

			if (n >= 10 && n <= 20) {
				ending = "th";
			} else {
				const rem = n % 10;
				switch (rem) {
					case 1:
						ending = "st";
						break;
					case 2:
						ending = "nd";
						break;
					case 3:
						ending = "rd";
						break;
					default:
						ending = "th";
				}
			}
			return n + ending
		}
	},
	created () {
		this.full_table = this.table;
		this.assoc_table = this.table;
		this.refresh_table();
	}
}
</script>

<style type="text/css" scoped>
.assoc-scrolling {
	max-height: 500px;
	overflow-y: scroll;
	position: relative;

	/* If not set, scrolled text will appear above the table header.
	   We could have used padding-top: 0; only, but it actually looks better
	   with no padding at all.
	 */
	padding: 0;
}

/* Reset default display: table; from browsers */
[role="table"] {
	display: block;
}

/* Grid table layout */
[role="rowgroup"]:nth-child(1) {
	position: sticky;
	top: 0;
	background-color: #fafafa;
	border-top-width: 1px;
	border-bottom-width: 1px;
	font-weight: bold;
}

.grid-assoc-header-top {
	display: grid;
	grid-template-columns: 6fr 9fr 9fr;
}

.grid-assoc-header-bottom {
	display: grid;
	grid-template-columns: 6fr 3fr 2fr 2fr 2fr 3fr 2fr 2fr 2fr;
}
.grid-assoc-body {
	display: grid;
	grid-template-columns: 6fr 3fr 2fr 2fr 2fr 3fr 2fr 2fr 2fr;
}

/* Place table header widget near the bottom */
[role="columnheader"] {
	display: grid;
	grid-template-columns: 1fr;
}
[role="columnheader"] p:last-child {
	align-self: end;
	margin-top: 0.25rem;
}
/* Hide overflowing endpoint code name */
[role="cell"]:nth-child(1) {
	overflow: hidden;
}
</style>
