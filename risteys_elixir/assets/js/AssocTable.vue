<template>
	<table>
		<thead>
			<td>
				<input
					type="checkbox"
					v-model="toggle_before"
					true-value="show"
					false-value="hide"
					v-on:change="comp_table">&nbsp;Before&nbsp;■<br>
				<input
					type="checkbox"
					v-model="toggle_after"
					true-value="show"
					false-value="hide"
					v-on:change="comp_table">&nbsp;After&nbsp;□
			</td>
			<td>
				Phenocode<br>
				<input
					type="text"
					placeholder="filter by name"
					v-on:keyup="comp_table"  
					v-model="pheno_filter">
			</td>
			<td class="col-interactive" v-on:click="sort_table('hr')">{{ symbol_sort("hr") }} Hazard Ratio [95%&nbsp;CI]</td>
			<td class="col-interactive" v-on:click="sort_table('pvalue')">{{ symbol_sort("pvalue") }} p-value</td>
			<td class="col-interactive" v-on:click="sort_table('nindivs')">{{ symbol_sort("nindivs") }}
				<abbr data-title="Number of individuals having this prior->later association">N.&nbsp;individuals</abbr>
			</td>
		</thead>
		<tbody>
			<tr v-for="pheno in assoc_table">
				<td>
					<span :title="pheno.longname + ' ' + pheno.direction + ' ' + phenocode">
						{{ directionSymbol(pheno.direction) }}
					</span>
				</td>
				<td><a :href="'/phenocode/' + pheno.name" :title="pheno.name">{{ pheno.longname }}</a></td>
				<td>{{ pheno.hr }}&nbsp;[{{ pheno.ci_min }},&nbsp;{{ pheno.ci_max }}]</td>
				<td>{{ pheno.pvalue_str }}</td>
				<td>{{ pheno.nindivs }}</td>
			</tr>
		</tbody>
	</table>
</template>

<script>
import { filter, reverse, sortBy } from 'lodash-es';

let compute_table = (col_filter, show_before, show_after, sort_by, sort_order, table) => {
	let result;

	// Filter rows
	if (col_filter === "" && show_before && show_after) {
		result = table;
	} else {
		result = filter(
			table,
			(pheno) => {
				let match_name = pheno.name.toLowerCase().includes(col_filter.toLowerCase())
				|| pheno.longname.toLowerCase().includes(col_filter.toLowerCase());

				let match_direction;
				if (show_after && show_before) {  // show all, no filtering
					match_direction = true;
				} else if (show_after) {
					match_direction = pheno.direction === "after";
				} else if (show_before) {
					match_direction = pheno.direction === "before";
				} else {  // no selection, show nothing
					match_direction = false;
				}

				return match_name && match_direction;
			}
		);
	}

	// Sort rows
	switch (sort_by) {
		case "hr":
			result = sortBy(result, (pheno) => pheno.hr);
			break;
		case "pvalue":
			result = sortBy(result, (pheno) => pheno.pvalue_num);
			break;
		case "nindivs":
			result = sortBy(result, (pheno) => pheno.nindivs);
			break;
	}
	if (sort_order === "desc") {
		result = reverse(result);
	}

	return result
};


export default {
	data () {
		return {
			full_table: [],  // keep a copy of the original
			assoc_table: [],
			pheno_filter: "",
			sort_by: ["hr", "desc"],
			toggle_after: "show",
			toggle_before: "show",
		}
	},
	props: {
		table: Array,
		phenocode: String,
	},
	methods: {
		comp_table() {
			console.log("TTTTEST")
			let show_before = this.toggle_before === "show";
			let show_after = this.toggle_after === "show";
			this.assoc_table = compute_table(
				this.pheno_filter,
				show_before,
				show_after,
				this.sort_by[0],
				this.sort_by[1],
				this.full_table
			)
		},
		directionSymbol (dir) {
			if (dir === "after") {
				return "□"
			} else if (dir === "before") {
				return "■"
			}
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
	}
}
</script>
