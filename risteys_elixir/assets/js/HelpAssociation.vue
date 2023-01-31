<template>
	<HelpButton>
        <section>
            <h3> Association analyses </h3>
            <article>
                <h3> Endpoint </h3>
                <p> The table shows associations between the selected endpoint and other endpoints,from cases where the onset of the selected endpoint occured first</p>
            </article>
            <article>
                <h3>Comparable box plot </h3>
                <p>
                    This plot allows to compare the hazard ratio (HR) for a single survival analysis with the distribution of HRs across all the survival analyses for the same disease endpoint.
                </p>
                <img src="/images/compbox.svg">
                <p>
                    This plot shows the distribution of binned HRs:
                </p>
                <ul>
                    <li>X axis: percentile distribution of HRs, from 0 to 1.</li>
                    <li>light-grey zone: 95% of all HRs are within this interval</li>
                    <li>grey zone: 50% of all HRs are within this interval</li>
                    <li>dark vertical line: median of HRs</li>
                    <li>black dot: HR for a specific survival analysis</li>
                </ul>
                <p>
                    If our endpoint of interest is A and we are interested in the survival analysis of A → B (solid dot), we compute the distribution of HRs of type * → B. If the HR for A → B lies inside the distribution of HRs for * → B , this indicates a not too unsurprising association.
                </p>
            </article>

        </section>
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


