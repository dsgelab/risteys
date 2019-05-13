import Vue from 'vue';

// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import css from "../css/app.css"

// webpack automatically bundles all modules in your
// entry points. Those entry points can be configured
// in "webpack.config.js".
//
// Import dependencies
//
import "phoenix_html"

// Import local files
//
// Local files can be imported directly using relative paths, for example:
//// import slider_component from "./MySlider.vue"
import { accumulate, makeHistogram, putData } from "./plots.js";

import socket from "./socket"
import { search_channel } from "./socket"


var path = window.location.pathname


/*
 *  SEARCH
 */

Vue.component('risteys-search', {
    data: function() {
        return {
            searchvalue: '',
            selected: {
                category: null,
                item: null,
            },
            // Array indexes in the categories
            idx_name: 0,
            idx_items: 1,
        }
    },
    props: ['results'],
    methods: {
        acceptResult: function (event) {
            let result_url = this.results[this.selected.category][this.idx_items][this.selected.item].url;
            window.location = result_url;
        },
        ariaExpanded: function(event) {
            return this.results.length > 0;
        },
        classSelected: function (idx_category, idx_item) {
            let res = "";
            if (idx_category === this.selected.category && idx_item === this.selected.item) {
                res = "selected";
            }
            return res
        },
        genItemId: function (idx_category, idx_item) {
            return `item__${idx_category}_${idx_item}`
        },
        getItemIdSelected: function () {
            return this.genItemId(this.selected.category, this.selected.item)
        },
        nextResult: function (event) {
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
        previousResult: function (event) {
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
        kbdSearch: function (event) {
            switch (event.key) {
                case "ArrowDown":
                case "ArrowUp":
                    break;
                default:
                    this.search();
            }
        },
        search: function() {
            search_channel.push("query", {body: this.searchvalue});
            this.selected.category = 0;
            this.selected.item = 0;
        },
        setSearch: function (value) {
            var search_box = document.getElementById('home-search-input');
            search_box.focus();

            this.searchvalue = value;
            this.search();
        },
    },
    template: `
<div>
    <div class="outshadow"
         role="combobox"
         aria-label="search for anything on Risteys"
         aria-haspopup="grid"
         aria-owns="search-results"
         :aria-expanded="ariaExpanded() ? 'true' : 'false'">
      <input type="text"
             v-on:keydown.enter="acceptResult"
             v-on:keydown.down.prevent="nextResult"
             v-on:keydown.up.prevent="previousResult"
             v-on:keyup="kbdSearch"
             v-model="searchvalue"
             role="searchbox"
             aria-multiline="false"
             aria-autocomplete="list"
             aria-controls="search-results"
             :aria-activedescendant="getItemIdSelected()"
             placeholder="search for disease, ICD code, endpoint"
             class="inshadow text-xl font-mono p-3 w-full focus:mb-4"
             autofocus="autofocus"
             id="home-search-input"
             autocomplete="off">

      <div id="search-results" class="results" role="grid">
            <div class="category" v-for="(category, idx_category) in results">
                <div class="category-name">{{ category[idx_name] }}</div>
                <div :id="genItemId(idx_category, idx_item)"
                     :class="'item ' + classSelected(idx_category, idx_item)"
                     v-for="(item, idx_item) in category[idx_items]"
                     role="row">
                        <span class="font-mono" role="rowcell">
                            <a :href="item.url" v-html="item.phenocode"></a>
                        </span>
                        <span v-html="item.content"
                              class="pr-2 inline-block"
                              role="rowcell">
                        </span>
                </div>
            </div>
       </div>
    </div>

    <div id="home-examples">
      <p>Examples:</p>
      <ul>
        <li>Search for <a href="#" @click="setSearch('angina')" class="font-mono">angina</a> or <a href="#" @click="setSearch('L12')" class="font-mono">L12</a></li>
        <li>Get statistics for the <a href="/phenocode/I9_CARDMPRI" class="font-mono">I9_CARDMPRI</a> phenocode</li>
      </ul>
    </div>
</div>
`
})

search_channel.on("results", payload => {
    app.search_results = payload.body.results;
})



/*
 * VUE APP
 */
var app = new Vue({
    el: '#app',
    data: {
        search_results: '',
    },
})



/*
 * PLOTS
 */
makeHistogram("Event distribution by year",
    "year",
    "number of events",
    true,
    "plot_events_by_year",
    events_by_year);
makeHistogram("Age distribution",
    "age bracket",
    "number of events",
    false,
    "plot_bin_by_age",
    bin_by_age);


/*
 * HACKS
 */
// HACK(firefox): set the focus back to the home search box
let search_box = document.getElementById('home-search-input')
if (search_box !== null) {  // we may be on the home page wihtout the search box
    search_box.focus();
}
