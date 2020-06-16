<template>
	<HelpButton>
		<h4>Comparable box plot</h4>
		<p>
			This plot allows to compare the hazard ratio (HR) for a single survival analysis with the distribution of HRs across all the survival analyses for the same disease endpoint.
		</p>
		<img src="/images/compbox.svg">
		<p>
			This plot shows the distribution of normalized HR:
		</p>
		<ul>
			<li>light-grey zone: 95% of all HRs are within this interval</li>
			<li>grey zone: 50% of all HRs are within this interval</li>
			<li>dark vertical line: median of HRs</li>
			<li>black dot: HR for a specific survival analysis</li>
		</ul>
		<p>
			If our endpoint of interest is A and we are interested in the survival analysis of A → B (solid dot), we compute the distribution of HRs of type * → B. If the HR for A → B lies inside the distribution of HRs for * → B , this indicates a not too unsurprising association.
		</p>
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
p {
	margin-top: 0.5rem;
}
</style>
