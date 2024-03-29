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
import {search_channel, stats_data_channel} from "./socket";
import { forEach } from "lodash-es";
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


let getPlotInfo = (windowWidth) => {
    const
        maxWidth = 500,
        minWidth = 300,
        margin = 90,
        narrowScreen = 650,  // This is also defined in the CSS
        isMobile = windowWidth < narrowScreen;

    var res;

    if (isMobile) {
        res = Math.max(windowWidth, minWidth);  // TODO maybe sub a margin
        res = res - margin;
    } else {  // Computer view
        res = Math.min(
            windowWidth / 2,  // There are 2 plots on 1 line when in computer view
            maxWidth
        );
    }

    return {
        isMobile: isMobile,
        width: res
    }
};


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

    /* HISTOGRAMS */

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
                assoc_data: assoc_data["plot"]
            },
            components: { AssocPlot },
        });

        /* ASSOC TABLE */
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
