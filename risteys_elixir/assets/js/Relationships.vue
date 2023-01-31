<template>
	<div role="table" class="assoc-scrolling">
		<div role="rowgroup">
			<div role="row" class="grid-assoc-header-top">
					<div role="columnheader">
						<p>Endpoint</p>
					</div>

					<div role="columnheader" aria-colspan = "2" class = "border-left">
						<p>
							<abbr data-title="Number and percentage of overlapping cases">Case overlap:<br> N, Jaccard index</abbr>
						</p>
					</div>

					<div role="columnheader" aria-colspan = "2" class = "border-left inc-pr">
						<p>Survival analysis, FR</p>
					</div>

					<div role="columnheader" aria-colspan = "2" class = "border-left">
						<p>Genetic correlation, FG</p>
					</div>

					<div role="columnheader" aria-colspan = "2" class = "border-left">
						<p>Genetic signals, FG</p>
					</div>
			</div>

			<div role="row" class="grid-assoc-header-bottom pb-2">
				<div role="columnheader">
					<p>
						<input
								type="text"
								placeholder="filter by name"
								v-on:keyup.stop="refresh_table()"
								v-model="endpoint_filter"
								class="mt-2">
						</p>
				</div>

				<div role="columnheader" class="green border-left">
					<p> FR </p>
					<p>
						<input type="radio" id="nindivs_fr_asc" value="nindivs_fr_asc" v-model="sorter" v-on:change="refresh_table()">
						<label for="nindivs_fr_asc" class="radio-left">▲</label>
						<input type="radio" id="nindivs_fr_desc" value="nindivs_fr_desc" v-model="sorter" v-on:change="refresh_table()">
						<label for="nindivs_fr_desc" class="radio-right">▼</label>
					</p>
				</div>
				<div role="columnheader" class = "dec-pl blue">
					<p> FG </p>
					<p>
						<input type="radio" id="nindivs_fg_asc" value="nindivs_fg_asc" v-model="sorter" v-on:change="refresh_table()">
						<label for="nindivs_fg_asc" class="radio-left">▲</label>
						<input type="radio" id="nindivs_fg_desc" value="nindivs_fg_desc" v-model="sorter" v-on:change="refresh_table()">
						<label for="nindivs_fg_desc" class="radio-right">▼</label>
					</p>
				</div>

				<div role="columnheader" class = "border-left green">
					<p>
						<abbr data-title="Hazard ratio and 95% confidence interval">HR [95%&nbsp;CI] </abbr>
					</p>
					<p>
						<input type="radio" id="hr_fr_asc" value="hr_fr_asc" v-model="sorter" v-on:change="refresh_table()">
						<label for="hr_fr_asc" class="radio-left">▲</label>
						<input type="radio" id="hr_fr_desc" value="hr_fr_desc" v-model="sorter" v-on:change="refresh_table()">
						<label for="hr_fr_desc" class="radio-right">▼</label>
					</p>
				</div>
				<div role="columnheader" class = "dec-pl inc-pr green">
					<p>
						<abbr data-title="Shows how extreme the value is on the total distribution">Extremity </abbr>
					</p>
					<p>
						<input type="radio" id="hr_extr_asc" value="hr_extr_asc" v-model="sorter" v-on:change="refresh_table()">
						<label for="hr_extr_asc" class="radio-left">▲</label>
						<input type="radio" id="hr_extr_desc" value="hr_extr_desc" v-model="sorter" v-on:change="refresh_table()">
						<label for="hr_extr_desc" class="radio-right">▼</label>
					</p>
				</div>

				<div role="columnheader" class = "border-left blue">
					<p>rg [95%&nbsp;CI]</p>
					<p>
						<input type="radio" id="rg_fg_asc" value="rg_fg_asc" v-model="sorter" v-on:change="refresh_table()">
						<label for="rg_fg_asc" class="radio-left">▲</label>
						<input type="radio" id="rg_fg_desc" value="rg_fg_desc" v-model="sorter" v-on:change="refresh_table()">
						<label for="rg_fg_desc" class="radio-right">▼</label>
					</p>
				</div>

				<div role="columnheader" class = "dec-pl inc-pr blue">
					<p>
						<abbr data-title="Shows how extreme the value is on the total distribution">Extremity </abbr>
					</p>
					<p>
						<input type="radio" id="rg_extr_asc" value="rg_extr_asc" v-model="sorter" v-on:change="refresh_table()">
						<label for="rg_extr_asc" class="radio-left">▲</label>
						<input type="radio" id="rg_extr_desc" value="rg_extr_desc" v-model="sorter" v-on:change="refresh_table()">
						<label for="rg_extr_desc" class="radio-right">▼</label>
					</p>
				</div>

				<div role="columnheader" class = "border-left blue">
					<p>Hits</p>
					<p>
						<input type="radio" id="hits_fg_asc" value="hits_fg_asc" v-model="sorter" v-on:change="refresh_table()">
						<label for="hits_fg_asc" class="radio-left">▲</label>
						<input type="radio" id="hits_fg_desc" value="hits_fg_desc" v-model="sorter" v-on:change="refresh_table()">
						<label for="hits_fg_desc" class="radio-right">▼</label>
					</p>
				</div>

				<div role="columnheader" class = "dec-pl blue">
					<p>Coloc hits</p>
					<p>
						<input type="radio" id="coloc_hits_fg_asc" value="coloc_hits_fg_asc" v-model="sorter" v-on:change="refresh_table()">
						<label for="coloc_hits_fg_asc" class="radio-left">▲</label>
						<input type="radio" id="coloc_hits_fg_desc" value="coloc_hits_fg_desc" v-model="sorter" v-on:change="refresh_table()">
						<label for="coloc_hits_fg_desc" class="radio-right">▼</label>
					</p>
				</div>
			</div>
		</div>

		<div v-for="(endpoint, idx) in assoc_table" role="rowgroup">
			<!-- LAG: no lag -->
			<div
				role="row"
				v-bind:class="bg_even(idx) + ' grid-assoc-body'"
			>
				<!-- ENDPOINT NAME -->
				<div role="cell">
					<a :href="'/endpoints/' + endpoint.name" :title="endpoint.name">{{ endpoint.longname }}</a>
				</div>

				<!-- case overlap FR-->
				<div role="cell" v-if="endpoint.fr_case_overlap_N === null"> - </div>
				<div role="cell" v-else> {{ endpoint.fr_case_overlap_N}} <br> {{ endpoint.fr_case_overlap_percent }}</div>

				<!-- case overlap FG-->
				<div role="cell" v-if="endpoint.fg_case_overlap_N === null"> - </div>
				<div role="cell" v-else> {{ endpoint.fg_case_overlap_N }} <br> {{endpoint.fg_case_overlap_percent }}</div>

				<!-- HR -->
				<div role="cell" v-if="endpoint.hr === null">-</div>
				<div role="cell" v-else-if="endpoint.hr > 100">&gt;&nbsp;100</div>
				<div role="cell" v-else>{{ endpoint.hr_str }} [{{ endpoint.hr_ci_min }},&nbsp;{{ endpoint.hr_ci_max }}]{{endpoint.hr_pvalue_str}}</div>

				<!-- HR extremity -->
				<div role="cell" v-if="endpoint.hr_binned === null">-</div>
				<div
					role="cell" v-else
					v-html="compBox(endpoint.hr_binned)"
					v-bind:title="textPercentile(Math.trunc(endpoint.hr_binned * 100)) + ' percentile'"
				>
				</div>

				<!-- Genetic correlation -->
				<div role="cell" v-if="endpoint.rg === null">-</div>
				<div role="cell" v-else> {{ endpoint.rg_str}} [{{ endpoint.rg_ci_min}},&nbsp;{{endpoint.rg_ci_max}}]{{endpoint.rg_pvalue_str}}</div>

				<!-- Genetic correlation extremity -->
				<div role="cell" v-if="endpoint.rg_binned === null">-</div>
				<div
					role="cell" v-else
					v-html="compBox(endpoint.rg_binned)"
					v-bind:title="textPercentile(Math.trunc(endpoint.rg_binned * 100) + ' percentile')"
				>
				</div>

				<!-- GWS hits -->
				<div role="cell" v-if="endpoint.gws_hits === null">-</div>
				<div role="cell" v-else> {{ endpoint.gws_hits }}</div>

				<!-- GWS coloc hits -->
				<div role="cell" v-if="endpoint.coloc_gws_hits === null">-</div>
				<div role="cell" v-else> {{ endpoint.coloc_gws_hits}} </div>
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
			(endpoint) => {
				let match_name = endpoint.name.toLowerCase().includes(col_filter.toLowerCase())
				|| endpoint.longname.toLowerCase().includes(col_filter.toLowerCase());

				return match_name;
			}
		);
	}

	// Sort rows
	switch (sorter) {
		case "nindivs_fr_desc":
			result = sortByNull(result, (endpoint) => endpoint.fr_case_overlap_N, "desc");
			break;
		case "nindivs_fr_asc":
			result = sortByNull(result, (endpoint) => endpoint.fr_case_overlap_N, "asc");
			break;
		case "nindivs_fg_desc":
			result = sortByNull(result, (endpoint) => endpoint.fg_case_overlap_N, "desc");
			break;
		case "nindivs_fg_asc":
			result = sortByNull(result, (endpoint) => endpoint.fg_case_overlap_N, "asc");
			break;
		case "hr_fr_desc":
			result = sortByNull(result, (endpoint) => endpoint.hr, "desc");
			break;
		case "hr_fr_asc":
			result = sortByNull(result, (endpoint) => endpoint.hr, "asc");
			break;
		case "hr_extr_desc":
			result = sortByNull(result, (endpoint) => endpoint.hr_binned, "desc");
			break;
		case "hr_extr_asc":
			result = sortByNull(result, (endpoint) => endpoint.hr_binned, "asc");
			break;
		case "rg_fg_desc":
			result = sortByNull(result, (endpoint) => endpoint.rg, "desc");
			break;
		case "rg_fg_asc":
			result = sortByNull(result, (endpoint) => endpoint.rg, "asc");
			break;
		case "rg_extr_desc":
			result = sortByNull(result, (endpoint) => endpoint.rg_binned, "desc");
			break;
		case "rg_extr_asc":
			result = sortByNull(result, (endpoint) => endpoint.rg_binned, "asc");
			break;
		case "hits_fg_desc":
			result = sortByNull(result, (endpoint) => endpoint.gws_hits, "desc");
			break;
		case "hits_fg_asc":
			result = sortByNull(result, (endpoint) => endpoint.gws_hits, "asc");
			break;
		case "coloc_hits_fg_desc":
			result = sortByNull(result, (endpoint) => endpoint.coloc_gws_hits, "desc");
			break;
		case "coloc_hits_fg_asc":
			result = sortByNull(result, (endpoint) => endpoint.coloc_gws_hits, "asc");
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
			endpoint_filter: "",
			sorter: "hr_fr_desc",
		}
	},
	props: {
		table: Array,
		endpoint: String,
	},
	methods: {
		compBox(hr_binned) {
			return drawCompBox(hr_binned);
		},
		refresh_table() {
			this.assoc_table = compute_table(
				this.endpoint_filter,
				this.sorter,
				this.full_table
			)
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

* {
	box-sizing: border-box;
}

.mb-50 {
	margin-bottom: 1rem;
}

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
	grid-template-columns: 2.5fr 1.8fr 3.1fr 3.1fr 1.9fr;
	@apply pt-2;
}

.grid-assoc-header-bottom {
	display: grid;
	grid-template-columns: 2.5fr 1fr 0.8fr 2fr 1.1fr 2fr 1.1fr 0.9fr 1fr;
}
.grid-assoc-body {
	display: grid;
	grid-template-columns: 2.5fr 1fr 0.8fr 2fr 1.1fr 2fr 1.1fr 0.9fr 1fr;
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

.dec-pl {
	@apply pl-0;
}

.inc-pr {
	/*@apply pr-5;*/
}

.blue {
	color: #2779bd; /* #3490DC;*/
}

.green {
	/*color: #14b8a6;*/
	color: rgb(15 118 110);
}

.border-left {
	border-left: 1px solid #dae1e7;
}

/* Hide overflowing endpoint code name */
[role="cell"]:nth-child(1) {
	overflow: hidden;
}

abbr {
  text-decoration: none;
}
</style>
