<template>
	<div>
		<div class="sup-header">
			<span></span><span>Before {{ phenocode }}</span><span>After {{ phenocode }}</span>
		</div>
		<table>
			<thead>
				<tr>
					<th rowspan="2">
						Phenocode<br>
						<input
							type="text"
							placeholder="filter by name"
							v-on:keyup.stop="comp_table"  
							v-model="pheno_filter">
					</th>
					<th class="col-interactive" v-on:click="sort_table('before_hr')">{{ symbol_sort("before_hr") }} HR [95%&nbsp;CI]</th>
					<th class="col-interactive" v-on:click="sort_table('before_pvalue')">{{ symbol_sort("before_pvalue") }} p</th>
					<th class="col-interactive" v-on:click="sort_table('before_nindivs')">{{ symbol_sort("before_nindivs") }}
						<abbr data-title="Number of overlapping individuals">N</abbr>
					</th>
					<th class="col-interactive" v-on:click="sort_table('after_hr')">{{ symbol_sort("after_hr") }} HR [95%&nbsp;CI]</th>
					<th class="col-interactive" v-on:click="sort_table('after_pvalue')">{{ symbol_sort("after_pvalue") }} p</th>
					<th class="col-interactive" v-on:click="sort_table('after_nindivs')">{{ symbol_sort("after_nindivs") }}
						<abbr data-title="Number of overlapping individuals">N</abbr>
					</th>
				</tr>
			</thead>

			<tbody>
				<tr v-for="pheno in assoc_table">
					<th scope="row"><a :href="'/phenocode/' + pheno.name" :title="pheno.name">{{ pheno.longname }}</a></th>

					<td v-if="pheno.before.hr === null">N/A</td>
					<td v-else>{{ pheno.before.hr }}&nbsp;[{{ pheno.before.ci_min }},&nbsp;{{ pheno.before.ci_max }}]</td>

					<td v-if="pheno.before.pvalue === null">N/A</td>
					<td v-else>{{ pheno.before.pvalue_str }}</td>

					<td v-if="pheno.before.nindivs === null">N/A</td>
					<td v-else>{{ pheno.before.nindivs }}</td>

					<td v-if="pheno.after.hr === null">N/A</td>
					<td v-else>{{ pheno.after.hr }}&nbsp;[{{ pheno.after.ci_min }},&nbsp;{{ pheno.after.ci_max }}]</td>
					
					<td v-if="pheno.after.pvalue === null">N/A</td>
					<td v-else>{{ pheno.after.pvalue_str }}</td>
					
					<td v-if="pheno.after.nindivs === null">N/A</td>
					<td v-else>{{ pheno.after.nindivs }}</td>
				</tr>
			</tbody>
		</table>
	</div>
</template>

<script>
import { concat, filter, partition, reverse, sortBy } from 'lodash-es';

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
			result = sortByNull(result, (pheno) => pheno.before.hr, sort_order);
			break;
		case "before_pvalue":
			result = sortByNull(result, (pheno) => pheno.before.pvalue, sort_order);
			break;
		case "before_nindivs":
			result = sortByNull(result, (pheno) => pheno.before.nindivs, sort_order);
			break;
		case "after_hr":
			result = sortByNull(result, (pheno) => pheno.after.hr, sort_order);
			break;
		case "after_pvalue":
			result = sortByNull(result, (pheno) => pheno.after.pvalue, sort_order);
			break;
		case "after_nindivs":
			result = sortByNull(result, (pheno) => pheno.after.nindivs, sort_order);
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
		}
	},
	props: {
		table: Array,
		phenocode: String,
	},
	methods: {
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
	},
	created () {
		this.full_table = this.table;
		this.assoc_table = this.table;
		this.comp_table();
	}
}
</script>
