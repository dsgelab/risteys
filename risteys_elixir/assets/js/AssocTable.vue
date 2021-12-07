<template>
	<div class="scrolling">
		<table>
			<col>
			<colgroup span="4"></colgroup>
			<colgroup span="4"></colgroup>
			<thead>
				<tr>
					<th rowspan="2">
						<div class="border-t border-b h-full pl-2 pt-4">  <!-- div hack to have the borders stay in place on scroll -->
							Endpoint<br>
							<input
								type="text"
								placeholder="filter by name"
								v-on:keyup.stop="refresh_table()"
								v-model="pheno_filter"
								class="mt-2">
						</div>
					</th>
					<th colspan="4" scope="colgroup">
						<div class="border-t h-full pt-2"> {{ phenocode }} as outcome</div>
					</th>
					<th colspan="4" scope="colgroup">
						<div class="border-t h-full pt-2"> {{ phenocode }} as exposure</div>
					</th>
				</tr>
				<tr>
					<th scope="col">
						<div class="border-b h-full">
							HR [95%&nbsp;CI] <br>
							<input type="radio" id="hr_before_asc" value="hr_before_asc" v-model="sorter" v-on:change="refresh_table()" checked><label for="hr_before_asc" class="radio-left">▲</label><input type="radio" id="hr_before_desc" value="hr_before_desc" v-model="sorter" v-on:change="refresh_table()"><label for="hr_before_desc" class="radio-right">▼</label>
						</div>
					</th>
					<th scope="col">
						<div class="border-b h-full">
							p <br>
							<input type="radio" id="pvalue_before_asc" value="pvalue_before_asc" v-model="sorter" v-on:change="refresh_table()"><label for="pvalue_before_asc" class="radio-left">▲</label><input type="radio" id="pvalue_before_desc" value="pvalue_before_desc" v-model="sorter" v-on:change="refresh_table()"><label for="pvalue_before_desc" class="radio-right">▼</label>
						</div>
					</th>
					<th scope="col">
						<div class="border-b h-full">
							<abbr data-title="Number of overlapping individuals">N</abbr> <br>
							<input type="radio" id="nindivs_before_asc" value="nindivs_before_asc" v-model="sorter" v-on:change="refresh_table()"><label for="nindivs_before_asc" class="radio-left">▲</label><input type="radio" id="nindivs_before_desc" value="nindivs_before_desc" v-model="sorter" v-on:change="refresh_table()"><label for="nindivs_before_desc" class="radio-right">▼</label>
						</div>
					</th>
					<th scope="col">
						<div class="border-b h-full">
							<HelpCompBox /> <br>
							<input type="radio" id="compbox_before_asc" value="compbox_before_asc" v-model="sorter" v-on:change="refresh_table()" checked><label for="compbox_before_asc" class="radio-left">▲</label><input type="radio" id="compbox_before_desc" value="compbox_before_desc" v-model="sorter" v-on:change="refresh_table()"><label for="compbox_before_desc" class="radio-right">▼</label>
						</div>
					</th>
					<th scope="col">
						<div class="border-b h-full">
							HR [95%&nbsp;CI] <br>
							<input type="radio" id="hr_after_asc" value="hr_after_asc" v-model="sorter" v-on:change="refresh_table()"><label for="hr_after_asc" class="radio-left">▲</label><input type="radio" id="hr_after_desc" value="hr_after_desc" v-model="sorter" v-on:change="refresh_table()"><label for="hr_after_desc" class="radio-right">▼</label>
						</div>
					</th>
					<th scope="col">
						<div class="border-b h-full">
							p <br>
							<input type="radio" id="pvalue_after_asc" value="pvalue_after_asc" v-model="sorter" v-on:change="refresh_table()"><label for="pvalue_after_asc" class="radio-left">▲</label><input type="radio" id="pvalue_after_desc" value="pvalue_after_desc" v-model="sorter" v-on:change="refresh_table()"><label for="pvalue_after_desc" class="radio-right">▼</label>
						</div>
					</th>
					<th scope="col">
						<div class="border-b h-full">
							<abbr data-title="Number of overlapping individuals">N</abbr> <br>
							<input type="radio" id="nindivs_after_asc" value="nindivs_after_asc" v-model="sorter" v-on:change="refresh_table()"><label for="nindivs_after_asc" class="radio-left">▲</label><input type="radio" id="nindivs_after_desc" value="nindivs_after_desc" v-model="sorter" v-on:change="refresh_table()"><label for="nindivs_after_desc" class="radio-right">▼</label>
						</div>
					</th>
					<th scope="col">
						<div class="border-b h-full">
							<HelpCompBox /> <br>
							<input type="radio" id="compbox_after_asc" value="compbox_after_asc" v-model="sorter" v-on:change="refresh_table()" checked><label for="compbox_after_asc" class="radio-left">▲</label><input type="radio" id="compbox_after_desc" value="compbox_after_desc" v-model="sorter" v-on:change="refresh_table()"><label for="compbox_after_desc" class="radio-right">▼</label>
						</div>
					</th>
				</tr>
			</thead>
			<tbody>
				<template v-for="(pheno, idx) in assoc_table">
					<!-- LAG: no lag -->
					<tr v-bind:class="bg_even(idx)">
						<!-- ENDPOINT NAME -->
						<th v-bind:class="bg_even(idx)">
							<img src="/images/explag.svg" v-on:click="toggle_fold(pheno.name)" alt="expand data" class="cursor-pointer mini-button">
							<a :href="'/phenocode/' + pheno.name" :title="pheno.name">{{ pheno.longname }}</a>
						</th>

						<!-- (before) HR -->
						<td v-if="pheno.all.before.hr === null">-</td>
						<td v-else-if="pheno.all.before.hr > 100">&gt;&nbsp;100</td>
						<td v-else>{{ pheno.all.before.hr_str }}&nbsp;[{{ pheno.all.before.ci_min }},&nbsp;{{ pheno.all.before.ci_max }}]</td>

						<!-- (before) P-VALUE -->
						<td v-if="pheno.all.before.pvalue === null">-</td>
						<td v-else>{{ pheno.all.before.pvalue_str }}</td>

						<!-- (before) N-INDIVS -->
						<td v-if="pheno.all.before.nindivs === null">-</td>
						<td v-else>{{ pheno.all.before.nindivs }}</td>

						<!-- (before) COMPBOX -->
						<td v-if="pheno.all.before.hr_binned === null">-</td>
 						<td	v-else
 							v-html="compBox(pheno.all.before.hr_binned)"
 							v-bind:title="textPercentile(Math.trunc(pheno.all.before.hr_binned * 100)) + ' percentile'">
						</td>

						<!-- (after) HR -->
						<td v-if="pheno.all.after.hr === null">-</td>
						<td v-else-if="pheno.all.after.hr > 100">&gt;&nbsp;100</td>
						<td v-else>{{ pheno.all.after.hr_str }}&nbsp;[{{ pheno.all.after.ci_min }},&nbsp;{{ pheno.all.after.ci_max }}]</td>

						<!-- (after) P-VALUE -->
						<td v-if="pheno.all.after.pvalue === null">-</td>
						<td v-else>{{ pheno.all.after.pvalue_str }}</td>

						<!-- (after) N-INDIVS -->
						<td v-if="pheno.all.after.nindivs === null">-</td>
						<td v-else>{{ pheno.all.after.nindivs }}</td>

						<!-- (after) COMPBOX -->
						<td v-if="pheno.all.after.hr_binned === null">-</td>
						<td v-else
							v-html="compBox(pheno.all.after.hr_binned)"
							v-bind:title="textPercentile(Math.trunc(pheno.all.after.hr_binned * 100)) + ' percentile'"
							>
						</td>
					</tr>

					<!-- LAG: 1 YEAR -->
					<tr v-bind:class="bg_even(idx)" v-if="unfolded.has(pheno.name)">
						<!-- LAG -->
						<th v-bind:class="bg_even(idx)" class="text-right pr-5">&lt;1 year follow-up</th>

						<!-- (before) HR -->
						<td v-if="pheno.lagged_1y.before.hr === null">-</td>
						<td v-else-if="pheno.lagged_1y.before.hr > 100">&gt;&nbsp;100</td>
						<td v-else>{{ pheno.lagged_1y.before.hr_str }}&nbsp;[{{ pheno.lagged_1y.before.ci_min }},&nbsp;{{ pheno.lagged_1y.before.ci_max }}]</td>

						<!-- (before) P-VALUE -->
						<td v-if="pheno.lagged_1y.before.pvalue === null">-</td>
						<td v-else>{{ pheno.lagged_1y.before.pvalue_str }}</td>

						<!-- (before) N-INDIVS -->
						<td v-if="pheno.lagged_1y.before.nindivs === null">-</td>
						<td v-else>{{ pheno.lagged_1y.before.nindivs }}</td>

						<!-- (before) COMPBOX -->
						<td>-</td>

						<!-- (after) HR -->
						<td v-if="pheno.lagged_1y.after.hr === null">-</td>
						<td v-else-if="pheno.lagged_1y.after.hr > 100">&gt;&nbsp;100</td>
						<td v-else>{{ pheno.lagged_1y.after.hr_str }}&nbsp;[{{ pheno.lagged_1y.after.ci_min }},&nbsp;{{ pheno.lagged_1y.after.ci_max }}]</td>

						<!-- (after) P-VALUE -->
						<td v-if="pheno.lagged_1y.after.pvalue === null">-</td>
						<td v-else>{{ pheno.lagged_1y.after.pvalue_str }}</td>

						<!-- (after) N-INDIVS -->
						<td v-if="pheno.lagged_1y.after.nindivs === null">-</td>
						<td v-else>{{ pheno.lagged_1y.after.nindivs }}</td>

						<!-- (after) COMPBOX -->
						<td>-</td>
					</tr>

					<!-- LAG: 5 YEARS -->
					<tr v-bind:class="bg_even(idx)" v-if="unfolded.has(pheno.name)">
						<!-- LAG -->
						<th v-bind:class="bg_even(idx)" class="text-right pr-5">&lt;1-5 year follow-up</th>

						<!-- (before) HR -->
						<td v-if="pheno.lagged_5y.before.hr === null">-</td>
						<td v-else-if="pheno.lagged_5y.before.hr > 100">&gt;&nbsp;100</td>
						<td v-else>{{ pheno.lagged_5y.before.hr_str }}&nbsp;[{{ pheno.lagged_5y.before.ci_min }},&nbsp;{{ pheno.lagged_5y.before.ci_max }}]</td>

						<!-- (before) P-VALUE -->
						<td v-if="pheno.lagged_5y.before.pvalue === null">-</td>
						<td v-else>{{ pheno.lagged_5y.before.pvalue_str }}</td>

						<!-- (before) N-INDIVS -->
						<td v-if="pheno.lagged_5y.before.nindivs === null">-</td>
						<td v-else>{{ pheno.lagged_5y.before.nindivs }}</td>

						<!-- (before) COMPBOX -->
						<td>-</td>

						<!-- (after) HR -->
						<td v-if="pheno.lagged_5y.after.hr === null">-</td>
						<td v-else-if="pheno.lagged_5y.after.hr > 100">&gt;&nbsp;100</td>
						<td v-else>{{ pheno.lagged_5y.after.hr_str }}&nbsp;[{{ pheno.lagged_5y.after.ci_min }},&nbsp;{{ pheno.lagged_5y.after.ci_max }}]</td>

						<!-- (after) P-VALUE -->
						<td v-if="pheno.lagged_5y.after.pvalue === null">-</td>
						<td v-else>{{ pheno.lagged_5y.after.pvalue_str }}</td>

						<!-- (after) N-INDIVS -->
						<td v-if="pheno.lagged_5y.after.nindivs === null">-</td>
						<td v-else>{{ pheno.lagged_5y.after.nindivs }}</td>

						<!-- (after) COMPBOX -->
						<td>-</td>
					</tr>

					<!-- LAG: 15 YEARS -->
					<tr v-bind:class="bg_even(idx)" v-if="unfolded.has(pheno.name)">
						<!-- LAG -->
						<th v-bind:class="bg_even(idx)" class="text-right pr-5">&lt;5-15 year follow-up</th>

						<!-- (before) HR -->
						<td v-if="pheno.lagged_15y.before.hr === null">-</td>
						<td v-else-if="pheno.lagged_15y.before.hr > 100">&gt;&nbsp;100</td>
						<td v-else>{{ pheno.lagged_15y.before.hr_str }}&nbsp;[{{ pheno.lagged_15y.before.ci_min }},&nbsp;{{ pheno.lagged_15y.before.ci_max }}]</td>

						<!-- (before) P-VALUE -->
						<td v-if="pheno.lagged_15y.before.pvalue === null">-</td>
						<td v-else>{{ pheno.lagged_15y.before.pvalue_str }}</td>

						<!-- (before) N-INDIVS -->
						<td v-if="pheno.lagged_15y.before.nindivs === null">-</td>
						<td v-else>{{ pheno.lagged_15y.before.nindivs }}</td>

						<!-- (before) COMPBOX -->
						<td>-</td>

						<!-- (after) HR -->
						<td v-if="pheno.lagged_15y.after.hr === null">-</td>
						<td v-else-if="pheno.lagged_15y.after.hr > 100">&gt;&nbsp;100</td>
						<td v-else>{{ pheno.lagged_15y.after.hr_str }}&nbsp;[{{ pheno.lagged_15y.after.ci_min }},&nbsp;{{ pheno.lagged_15y.after.ci_max }}]</td>

						<!-- (after) P-VALUE -->
						<td v-if="pheno.lagged_15y.after.pvalue === null">-</td>
						<td v-else>{{ pheno.lagged_15y.after.pvalue_str }}</td>

						<!-- (after) N-INDIVS -->
						<td v-if="pheno.lagged_15y.after.nindivs === null">-</td>
						<td v-else>{{ pheno.lagged_15y.after.nindivs }}</td>

						<!-- (after) COMPBOX -->
						<td>-</td>
					</tr>
				</template>
			</tbody>
		</table>
	</div>
</template>

<script>
import { concat, filter, partition, reverse, sortBy } from 'lodash-es';
import { drawCompBox } from './CompBox.js';
import HelpCompBox from './HelpCompBox.vue';


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
	components: {
		HelpCompBox,
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
div.scrolling {
	max-width: 100%;
	max-height: 500px;
	overflow: scroll;
	position: relative;

	font-size: 0.6rem;
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

/* thead: endpoint cell */
.scrolling thead tr:first-child th:first-child {
	left: 0;
	z-index: 1;
	height: 100px;
}

/* thead: top row */
.scrolling thead tr:nth-child(1) th {
	position: sticky;

	top: 0;
	height: 40px;
}

/* thead: bottom row */;
.scrolling thead tr:nth-child(2) th {
	position: sticky;

	top: 40px;
	height: 60px;
	line-height: 1.5;
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
