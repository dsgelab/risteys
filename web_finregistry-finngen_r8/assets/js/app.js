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
import InteractiveMortality from './InteractiveMortality.vue';
import CorrTable from './CorrTable.vue';
import AssocPlot from './AssocPlot.vue';
import AssocTable from './AssocTable.vue';
import DrugTable from './DrugTable.vue';
import SearchBox from './SearchBox.vue';

// Help buttons
import HelpButton from './HelpButton.vue';
import HelpNumberIndividuals from './HelpNumberIndividuals.vue';
import HelpPrevalence from './HelpPrevalence.vue';
import HelpMedianAge from './HelpMedianAge.vue';
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
    content.style.display = "none";
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
 * ENDPOINT PAGE
 */
if (path.startsWith("/endpoints/")) {  // Load only on endpoint pages

    let endpoint = path.split("/")[2];

    init_search_key();



    /* SEARCH BOX */
    var endpoint_search_results = new Vue({
        el: '#endpoint-searchbox',
        template: '<SearchBox v-bind:results="search_results"/>',
        data: {
            search_results: [],
        },
        components: { SearchBox }
    });
    search_channel.on("results", payload => {
        endpoint_search_results.search_results = payload.body.results;
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
        template: `<HelpMedianAge/>`,
        components: { HelpMedianAge },
    });
    var help_mortality = new Vue({
        el: '#help-mortality',
        template: `<HelpMortality/>`,
        components: { HelpMortality },
    });

    /* set colors for plots */
    /* from Tailwind color palettes (v0.7.4 (FG) & v3.0.23 (FR)) */
    const color_black = "#22292F"
    const color_blue_base = "#3490DC"
    const color_teal_500 = "#14b8a6"

    /* FinnGen results*/
    /* AGE HISTOGRAM FG */
    stats_data_channel.push("get_age_histogram", {endpoint: endpoint, dataset: "FG"});
    stats_data_channel.on("data_age_histogram_FG", payload => {
        const elementSelector = "#bin-plot-age-FG";
        const xAxisLabel = "Age";
        const yAxisLabel = "Individuals";
        const data = payload.data;
        const plot_color = color_black;
        varBinPlot(elementSelector, data, xAxisLabel, yAxisLabel, plot_color);
    });

    /* YEAR HISTOGRAM FG */
    stats_data_channel.push("get_year_histogram", {endpoint: endpoint, dataset: "FG"});
    stats_data_channel.on("data_year_histogram_FG", payload => {
        const elementSelector = "#bin-plot-year-FG";
        const xAxisLabel = "Year";
        const yAxisLabel = "Individuals";
        const data = payload.data;
        const plot_color = color_black;
        varBinPlot(elementSelector, data, xAxisLabel, yAxisLabel, plot_color);
    });

    /* CUMMULATIVE INCIDENCE FG */
    stats_data_channel.push("get_cumulative_incidence", {endpoint: endpoint, dataset: "FG"});  // request plot data
    stats_data_channel.on("data_cumulative_incidence_FG", payload => {
        const pattern_female = "1 0";
        const pattern_male = "9 1";
        const data = [
            {
                name: "female",
                color: color_blue_base,
                dasharray: pattern_female,
                cumulinc: payload.females,
                max_value: payload.max_value
            },
            {
                name: "male",
                color: color_black,
                dasharray: pattern_male,
                cumulinc: payload.males,
                max_value: payload.max_value
            }
        ];

        if (data[0].cumulinc.length === 0 && data[1].cumulinc.length === 0) {
            const node = document.getElementById("cumulinc-plot-FG");
            node.innerText = "No data";
        } else {
            drawPlotCumulInc("#cumulinc-plot-FG", data);
        }
    });

    /* CORRELATION TABLE */
    stats_data_channel.push("get_correlations", {endpoint: endpoint});
    stats_data_channel.on("data_correlations", payload => {
        var vv = new Vue({
            el: "#vue-correlations",
            data: {
                rows: payload.rows
            },
            components: { CorrTable },
        });
    });

    /* FinRegistry results*/
    stats_data_channel.push("test_exclusion", {endpoint: endpoint});
    stats_data_channel.on("result_exclusion", payload => {
        const excluded = payload.excl;

        /* Get results if endpoint is not excluded */
        if (excluded === null) {
            /* AGE HISTOGRAM FR */
            stats_data_channel.push("get_age_histogram", {endpoint: endpoint, dataset: "FR"});
            stats_data_channel.on("data_age_histogram_FR", payload => {
                const elementSelector = "#bin-plot-age-FR";
                const xAxisLabel = "Age";
                const yAxisLabel = "Individuals";
                const data = payload.data;
                const plot_color = color_teal_500;
                varBinPlot(elementSelector, data, xAxisLabel, yAxisLabel, plot_color);
            });

            /* YEAR HISTOGRAM FR */
            stats_data_channel.push("get_year_histogram", {endpoint: endpoint, dataset: "FR"});
            stats_data_channel.on("data_year_histogram_FR", payload => {
                const elementSelector = "#bin-plot-year-FR";
                const xAxisLabel = "Year";
                const yAxisLabel = "Individuals";
                const data = payload.data;
                const plot_color = color_teal_500;
                varBinPlot(elementSelector, data, xAxisLabel, yAxisLabel, plot_color);
            });


            /* CUMMULATIVE INCIDENCE FR */
            stats_data_channel.push("get_cumulative_incidence", {endpoint: endpoint, dataset: "FR"});  // request plot data
            stats_data_channel.on("data_cumulative_incidence_FR", payload => {
                const pattern_female = "1 0";
                const pattern_male = "9 1";
                const data = [
                    {
                        name: "female",
                        color: color_teal_500,
                        dasharray: pattern_female,
                        cumulinc: payload.females,
                        max_value: payload.max_value
                    },
                    {
                        name: "male",
                        color: color_black,
                        dasharray: pattern_male,
                        cumulinc: payload.males,
                        max_value: payload.max_value
                    }
                ];

                if (data[0].cumulinc.length === 0 && data[1].cumulinc.length === 0) {
                    const node = document.getElementById("cumulinc-plot-FR");
                    node.innerText = "No data";
                } else {
                    drawPlotCumulInc("#cumulinc-plot-FR", data);
                }
            });

            /* INTERACTIVE MORTALITY*/
            stats_data_channel.push("get_mortality", {endpoint: endpoint});
            stats_data_channel.on("data_mortality", payload => {
                new Vue({
                    el: '#vue-interactive-mortality',
                    data: {
                        mortality_data: payload.mortality_data
                    },
                    components: { InteractiveMortality }
                });
            });

            /* SURVIVAL ANALYSIS DATA */
            fetch('/api/endpoint/' + endpoint + '/assocs.json', {
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
            fetch('/api/endpoint/' + endpoint + '/drugs.json', {
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
    });
}
