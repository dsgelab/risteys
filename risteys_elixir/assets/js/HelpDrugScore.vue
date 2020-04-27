<template>
	<HelpButton>
		<h4>Drug Score</h4>
		<p>Probability of getting the drug after <i>{{ phenocode }}</i> conditional on having <i>{{ phenocode }}</i>.</p>
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
