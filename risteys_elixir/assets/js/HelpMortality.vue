<template>
	<HelpButton>
		<article>
			<h3>Hazard ratios</h3>
			<p>Measures the association between a covariate and the risk of death. Hazard ratios greater than 1 indicate that the covariate is associated with an increased risk of death whereas hazard ratios smaller than 1 indicate the opposite. Hazard ratios are presented with 95 % confidence intervals and p-values.</p>
		</article>

		<article>
			<h3>Absolute risk</h3>
			<p>Estimates the N-year risk of death for a person of a specific age having the endpoint. See <a href="/documentation/#mortality">Documentation</a> for more details.</p>
		</article>
	</HelpButton>
</template>

<script>
import HelpButton from './HelpButton.vue';

export default {
	data () {
		return {};
	},
	components: {
		HelpButton
	}
}
</script>

<style type="text/css" scoped>
* {
	font-size: 1rem;
}

p:last-child {
	margin-bottom: 1rem;
}
</style>
