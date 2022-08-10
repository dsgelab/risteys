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
					<p>Case overlap (%)</p>
					<p>
						<input type="radio" id="case_overlap_asc" value="case_overlap_asc" v-model="sorter" v-on:change="refreshTable()" checked><label for="case_overlap_asc" class="radio-left">▲</label><input type="radio" id="case_overlap_desc" value="case_overlap_desc" v-model="sorter" v-on:change="refreshTable()"><label for="case_overlap_desc" class="radio-right">▼</label>
					</p>
				</div>
				<div role="columnheader">
					<p>GWS hits</p>
					<p>
						<input type="radio" id="gws_hits_asc" value="gws_hits_asc" v-model="sorter" v-on:change="refreshTable()" checked><label for="gws_hits_asc" class="radio-left">▲</label><input type="radio" id="gws_hits_desc" value="gws_hits_desc" v-model="sorter" v-on:change="refreshTable()"><label for="gws_hits_desc" class="radio-right">▼</label>
					</p>
				</div>
				<div role="columnheader">
					<p>Coloc GWS hits</p>
					<p>
						<input type="radio" id="coloc_gws_hits_asc" value="coloc_gws_hits_asc" v-model="sorter" v-on:change="refreshTable()" checked><label for="coloc_gws_hits_asc" class="radio-left">▲</label><input type="radio" id="coloc_gws_hits_desc" value="coloc_gws_hits_desc" v-model="sorter" v-on:change="refreshTable()"><label for="coloc_gws_hits_desc" class="radio-right">▼</label>
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
					<a :href="'/endpoints/' + corr.name" :title="corr.name">
						{{ corr.name }}
					</a>
				</div>
				<div role="cell">
					<a :href="'/endpoints/' + corr.name" :title="corr.name">
						{{ corr.longname }}
					</a>
				</div>
				<div role="cell">{{ corr.case_overlap }}</div>
				<div role="cell">{{ corr.gws_hits }}</div>
				<div role="cell">
					<template v-if="corr.coloc_gws_hits > 0">
						<a :href="'#dialog-corr-' + corr.name" v-on:click="openDialogAuthz(corr.name)">{{ corr.coloc_gws_hits }}</a>
					</template>
					<template v-else>
						{{ corr.coloc_gws_hits }}
					</template>
				</div>
			</div>
		</div>

	</div>
</template>

<script>
import { filter, map, reverse, orderBy } from 'lodash-es';

function formatRow(row) {
	const case_overlap_perc = (row.case_overlap * 100).toFixed(2);
	const case_overlap = row.case_overlap === null ? "-" : case_overlap_perc;
	const gws_hits = row.gws_hits === null ? "-" : row.gws_hits;
	const coloc_gws_hits = row.coloc_gws_hits === null ? "-" : row.coloc_gws_hits;
	return {
		name: row.name,
		longname: row.longname,
		case_overlap: case_overlap,
		gws_hits: gws_hits,
		coloc_gws_hits: coloc_gws_hits,
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
		case "case_overlap_desc":
			computed_rows = orderBy(computed_rows, [(row) => row.case_overlap || ""], ["desc"]);
			break;
		case "case_overlap_asc":
			computed_rows = orderBy(computed_rows, ["case_overlap"], ["asc"]);
			break;

		case "gws_hits_desc":
			computed_rows = orderBy(computed_rows, [(row) => row.gws_hits || ""], ["desc"]);
			break;
		case "gws_hits_asc":
			computed_rows = orderBy(computed_rows, ["gws_hits"], ["asc"]);
			break;

		case "coloc_gws_hits_desc":
			computed_rows = orderBy(computed_rows, [(row) => row.coloc_gws_hits || ""], ["desc"]);
			break;
		case "coloc_gws_hits_asc":
			computed_rows = orderBy(computed_rows, ["coloc_gws_hits"], ["asc"]);
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
			sorter: "case_overlap_desc",
			endpoint_filter: "",
			live_rows: []
		};
	},
	props: {
		rows: Array,
		authz: Boolean,
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
		},
		openDialogAuthz(corrName) {
			const dialogIdCorr = 'corr-' + corrName;
			const dialogIdAuthn = 'user-authn';

			if (this.authz) {
				openDialog(dialogIdCorr);
			} else {
				openDialog(dialogIdAuthn);
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
	grid-template-columns: 9fr     2fr 2fr 2fr;  /* first column spans 2 body columns */
}
.grid-corr-body {
	display: grid;
	grid-template-columns: 3fr 6fr 2fr 2fr 2fr;
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
