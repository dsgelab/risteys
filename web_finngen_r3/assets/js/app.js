import Vue from 'vue';

// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import css from "../css/app.css";

// webpack automatically bundles all modules in your
// entry points. Those entry points can be configured
// in "webpack.config.js".
//
// Import dependencies
//
import "phoenix_html";

// Import local files
//
// Local files can be imported directly using relative paths, for example:
//// import slider_component from "./MySlider.vue"
import {makeHistogram, toggleCumulative} from "./plots.js";
import AssocPlot from './AssocPlot.vue';
import AssocTable from './AssocTable.vue';
import Search from './Search.vue';
import {search_channel} from "./socket";


var path = window.location.pathname;


/*
 *  HOME PAGE
 */

/* SEARCH */
if (path === "/") {
    var app_search_results = new Vue({
        el: '#app-search-results',
        template: '<Search v-bind:results="search_results"/>',
        data: {
            search_results: [],
        },
        components: { Search }
    });

    search_channel.on("results", payload => {
        app_search_results.search_results = payload.body.results;
    });
}


/*
 * PHENOCODE PAGE
 */
if (path.startsWith("/phenocode/")) {  // Load only on phenocode pages

    let phenocode = path.split("/")[2];

    /* HISTOGRAMS */
    makeHistogram("Year distribution",
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

    let button = document.getElementById("toggle_year_cumulative");
    button.addEventListener('click', event => {
        toggleCumulative("plot_events_by_year", true);
    });

    /* ASSOC DATA */
    fetch('/api/phenocode/' + phenocode + '/assocs.json', {
        cache: 'default',
        mode: 'same-origin'
    }).then((response) => {
        return response.json();
    }).then((assoc_data) => {
        /* ASSOC PLOT */
        new Vue({
            el: '#assoc-plot',
            data: {
                assoc_data: assoc_data
            },
            components: { AssocPlot },
        });

        /* ASSOC TABLE */
        new Vue({
            el: '#assoc-table',
            data: {
                assoc_data: assoc_data
            },
            components: { AssocTable },
        });
    });

}

/*
 * HACKS
 */
// HACK(firefox): set the focus back to the home search box
let search_box = document.getElementById('home-search-input')
if (search_box !== null) {  // we may be on the home page wihtout the search box
    search_box.focus();
}
