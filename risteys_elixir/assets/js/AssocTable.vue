<template>
	<table>
		<thead>
			<td>
				<b>Association</b><br>
				Phenocode happening
				<span class="border-2 cursor-pointer rounded hover:bg-grey-light" v-on:click="do_toggle_before()">
					<input
					type="checkbox"
					v-model="toggle_before"
					true-value="show"
					false-value="hide">■&nbsp;Before</span>
					/ <span class="border-2 cursor-pointer rounded hover:bg-grey-light" v-on:click="do_toggle_after()">
						<input
					type="checkbox"
					v-model="toggle_after"
					true-value="show"
					false-value="hide">□&nbsp;After</span> {{ phenocode }}<br>
				<input
					type="text"
					placeholder="filter by name"
					v-on:keyup.stop="comp_table"
					v-model="pheno_filter">
			</td>
			<td class="col-interactive" v-on:click="sort_table('hr')">{{ symbol_sort("hr") }} Hazard Ratio [95%&nbsp;CI]</td>
			<td class="col-interactive" v-on:click="sort_table('pvalue')">{{ symbol_sort("pvalue") }} p-value</td>
			<td class="col-interactive" v-on:click="sort_table('nindivs')">{{ symbol_sort("nindivs") }}
				<abbr data-title="Number of overlapping individuals">N.</abbr>
			</td>
		</thead>
		<tbody>
			<tr v-for="pheno in assoc_table">
				<td> <a :href="'/phenocode/' + pheno.name" :title="pheno.name">{{ pheno.longname }}</a><br>
					<span class="pl-4">happening {{ directionSymbol(pheno.direction) }}&nbsp;<i>{{ pheno.direction }}</i>&nbsp;{{ phenocode }}</span></td>
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
		do_toggle_before() {
			if (this.toggle_before === "show") {
				this.toggle_before = "hide";
			} else {
				this.toggle_before = "show";
			}
			this.comp_table();
		},
		do_toggle_after() {
			if (this.toggle_after === "show") {
				this.toggle_after = "hide";
			} else {
				this.toggle_after = "show";
			}
			this.comp_table();
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
