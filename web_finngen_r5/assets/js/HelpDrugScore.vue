<template>
	<HelpButton>
		<h4>Drug Score</h4>
		<p>Probability of getting the drug after <i>{{ phenocode }}</i> conditional on not having this drug before <i>{{ phenocode }}</i>.</p>
		<p>See <i>Drug Statistics</i> on the <a href="/methods#drug-stats">Methods page</a> for more information.</p>
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
