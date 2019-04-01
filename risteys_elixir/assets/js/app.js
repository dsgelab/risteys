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
import VueSlider from 'vue-slider-component'
import 'vue-slider-component/theme/default.css'

import socket from "./socket"
import { search_channel, kf_channel } from "./socket"


var path = window.location.pathname


/*
 *  SEARCH
 */

Vue.component('risteys-search', {
    data: function() {
        return {
            searchvalue: ''
        }
    },
    props: ['results'],
    methods: {
        search: function (event) {
            search_channel.push("query", {body: this.searchvalue});
        },
        setSearch: function (value) {
            this.searchvalue = value;
            this.search();
        },
    },
    template: `
<div>
    <form class="outshadow">
      <input type="text" v-on:keyup="search" v-model="searchvalue" placeholder="search for disease, ICD code, endpoint"
         class="inshadow text-xl font-mono p-3 w-full focus:mb-4"
         autofocus="autofocus"
       id="home-search-input"
       autocomplete="off">
        <section class="results">
              <ul>
                <li v-for="item in results" class="leading-normal">
                  <a :href="item.url">
                    <span v-html="item.description"></span>
                  </a>
                  <div v-if="item.phenocode">Phenocode: <span v-html="item.phenocode" class="font-mono"></span></div>
                  <div v-if="item.icds">
                    ICD-10: <span v-for="icd in item.icds" v-html="icd" class="pr-2 inline-block font-mono"></span>
                  </div>
                </li>
              </ul>
        </section>
    </form>
    <div id="home-examples">
      <p>Examples:</p>
      <ul>
        <li>Search for <a href="#" @click="setSearch('cardio')" class="font-mono">cardio</a></li>
        <li>Get statistics for the <a href="/code/I9_ANGINA" class="font-mono">I9_ANGINA</a> phenocode</li>
        <li>Get statistics for the <a href="#TODO" class="font-mono">I25</a> ICD-10 code</li>
      </ul>
    </div>
</div>
`
})

search_channel.on("results", payload => {
    app.search_results = payload.body.results;
})


/*
 * KEY FIGURES
 */

Vue.component('key-figures', {
    props: ['table', 'filters'],
    template: `
    <div class="flex">
        <kf-table :table="table"></kf-table>
        <kf-filters :filters="filters" class="flex-grow"></kf-filters>
    </div>
    `
})

// TABLE
Vue.component('kf-table', {
    props: ['table'],
    // TODO prevalence
    template: `
    <div>
        <h3>Key figures</h3>
        <table class="key-figures table-fixed flex-initial mr-4">
            <tbody>
                <tr>
                    <td>Sex</td>
                    <td>Number of events</td>
                    <td>Prevalence (%)</td>
                    <td>Mean age after baseline (years)</td>
                </tr>
                <tr>
                    <td>All</td>
                    <td>{{ table.all.nevents }}</td>
                    <td>{{ table.all.nevents / 1000 }}</td>
                    <td>{{ Math.floor(table.all.mean_age) }}</td>
                </tr>
                <tr>
                    <td>Male</td>
                    <td>{{ table.male.nevents }}</td>
                    <td>{{ table.male.nevents / 1000 }}</td>
                    <td>{{ Math.floor(table.male.mean_age) }}</td>
                </tr>
                <tr>
                    <td>Female</td>
                    <td>{{ table.female.nevents }}</td>
                    <td>{{ table.female.nevents / 1000 }}</td>
                    <td>{{ Math.floor(table.female.mean_age) }}</td>
                </tr>
            </tbody>
        </table>

        <h3>Clinical metrics</h3>
        <table class="key-figures table-fixed flex-initial mr-4">
            <tbody>
                <tr>
                    <td>Sex</td>
                    <td>Re-hospitalization rate (%)</td>
                    <td>Case fatality (%)</td>
                </tr>
                <tr>
                    <td>All</td>
                    <td>{{ (table.all.rehosp * 100).toFixed(3) }}</td>
                    <td>{{ (table.all.case_fatality * 100).toFixed(3) }}</td>
                </tr>
                <tr>
                    <td>Male</td>
                    <td>{{ (table.male.rehosp * 100).toFixed(3) }}</td>
                    <td>{{ (table.male.case_fatality * 100).toFixed(3) }}</td>
                </tr>
                <tr>
                    <td>Female</td>
                    <td>{{ (table.female.rehosp * 100).toFixed(3)  }}</td>
                    <td>{{ (table.female.case_fatality * 100).toFixed(3) }}</td>
                </tr>
            </tbody>
        </table>
    </div>
   `
})

// FILTERS
Vue.component('kf-filters', {
    props: ['filters'],
    methods: {
        filterOut: function(event) {
            kf_channel.push("filter_out", {body: {path: path, filters: this.filters}})
            .receive("ok", (payload) => {
                app.key_figures.table = payload.body.results;
            });
        },
    },
    template: `
        <div>
            <div class="flex">
                <div>Age</div>
                <vue-slider
                    v-model="filters.age"
                    @change="filterOut"
                    :min="25"
                    :max="70"
                    :duration="0"
                    :height="8"
                    :tooltip="'always'"
                    :useKeyboard="true"
                    :lazy="false"
                    class="flex-grow">
                </vue-slider>
            </div>
        </div>
    `
})

// AGE SLIDER
Vue.component('VueSlider', VueSlider)
//// Vue.component('kf-age-slider', slider_component)


// Send request to get the initial_data for the given code
kf_channel.push("initial_data", {body: path})
    .receive("ok", (payload) => {
        app.key_figures.table = payload.body.results;
    })

/*
 * VUE APP
 */
var app = new Vue({
    el: '#app',
    data: {
        search_results: '',
        key_figures: {
            table: {
                all: {
                    nevents: 0,
                    mean_age: 0,
                },
                male: {
                    nevents: 0,
                    mean_age: 0,
                },
                female: {
                    nevents: 0,
                    mean_age: 0,
                },
            },
            filters: {
                age: [25, 70],
            }
        }
    },
})


// HACK(firefox): set the focus back to the home search box
var search_box = document.getElementById('home-search-input')
search_box.focus()
