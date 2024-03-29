<template>
	<div role="combobox"
		 aria-label="search for anything on Risteys"
		 aria-haspopup="grid"
		 aria-owns="search-results"
		 :aria-expanded="ariaExpanded() ? 'true' : 'false'"
		 class="outshadow">
		<input type="text"
			   v-on:keydown.enter.prevent="acceptResult"
			   v-on:keydown.down.prevent="nextResult"
			   v-on:keydown.up.prevent="previousResult"
			   v-on:keyup="kbdSearch"
			   v-bind:value="searchvalue"
			   v-on:input="searchvalue = $event.target.value"
			   role="searchbox"
			   aria-multiline="false"
			   aria-autocomplete="list"
			   aria-controls="search-results"
			   :aria-activedescendant="getItemIdSelected()"
			   placeholder="click or type 's' to search for disease, ICD code, endpoint"
			   id="search-input"
			   autocomplete="off">

		<div id="search-results" class="results" role="grid">
			<div class="category" v-for="(category, idx_category) in results">
				<div class="category-name">{{ category[idx_name] }}</div>
				<div :id="genItemId(idx_category, idx_item)"
					 :class="'item ' + classSelected(idx_category, idx_item)"
					 v-for="(item, idx_item) in category[idx_items]"
					 role="row">
						<span class="font-mono" role="rowcell">
							<a :href="item.url" v-html="item.endpoint"></a>
						</span>
						<span v-html="item.content"
							  class="pr-2 inline-block"
							  role="rowcell">
						</span>
				</div>
			</div>
		</div>
	</div>
</template>

<style>
div[role="combobox"] {
	color: black;
	@apply text-left;
}

.outshadow:focus-within {
    box-shadow: 0 0 30px rgba(0, 0, 0, 0.15);
}

div[role="combobox"] > input {
    box-shadow: inset 0 0 15px rgba(0, 0, 0, 0.1);
	@apply p-3;
    @apply w-full;

    @apply border-2;
    @apply border-grey;
}

div[role="combobox"] > input:focus {
    box-shadow: none;
    @apply border-blue-dark;
}

.results {
	position: relative;
	@apply bg-grey-lightest;
}

.results .category {
	@apply p-2;
}

.results .category:nth-child(n + 2) .category-name {
    @apply mt-4;
}
.results .item {
    @apply py-2;
    display: grid;
    grid-template-columns: 250px auto;
}
.results .item > span:nth-child(1) {
    @apply pr-2;
    overflow-wrap: break-word;
}
.results .item.selected {
    @apply bg-grey-light;
}

.results .category-name {
    @apply uppercase;
    @apply bg-grey-lighter;
    @apply py-2;
}
</style>

<script>
import { search_channel } from "./socket";

export default {
   data () {
		return {
			searchvalue: "",
			selected: {
				category: null,
				item: null,
			},
			// Array indexes in the categories
			idx_name: 0,
			idx_items: 1,
		}
	},
	props: {
		results: {
			type: Array,
			default: function () {
				return []
			}
		},
		example: {
			type: String,
			default: ""
		}
	},
	watch: {
		example (value) {
			this.searchvalue = value;
			this.search();
		}
	},
	methods: {
		acceptResult (event) {
			let result_url = this.results[this.selected.category][this.idx_items][this.selected.item].url;
			window.location = result_url;
		},
		ariaExpanded (event) {
			return this.results.length > 0;
		},
		classSelected (idx_category, idx_item) {
			let res = "";
			if (idx_category === this.selected.category && idx_item === this.selected.item) {
				res = "selected";
			}
			return res
		},
		genItemId (idx_category, idx_item) {
			return `item__${idx_category}_${idx_item}`
		},
		getItemIdSelected () {
			return this.genItemId(this.selected.category, this.selected.item)
		},
		nextResult (event) {
			if (this.results.length > 0) {
				let ncategories = this.results.length;
				if (this.selected.category === null) {
					// If nothing selected yet, then select first element
					this.selected.category = 0;
					this.selected.item = 0;
				} else {
					// Already a selection, just go down.
					let nitems = this.results[this.selected.category][this.idx_items].length;
					if (this.selected.item === nitems - 1) {  // on last item
						if (this.selected.category < ncategories - 1) {  // there are more categories
							this.selected.category += 1;
							this.selected.item = 0;
						}
					} else {
						this.selected.item += 1;
					}
				}
			}
		},
		previousResult (event) {
			if (this.results.length > 0) {  // there are some results
				let ncategories = this.results.length;
				if (this.selected.category === null) {  // no selection yet
					let category = ncategories - 1;
					this.selected.category = category;

					let nitems = this.results[category][this.idx_items].length;
					this.selected.item = nitems - 1;
				} else {  // already a selection
					if (this.selected.item === 0) {  // first item of the category
						if (this.selected.category > 0) {  // can go one category up
							let category = this.selected.category - 1;
							this.selected.category = category;

							let nitems = this.results[category][this.idx_items].length;
							this.selected.item = nitems - 1;  // last item of the category
						}
					} else {  // not the first item of the category
						this.selected.item -= 1;
					}
				}
			}
		},
		kbdSearch (event) {
			switch (event.key) {
				case "ArrowDown":
				case "ArrowUp":
					break;
				default:
					this.search();
			}
		},
		search () {
			search_channel.push("query", {body: this.searchvalue});
			this.selected.category = 0;
			this.selected.item = 0;
		},
	},
}
</script>
