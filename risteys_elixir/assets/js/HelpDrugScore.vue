<template>
	<HelpButton>
		<h4>Drug Score</h4>
		<p>The drug score is computed in a 2-step process:</p>
		<ol>
			<li>Fit the data to the logistic model:<br>
				<span class="font-mono">y ~ sex + year-of-birth + year-of-birth^2 + year-at-endpoint + year-at-endpoint^2</span><br>
			</li>
			<li>Use the fitted model to predict the probability for the following data:
				<ul>
					<li><span class="font-mono">sex = 0.5</span>, assume an even number of females and males.</li>
					<li><span class="font-mono">year-of-birth = 1960</span>, the mean year of birth of the FinnGen cohort.</li>
					<li><span class="font-mono">year-at-endpoint = 2018</span>, predict the probability at the end of the study.</li>
				</ul>
			</li>
		</ol>
		<p>The resulting probability value is the drug score. The highest the drug score is, the stronger the drug is associated with the endpoint.</p>
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
