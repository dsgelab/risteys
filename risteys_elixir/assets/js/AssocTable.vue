<template>
	<div>
		<div class="assoc-grid thead">
			<div class="before"><b>before</b> {{ phenocode }}</div>
			<div class="after"><b>after</b> {{ phenocode }}</div>

			<div class="font-bold">
				Phenocode<br>
				<input
					type="text"
					placeholder="filter by name"
					v-on:keyup.stop="comp_table"
					v-model="pheno_filter">
			</div>
			<div class="font-bold col-interactive" v-on:click="sort_table('before_hr')">{{ symbol_sort("before_hr") }} HR [95%&nbsp;CI]</div>
			<div class="font-bold col-interactive" v-on:click="sort_table('before_pvalue')">{{ symbol_sort("before_pvalue") }} p</div>
			<div class="font-bold col-interactive" v-on:click="sort_table('before_nindivs')">{{ symbol_sort("before_nindivs") }}
				<abbr data-title="Number of overlapping individuals">N</abbr>
			</div>
			<div><HelpCompBox /></div>
			<div class="font-bold col-interactive" v-on:click="sort_table('after_hr')">{{ symbol_sort("after_hr") }} HR [95%&nbsp;CI]</div>
			<div class="font-bold col-interactive" v-on:click="sort_table('after_pvalue')">{{ symbol_sort("after_pvalue") }} p</div>
			<div class="font-bold col-interactive" v-on:click="sort_table('after_nindivs')">{{ symbol_sort("after_nindivs") }}
				<abbr data-title="Number of overlapping individuals">N</abbr>
			</div>
			<div><HelpCompBox /></div>
		</div>

		<div class="assoc-grid assoc-data">
			<template v-for="(pheno, idx) in assoc_table">
				<div v-bind:class="bg_even(idx)">
					<img src="/images/explag.svg" v-on:click="toggle_fold(pheno.name)" alt="expand data" class="cursor-pointer mini-button">
					<a :href="'/phenocode/' + pheno.name" :title="pheno.name">{{ pheno.longname }}</a>
				</div>

				<div v-bind:class="bg_even(idx)" v-if="pheno.all.before.hr === null">-</div>
				<div v-bind:class="bg_even(idx)" v-else-if="pheno.all.before.hr > 100">&gt;&nbsp;100</div>
				<div v-bind:class="bg_even(idx)" v-else>{{ pheno.all.before.hr_str }}&nbsp;[{{ pheno.all.before.ci_min }},&nbsp;{{ pheno.all.before.ci_max }}]</div>

				<div v-bind:class="bg_even(idx)" v-if="pheno.all.before.pvalue === null">-</div>
				<div v-bind:class="bg_even(idx)" v-else>{{ pheno.all.before.pvalue_str }}</div>

				<div v-bind:class="bg_even(idx)" v-if="pheno.all.before.nindivs === null">-</div>
				<div v-bind:class="bg_even(idx)" v-else>{{ pheno.all.before.nindivs }}</div>


				<div
					v-if="pheno.all.before.hr_norm === null"
					v-bind:class="bg_even(idx)">
					-
				</div>
				<div
					v-else
					v-bind:class="bg_even(idx)"
					v-html="compBox(pheno.all.before.hr_norm, pheno.all.before.hr_norm_min, pheno.all.before.hr_norm_max)">
				</div>

				<div v-bind:class="bg_even(idx)" v-if="pheno.all.after.hr === null">-</div>
				<div v-bind:class="bg_even(idx)" v-else-if="pheno.all.after.hr > 100">&gt;&nbsp;100</div>
				<div v-bind:class="bg_even(idx)" v-else>{{ pheno.all.after.hr_str }}&nbsp;[{{ pheno.all.after.ci_min }},&nbsp;{{ pheno.all.after.ci_max }}]</div>

				<div v-bind:class="bg_even(idx)" v-if="pheno.all.after.pvalue === null">-</div>
				<div v-bind:class="bg_even(idx)" v-else>{{ pheno.all.after.pvalue_str }}</div>

				<div v-bind:class="bg_even(idx)" v-if="pheno.all.after.nindivs === null">-</div>
				<div v-bind:class="bg_even(idx)" v-else>{{ pheno.all.after.nindivs }}</div>

				<div
					v-if="pheno.all.after.hr_norm === null"
					v-bind:class="bg_even(idx)">
					-
				</div>
				<div
					v-else
					v-bind:class="bg_even(idx)"
					v-html="compBox(pheno.all.after.hr_norm, pheno.all.after.hr_norm_min, pheno.all.after.hr_norm_max)">
				</div>

				<template v-if="unfolded.has(pheno.name)">
					<!-- LAG 1 YEAR -->
					<div v-bind:class="bg_even(idx)" class="text-right pr-5">&lt;1 year follow-up</div>
					<div v-bind:class="bg_even(idx)" v-if="pheno.lagged_1y.before.hr === null">-</div>
					<div v-bind:class="bg_even(idx)" v-else>{{ pheno.lagged_1y.before.hr_str }}&nbsp;[{{ pheno.lagged_1y.before.ci_min }},&nbsp;{{ pheno.lagged_1y.before.ci_max }}]</div>

					<div v-bind:class="bg_even(idx)" v-if="pheno.lagged_1y.before.pvalue === null">-</div>
					<div v-bind:class="bg_even(idx)" v-else>{{ pheno.lagged_1y.before.pvalue_str }}</div>

					<div v-bind:class="bg_even(idx)" v-if="pheno.lagged_1y.before.nindivs === null">-</div>
					<div v-bind:class="bg_even(idx)" v-else>{{ pheno.lagged_1y.before.nindivs }}</div>

					<div v-bind:class="bg_even(idx)">-</div>

					<div v-bind:class="bg_even(idx)" v-if="pheno.lagged_1y.after.hr === null">-</div>
					<div v-bind:class="bg_even(idx)" v-else>{{ pheno.lagged_1y.after.hr_str }}&nbsp;[{{ pheno.lagged_1y.after.ci_min }},&nbsp;{{ pheno.lagged_1y.after.ci_max }}]</div>

					<div v-bind:class="bg_even(idx)" v-if="pheno.lagged_1y.after.pvalue === null">-</div>
					<div v-bind:class="bg_even(idx)" v-else>{{ pheno.lagged_1y.after.pvalue_str }}</div>

					<div v-bind:class="bg_even(idx)" v-if="pheno.lagged_1y.after.nindivs === null">-</div>
					<div v-bind:class="bg_even(idx)" v-else>{{ pheno.lagged_1y.after.nindivs }}</div>

					<div v-bind:class="bg_even(idx)">-</div>


					<!-- LAG 5 YEARS -->
					<div v-bind:class="bg_even(idx)" class="text-right pr-5">1-5 year follow-up</div>
					<div v-bind:class="bg_even(idx)" v-if="pheno.lagged_5y.before.hr === null">-</div>
					<div v-bind:class="bg_even(idx)" v-else>{{ pheno.lagged_5y.before.hr_str }}&nbsp;[{{ pheno.lagged_5y.before.ci_min }},&nbsp;{{ pheno.lagged_5y.before.ci_max }}]</div>

					<div v-bind:class="bg_even(idx)" v-if="pheno.lagged_5y.before.pvalue === null">-</div>
					<div v-bind:class="bg_even(idx)" v-else>{{ pheno.lagged_5y.before.pvalue_str }}</div>

					<div v-bind:class="bg_even(idx)" v-if="pheno.lagged_5y.before.nindivs === null">-</div>
					<div v-bind:class="bg_even(idx)" v-else>{{ pheno.lagged_5y.before.nindivs }}</div>

					<div v-bind:class="bg_even(idx)">-</div>

					<div v-bind:class="bg_even(idx)" v-if="pheno.lagged_5y.after.hr === null">-</div>
					<div v-bind:class="bg_even(idx)" v-else>{{ pheno.lagged_5y.after.hr_str }}&nbsp;[{{ pheno.lagged_5y.after.ci_min }},&nbsp;{{ pheno.lagged_5y.after.ci_max }}]</div>

					<div v-bind:class="bg_even(idx)" v-if="pheno.lagged_5y.after.pvalue === null">-</div>
					<div v-bind:class="bg_even(idx)" v-else>{{ pheno.lagged_5y.after.pvalue_str }}</div>

					<div v-bind:class="bg_even(idx)" v-if="pheno.lagged_5y.after.nindivs === null">-</div>
					<div v-bind:class="bg_even(idx)" v-else>{{ pheno.lagged_5y.after.nindivs }}</div>

					<div v-bind:class="bg_even(idx)">-</div>

					<!-- LAG 15 YEARS -->
					<div v-bind:class="bg_even(idx)" class="text-right pr-5">5-15 year follow-up</div>
					<div v-bind:class="bg_even(idx)" v-if="pheno.lagged_15y.before.hr === null">-</div>
					<div v-bind:class="bg_even(idx)" v-else>{{ pheno.lagged_15y.before.hr_str }}&nbsp;[{{ pheno.lagged_15y.before.ci_min }},&nbsp;{{ pheno.lagged_15y.before.ci_max }}]</div>

					<div v-bind:class="bg_even(idx)" v-if="pheno.lagged_15y.before.pvalue === null">-</div>
					<div v-bind:class="bg_even(idx)" v-else>{{ pheno.lagged_15y.before.pvalue_str }}</div>

					<div v-bind:class="bg_even(idx)" v-if="pheno.lagged_15y.before.nindivs === null">-</div>
					<div v-bind:class="bg_even(idx)" v-else>{{ pheno.lagged_15y.before.nindivs }}</div>

					<div v-bind:class="bg_even(idx)">-</div>

					<div v-bind:class="bg_even(idx)" v-if="pheno.lagged_15y.after.hr === null">-</div>
					<div v-bind:class="bg_even(idx)" v-else>{{ pheno.lagged_15y.after.hr_str }}&nbsp;[{{ pheno.lagged_15y.after.ci_min }},&nbsp;{{ pheno.lagged_15y.after.ci_max }}]</div>

					<div v-bind:class="bg_even(idx)" v-if="pheno.lagged_15y.after.pvalue === null">-</div>
					<div v-bind:class="bg_even(idx)" v-else>{{ pheno.lagged_15y.after.pvalue_str }}</div>

					<div v-bind:class="bg_even(idx)" v-if="pheno.lagged_15y.after.nindivs === null">-</div>
					<div v-bind:class="bg_even(idx)" v-else>{{ pheno.lagged_15y.after.nindivs }}</div>

					<div v-bind:class="bg_even(idx)">-</div>
				</template>
			</template>
		</div>
	</div>
</template>

<script>
import { concat, filter, partition, reverse, sortBy } from 'lodash-es';
import { drawCompBox } from './CompBox.js';
import HelpCompBox from './HelpCompBox.vue';


let compute_table = (col_filter, sort_by, sort_order, table) => {
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
	switch (sort_by) {
		case "before_hr":
			result = sortByNull(result, (pheno) => pheno.all.before.hr, sort_order);
			break;
		case "before_pvalue":
			result = sortByNull(result, (pheno) => pheno.all.before.pvalue, sort_order);
			break;
		case "before_nindivs":
			result = sortByNull(result, (pheno) => pheno.all.before.nindivs, sort_order);
			break;
		case "after_hr":
			result = sortByNull(result, (pheno) => pheno.all.after.hr, sort_order);
			break;
		case "after_pvalue":
			result = sortByNull(result, (pheno) => pheno.all.after.pvalue, sort_order);
			break;
		case "after_nindivs":
			result = sortByNull(result, (pheno) => pheno.all.after.nindivs, sort_order);
			break;
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
			sort_by: ["before_hr", "desc"],
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
		compBox(hr, hr_min, hr_max) {
			return drawCompBox(hr, hr_min, hr_max);
		},
		comp_table() {
			this.assoc_table = compute_table(
				this.pheno_filter,
				this.sort_by[0],
				this.sort_by[1],
				this.full_table
			)
		},
		sort_table(col) {
			if (this.sort_by[0] === col) {
				// reverse order
				if (this.sort_by[1] === "desc") {
					this.sort_by[1] = "asc";
				} else {
					this.sort_by[1] = "desc";
				}
			} else {
				// sort by new col, descending
				this.sort_by = [col, "desc"];
			}

			// Update the table
			this.comp_table();
		},
		symbol_sort(col) {
			if (this.sort_by[0] === col && this.sort_by[1] === "desc") {
				return  "▼";
			} else if (this.sort_by[0] === col && this.sort_by[1] === "asc") {
				return  "▲";
			} else {
				return "";
			}
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
			}
		}
	},
	created () {
		this.full_table = this.table;
		this.assoc_table = this.table;
		this.comp_table();
	}
}
</script>

<style type="text/css" scoped>
.assoc-grid {
    --width-table: 1200px;
    display: grid;
    grid-template-columns:
        calc(30 / 100 * var(--width-table))   /* Phenocode name */
        calc(15 / 100 * var(--width-table))   /* before: HR */
        calc( 7 / 100 * var(--width-table))   /* before: p */
        calc( 5 / 100 * var(--width-table))   /* before: N */
        calc( 5 / 100 * var(--width-table))   /* before: compBox */
        calc(16 / 100 * var(--width-table))   /* after: HR */
        calc( 6 / 100 * var(--width-table))   /* after: p */
        calc( 5 / 100 * var(--width-table))   /* after: N */
        calc( 6 / 100 * var(--width-table));  /* after: compBox */
}
.thead > div {
    @apply bg-grey-lightest;
}
.thead .before {
    grid-column: 2 / 6;
}
.thead .after {
    grid-column: 6 / 10;
}
.assoc-data {
    max-height: 500px;
    overflow: auto;
}
.thead .after, .thead .before {
    text-align: center;
}

.thead > div:nth-child(1),
.thead > div:nth-child(2),
.thead > div:nth-child(3) {
    @apply border-t-2;
}
.thead > div:nth-child(1),           /* header "before Phenocode" */
.thead > div:nth-child(2),           /* header "after Phenocode"  */
.thead > div:nth-child(3),           /* header "Phenocode"        */
.thead > div:nth-child(4),           /* header "HR" (before)      */
.thead > div:nth-child(8),           /* header "HR" (after)       */
.assoc-data div:nth-child(9n+1),     /* value "Phenocode"         */
.assoc-data div:nth-child(9n+2),     /* value "HR" (before)       */
.assoc-data div:nth-child(9n+6) {    /* value "HR" (after)        */
    @apply border-l-2;
}
.thead div:nth-child(3),
.thead div:nth-child(4),
.thead div:nth-child(5),
.thead div:nth-child(6),
.thead div:nth-child(7),
.thead div:nth-child(8),
.thead div:nth-child(9),
.thead div:nth-child(10),
.thead div:nth-child(11) {
    @apply border-b-2;
}
.thead div:nth-child(2),
.thead div:nth-child(11) {
    @apply border-r-2;
}

.assoc-grid div, .assoc-data div {
    @apply py-1;
}
.thead div:nth-child(1), .thead div:nth-child(2) {
	text-align: center;
}


/* interactive elements */
#assoc-table .col-interactive {
    cursor: pointer;
}
#assoc-table .col-interactive:hover {
    background-color: #e9e9e9;
}


.mini-button {
    box-shadow: 0 0 5px rgba(0, 0, 0, 0.5);
}
</style>
