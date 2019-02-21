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
import { channel } from "./socket"


var app = new Vue({
    el: '#app',
    data: {
        message: '',
        searchvalue: '',
    },
    methods: {
        search: function (event) {
            channel.push("query", {body: this.searchvalue});
        }
    }
})

channel.on("result", payload => {
    console.log(payload.body);
    app.message = `${payload.body}`;
})
