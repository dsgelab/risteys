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
import {openDialog, closeDialog} from "./dialog.js";
import {search_channel, stats_data_channel} from "./socket";
import {plot as varBinPlot} from "./varBinPlot";
import {drawPlot as drawPlotCumulInc} from "./cumulincPlot";
import {forEach} from "lodash-es";
import CorrTable from './CorrTable.vue';
import AssocPlot from './AssocPlot.vue';
import AssocTable from './AssocTable.vue';
import DrugTable from './DrugTable.vue';
import SearchBox from './SearchBox.vue';

// Help buttons
import HelpButton from './HelpButton.vue';
import HelpNumberIndividuals from './HelpNumberIndividuals.vue';
import HelpPrevalence from './HelpPrevalence.vue';
import HelpMeanAge from './HelpMeanAge.vue';
import HelpMortality from './HelpMortality.vue';


var path = window.location.pathname;

/*
 * GLOBALS
 *
 * Functions needed when calling from HTML.
 * By default webpack would get rid of them, we must attach them to "window" to make them available.
 */
window.openDialog = openDialog;
window.closeDialog = closeDialog;


/*
 * UTILS
 */

let init_search_key = () => {
    document.addEventListener('keyup', (event) => {
        if (event.key === "s") {
            let search_box = document.getElementById('search-input');
            search_box.focus();
        }
    })
};

let showHelpContent = (elem) => {
    // Select content div
    let content = elem.querySelector(".help-content");
    // Toggle display
    content.style.display = "unset";
};
/* Attach listener to open help windows */
let helps = document.querySelectorAll(".help-button");
forEach(helps, (elem) => elem.addEventListener("click", () => showHelpContent(elem)));

let hideHelpContent = (closeButton) => {
    let content = closeButton.parentElement;
    console.log(content);
    content.style.display = "none";
    console.log(content);
}
/* Attach listener to close help windows */
let closeButtons = document.querySelectorAll(".help-close");
forEach(closeButtons, (elem) => elem.addEventListener("click", () => hideHelpContent(elem)));


/* ≡ MOBILE MENU */
let elNav = document.getElementById("nav-narrow");
if (elNav !== null) {  // we are a page with the Nav button
    let elToggle = document.getElementById("toggle-nav-menu");
    let displayNav = false;  // initial state: hidden
    elToggle.addEventListener('click', event => {
        displayNav = !displayNav;

        if (displayNav) {
            elNav.style.display = "unset";
        } else {
            elNav.style.display = "none";
        }
    });
}



/*
 *  HOME PAGE
 */
if (path === "/") {
    /* SEARCH */
    var app_search_results = new Vue({
        el: '#app-search-results',
        template: '<SearchBox class="frontpage" v-bind:results="search_results"/>',
        data: {
            search_results: [],
        },
        components: { SearchBox }
    });

    search_channel.on("results", payload => {
        app_search_results.search_results = payload.body.results;
    });

    init_search_key();

    // HACK(firefox): set the focus back to the home search box
    let search_box = document.getElementById('search-input');
    if (search_box !== null) {  // we may be on the home page wihtout the search box
        search_box.focus();
    }

}


/*
 * PHENOCODE PAGE
 */
if (path.startsWith("/phenocode/")) {  // Load only on phenocode pages

    let phenocode = path.split("/")[2];

    init_search_key();



    /* SEARCH BOX */
    var pheno_search_results = new Vue({
        el: '#pheno-searchbox',
        template: '<SearchBox v-bind:results="search_results"/>',
        data: {
            search_results: [],
        },
        components: { SearchBox }
    });
    search_channel.on("results", payload => {
        pheno_search_results.search_results = payload.body.results;
    });

    /* HELP BUTTONS */
    var help_button_nindivs = new Vue({
        el: '#help-button-nindivs',
        template: `<HelpNumberIndividuals/>`,
        components: { HelpNumberIndividuals },
    });
    var help_button_prevalence = new Vue({
        el: '#help-button-prevalence',
        template: `<HelpPrevalence/>`,
        components: { HelpPrevalence },
    });
    var help_button_mean_age = new Vue({
        el: '#help-button-mean-age',
        template: `<HelpMeanAge/>`,
        components: { HelpMeanAge },
    });
    var help_mortality = new Vue({
        el: '#help-mortality',
        template: `<HelpMortality/>`,
        components: { HelpMortality },
    });

    /* AGE HISTOGRAM */
    stats_data_channel.push("get_age_histogram", {endpoint: phenocode});
    stats_data_channel.on("data_age_histogram", payload => {
        const elementSelector = "#bin-plot-age";
        const xAxisLabel = "age";
        const yAxisLabel = "individuals";
        const data = payload.data;
        varBinPlot(elementSelector, data, xAxisLabel, yAxisLabel);
    });

    /* YEAR HISTOGRAM */
    stats_data_channel.push("get_year_histogram", {endpoint: phenocode});
    stats_data_channel.on("data_year_histogram", payload => {
        const elementSelector = "#bin-plot-year";
        const xAxisLabel = "year";
        const yAxisLabel = "individuals";
        const data = payload.data;
        varBinPlot(elementSelector, data, xAxisLabel, yAxisLabel);
    });

    /* CORRELATION TABLE */
    stats_data_channel.push("get_correlations", {endpoint: phenocode});
    stats_data_channel.on("data_correlations", payload => {
        var vv = new Vue({
            el: "#vue-correlations",
            data: {
                rows: payload.rows
            },
            components: { CorrTable },
        });
    });

    /* CUMMULATIVE INCIDENCE */
    stats_data_channel.push("get_cumulative_incidence", {endpoint: phenocode});  // request plot data
    stats_data_channel.on("data_cumulative_incidence", payload => {
        const color_female = "#9f0065";
        const color_male = "#2779bd";
        const pattern_female = "1 0";
        const pattern_male = "9 1";
        const data = [
            {
                name: "female",
                color: color_female,
                dasharray: pattern_female,
                cumulinc: payload.females
            },
            {
                name: "male",
                color: color_male,
                dasharray: pattern_male,
                cumulinc: payload.males
            }
        ];

        if (data[0].cumulinc.length === 0 && data[1].cumulinc.length === 0) {
            const node = document.getElementById("cumulinc-plot");
            node.innerText = "No data";
        } else {
            drawPlotCumulInc("#cumulinc-plot", data);
        }
    });


    /* SURVIVAL ANALYSIS DATA */
    fetch('/api/phenocode/' + phenocode + '/assocs.json', {
        cache: 'default',
        mode: 'same-origin'
    }).then((response) => {
        return response.json();
    }).then((assoc_data) => {
        /* SURVIVAL ANALYSIS PLOT */
        new Vue({
            el: '#assoc-plot',
            data: {
                assoc_data: assoc_data["plot"]
            },
            components: { AssocPlot },
        });

        /* SURVIVAL ANALYSIS TABLE */
        new Vue({
            el: '#assoc-table',
            data: {
                assoc_data: assoc_data["table"]
            },
            components: { AssocTable },
        });
    });


    /* DRUG TABLE */
    fetch('/api/phenocode/' + phenocode + '/drugs.json', {
        cache: 'default',
        mode: 'same-origin'
    }).then((response) => {
        return response.json();
    }).then((drug_data) => {
        new Vue({
            el: '#drug-table',
            data: {
                drug_data: drug_data
            },
            components: { DrugTable },
        });
    });
}
