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
import { search_channel, stats_channel } from "./socket"


var searchapp = new Vue({
    el: '#app',
    data: {
        results: '',
        searchvalue: '',
    },
    methods: {
        search: function (event) {
            search_channel.push("query", {body: this.searchvalue});
        }
    }
})

search_channel.on("results", payload => {
    searchapp.results = payload.body.results;
})



/*
*
*  CODE PAGE
*
*/

var codeapp = new Vue({
    el: '#interactive_stats',
    data: {
        stats: {
            profiles: [],
            metrics: [],
            table: [[1, 2, 3, 4], [5, 6, 7, 8]]
        },
    }
})

// Send initial request for data on page load
stats_channel.push("code", window.location.pathname, 1000)
  .receive("ok", (payload) => codeapp.stats = payload.body)
  .receive("error", (reasons) => console.log(reasons))
  .receive("timeout", () => console.log("timeout"))

// Listen on result update after a user interaction 
stats_channel.on("results", payload => {
    codeapp.stats = payload.body.results;
})
