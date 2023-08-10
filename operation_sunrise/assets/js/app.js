// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"


/*
 * Hooks: Phoenix <--> JS
 */
let Hooks = {}

/*
 * Risteys
 */
import { drawCompBox } from './CompBox.js';

/* Draw CompBoxes
 *
 * For them to allways appear we would need to:
 * 1. draw when the static HTML is rendered by Phoenix
 * 2. draw on LiveView 'mounted'
 * 3. draw on LiveView 'updated'
 *
 * However, we don't do (1.) here because the initial static render is intentionally rendering
 * 0 elements to prevent blocking the initial page render (it takes ~ 5s to render).
 * So instead we just do (2.) and (3.)
 */
function replaceWithCompBox(element) {
    // The element MUST have a 'data-compbox-value'
    const value = element.dataset.compboxValue
    element.innerHTML = drawCompBox(value)
}

Hooks.DrawCompBox = {
    mounted() {
        replaceWithCompBox(this.el)
    },
    updated() {
        replaceWithCompBox(this.el)
    }
}

/*
 * UTILS
 */
function init_search_key () {
    document.addEventListener('keyup', (event) => {
        if (event.key === "s") {
            let search_box = document.getElementById('search-input');
            search_box.focus();
        }
    })
}

init_search_key()


/***********
 * Phoenix *
 **********/
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}, hooks: Hooks})

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket
