<template>
	<div class="help-widget">
		<div class="help-button" v-on:click="toggleDisplay()">?</div>
		<div class="help-content" v-bind:style="getDisplay()">
			<button class="help-close button-out" v-on:click="hide()">X</button>
			<slot></slot>
		</div>
	</div>
</template>

<style>
.help-widget {
    position: relative;
    display: inline-block;
}
.help-content {
    /* positioning */
    position: absolute;
    top: 2rem;
    background: white;
    z-index: 1;

    /* reset style due to .help-button */
    font-weight: initial;
    text-align: initial;
    cursor: initial;

    /* box styling */
    @apply px-4;
    @apply py-2;
    min-width: 700px;
    @apply shadow-lg;
    @apply border;
}
.help-content table {
    @apply my-3;

    margin-left: auto;
    margin-right: auto;
}
.help-content table th {
    font-style: normal;
}
.help-highlight {
    background-color: #d33c8e44;
}
.help-close {
    float: right;
    cursor: pointer;
}
</style>

<script>
export default {
	data () {
		return {
			show: false,
		}
	},
	methods: {
		getDisplay () {
			if (this.show) {
				return "display: unset";
			} else {
				return "display: none";
			}
		},
		hide () {
			this.show = false;
		},
		toggleDisplay () {
			this.show = !this.show;
		}
	}
}
</script>
