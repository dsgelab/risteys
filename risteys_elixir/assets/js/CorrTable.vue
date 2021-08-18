<template>
	<div role="table">

		<div role="rowgroup">
			<div role="row" class="grid-corr-header">
				<div role="columnheader" aria-colspan="2">
					<p>Correlated endpoint</p>
					<p>
						<input
							type="text"
							placeholder="filter by name"
							v-model="endpoint_filter"
							v-on:keyup.stop="refreshTable()"
							>
					</p>
				</div>
				<div role="columnheader">
					<p>Case-control overlap (%)</p>
					<p>
						<input type="radio" id="case_ratio_asc" value="case_ratio_asc" v-model="sorter" v-on:change="refreshTable()" checked><label for="case_ratio_asc" class="radio-left">▲</label><input type="radio" id="case_ratio_desc" value="case_ratio_desc" v-model="sorter" v-on:change="refreshTable()"><label for="case_ratio_desc" class="radio-right">▼</label>
					</p>
				</div>
				<div role="columnheader">
					<p>GWS hits</p>
					<p>
						<input type="radio" id="gws_hits_asc" value="gws_hits_asc" v-model="sorter" v-on:change="refreshTable()" checked><label for="gws_hits_asc" class="radio-left">▲</label><input type="radio" id="gws_hits_desc" value="gws_hits_desc" v-model="sorter" v-on:change="refreshTable()"><label for="gws_hits_desc" class="radio-right">▼</label>
					</p>
				</div>
				<div role="columnheader">
					<p>Coloc GWS hits (same&nbsp;dir)</p>
					<p>
						<input type="radio" id="coloc_gws_hits_same_dir_asc" value="coloc_gws_hits_same_dir_asc" v-model="sorter" v-on:change="refreshTable()" checked><label for="coloc_gws_hits_same_dir_asc" class="radio-left">▲</label><input type="radio" id="coloc_gws_hits_same_dir_desc" value="coloc_gws_hits_same_dir_desc" v-model="sorter" v-on:change="refreshTable()"><label for="coloc_gws_hits_same_dir_desc" class="radio-right">▼</label>
					</p>
				</div>
				<div role="columnheader">
					<p>Relative β with index</p>
					<p>
						<input type="radio" id="rel_beta_asc" value="rel_beta_asc" v-model="sorter" v-on:change="refreshTable()" checked><label for="rel_beta_asc" class="radio-left">▲</label><input type="radio" id="rel_beta_desc" value="rel_beta_desc" v-model="sorter" v-on:change="refreshTable()"><label for="rel_beta_desc" class="radio-right">▼</label>
					</p>
				</div>
				<div role="columnheader">
					<p>Coloc GWS hits (opp&nbsp;dir)</p>
					<p>
						<input type="radio" id="coloc_gws_hits_opp_dir_asc" value="coloc_gws_hits_opp_dir_asc" v-model="sorter" v-on:change="refreshTable()" checked><label for="coloc_gws_hits_opp_dir_asc" class="radio-left">▲</label><input type="radio" id="coloc_gws_hits_opp_dir_desc" value="coloc_gws_hits_opp_dir_desc" v-model="sorter" v-on:change="refreshTable()"><label for="coloc_gws_hits_opp_dir_desc" class="radio-right">▼</label>
					</p>
				</div>
			</div>
		</div>
		
		<div v-for="(corr, idx) in live_rows" role="rowgroup">
			<div
				role="row"
				v-bind:class="bg_class(idx) + ' grid-corr-body'"
			>
				<div role="cell">
					<a :href="'/phenocode/' + corr.name" :title="corr.name">
						{{ corr.name }}
					</a>
				</div>
				<div role="cell">
					<a :href="'/phenocode/' + corr.name" :title="corr.name">
						{{ corr.longname }}
					</a>
				</div>
				<div role="cell">{{ corr.case_ratio }}</div>
				<div role="cell">{{ corr.gws_hits }}</div>
				<div role="cell">
					<template v-if="corr.coloc_gws_hits_same_dir > 0">
						<a :href="'#dialog-corr-' + corr.name" :onclick="'openDialog(\'corr-' + corr.name + '\')'">{{ corr.coloc_gws_hits_same_dir }}</a>
					</template>
					<template v-else>
						{{ corr.coloc_gws_hits_same_dir }}
					</template>
				</div>
				<div role="cell">{{ corr.rel_beta }}</div>
				<div role="cell">{{ corr.coloc_gws_hits_opp_dir }}</div>
			</div>
		</div>

	</div>
</template>

<script>
import { filter, map, reverse, orderBy } from 'lodash-es';

function formatRow(row) {
	const case_ratio_perc = (row.case_ratio * 100).toFixed(2);
	const case_ratio = row.case_ratio === null ? "-" : case_ratio_perc;
	const gws_hits = row.gws_hits === null ? "-" : row.gws_hits;
	const coloc_gws_hits_same_dir = row.coloc_gws_hits_same_dir === null ? "-" : row.coloc_gws_hits_same_dir;
	const rel_beta = row.rel_beta === null ? "-" : row.rel_beta;
	const coloc_gws_hits_opp_dir = row.coloc_gws_hits_opp_dir === null ? "-" : row.coloc_gws_hits_opp_dir;
	return {
		name: row.name,
		longname: row.longname,
		case_ratio: case_ratio,
		gws_hits: gws_hits,
		coloc_gws_hits_same_dir: coloc_gws_hits_same_dir,
		rel_beta: rel_beta,
		coloc_gws_hits_opp_dir: coloc_gws_hits_opp_dir
	}
}

function computeTable(rows, endpoint_filter, sorter) {
	var computed_rows = rows;

	if (endpoint_filter !== "") {
		computed_rows = filter(
			rows,
			(row) => {
				const longname = row.longname === null ? "" : row.longname;  // some endpoint don't have a "longname"
				return row.name.toLowerCase().includes(endpoint_filter.toLowerCase())
					|| longname.toLowerCase().includes(endpoint_filter.toLowerCase())
			}
		)
	}

	switch (sorter) {
		// In the following we use `row.<col> || ""` to put null values at the bottom when using descending order
		case "case_ratio_desc":
			computed_rows = orderBy(computed_rows, [(row) => row.case_ratio || ""], ["desc"]);
			break;
		case "case_ratio_asc":
			computed_rows = orderBy(computed_rows, ["case_ratio"], ["asc"]);
			break;

		case "gws_hits_desc":
			computed_rows = orderBy(computed_rows, [(row) => row.gws_hits || ""], ["desc"]);
			break;
		case "gws_hits_asc":
			computed_rows = orderBy(computed_rows, ["gws_hits"], ["asc"]);
			break;

		case "coloc_gws_hits_same_dir_desc":
			computed_rows = orderBy(computed_rows, [(row) => row.coloc_gws_hits_same_dir || ""], ["desc"]);
			break;
		case "coloc_gws_hits_same_dir_asc":
			computed_rows = orderBy(computed_rows, ["coloc_gws_hits_same_dir"], ["asc"]);
			break;

		case "rel_beta_desc":
			computed_rows = orderBy(computed_rows, [(row) => row.rel_beta || ""], ["desc"]);
			break;
		case "rel_beta_asc":
			computed_rows = orderBy(computed_rows, ["rel_beta"], ["asc"]);
			break;

		case "coloc_gws_hits_opp_dir_desc":
			computed_rows = orderBy(computed_rows, [(row) => row.coloc_gws_hits_opp_dir || ""], ["desc"]);
			break;
		case "coloc_gws_hits_opp_dir_asc":
			computed_rows = orderBy(computed_rows, ["coloc_gws_hits_opp_dir"], ["asc"]);
			break;
	}

	return computed_rows
}

function displayTable(rows, endpoint_filter, sorter) {
	var res = computeTable(rows, endpoint_filter, sorter);
	res = map(res, formatRow);
	return res
}

export default {
	data() {
		return {
			sorter: "gws_hits_desc",
			endpoint_filter: "",
			live_rows: []
		};
	},
	props: {
		rows: Array
	},
	methods: {
		refreshTable() {
			this.live_rows = displayTable(this.rows, this.endpoint_filter, this.sorter);
		},
		bg_class(idx) {
			if (idx % 2 === 1) {
				return "bg-grey-lightest"
			} else {
				return "bg-white"
			}
		}
	},
	created() {
		this.live_rows = displayTable(this.rows, this.endpoint_filter, this.sorter);
	}
}
</script>

<style scoped>
	/* .scrolling is already defined elsewhere so using it will mess with this
   table layout */
.corr-scrolling {
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

[role="rowgroup"]:nth-child(1) {
	position: sticky;
	top: 0;
	background-color: #fafafa;
	border-top-width: 1px;
	border-bottom-width: 1px;

	font-weight: bold;
}

/* Grid table layout */
.grid-corr-header {
	display: grid;
	grid-template-columns: 9fr     2fr 2fr 2fr 2fr 2fr;  /* first column spans 2 body columns */
}
.grid-corr-body {
	display: grid;
	grid-template-columns: 3fr 6fr 2fr 2fr 2fr 2fr 2fr;
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
