<template>
	<HelpButton>
		<article>
			<h3>Follow-up</h3>
			<p>Amount of time to look for the endpoint since entering the study. This is either either 1, 5, 15 years or the full study time from 1998 to 2019.</p>
		</article>

		<article>
			<h3>Absolute risk</h3>
			<p>Estimates the probability of dying from the current endpoint. Check the <a href="/methods/#mortality-absolute-risk">Methods page for Mortality: absolute risk</a> to get more details.</p>
		</article>

		<article>
			<h3>Hazard Ratio (HR) and 95% Confidence Interval (CI)</h3>
			<p>Measures how much the risk of dying increases (HR&nbsp;&gt;&nbsp;1) or decreases (HR&nbsp;&lt;&nbsp;1).</p>
		</article>

		<article>
			<h3>Number of individuals (N)</h3>
			<p>Number of individuals having the current endpoint and died during the follow-up time.</p>
		</article>
	</HelpButton>
</template>

<script>
import HelpButton from './HelpButton.vue';

export default {
	data () {
		return {};
	},
	props: {
		phenocode: String,
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
