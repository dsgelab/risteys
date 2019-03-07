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
import socket from "./socket"
import { search_channel } from "./socket"


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
        }
    },
    template: `
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
`
})


var searchapp = new Vue({
    el: '#app',
    data: {
        results: '',
    },
})

search_channel.on("results", payload => {
    searchapp.results = payload.body.results;
})


// HACK(firefox): set the focus back to the home search box
var search_box = document.getElementById('home-search-input')
search_box.focus()
