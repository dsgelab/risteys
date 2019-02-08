import Vue from 'vue';
import './styles.css';

var app = new Vue({
    el: '#app',
    data: {
	message: '',
	searchvalue: '',
    },
    methods: {
	search: function (event) {
	    console.log("current search: " + this.searchvalue);
	    ws.send(this.searchvalue);
	}
    }
})

var ws = new WebSocket(webSocketUri);

ws.onmessage = function (event) {
  app.message = JSON.parse(event.data);
};
