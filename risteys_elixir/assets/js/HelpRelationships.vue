<template>
	<HelpButton>
        <section>
            <article>
                <h3>Case overlap:</h3>
                <p>
                    The overlap between the endpoint cases is shown for the whole FinRegistry (FR) data and FinnGen (FG) data.
                    Please note, that these values are independent of the shown analysis results.
                    The first (upper) value shows the <b>number of cases</b> having both endpoints. The second (lower) value shows the <b>Jaccard index</b>:
                    (intersect of cases, i.e. the number of individuals having both endpoints) /
                    (union of cases, i.e. the number of individuals having one or both of the endpoints) * 100.

                </p>
            </article>
            <article>
                <h3> Survival analysis: </h3>
                <p>
                    <b>Hazard ratios (HR)</b> with 95% confidence intervals are shown for cases in the FinRegistry
                    data where the onset of the selected endpoint occurred first.
                    Results with statistically significant Bonferroni corrected p-values are indicated by *.
                    See <a href="/documentation/#methods-relationships">Documentation</a> for details.
                </p>

                <div class="mt-2">
                    <p>
                        <b> Extremity</b> box plot compares the hazard ratio (HR) for a single survival analysis
                        with the distribution of HRs across all the survival analyses for the same disease endpoint.
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
                </div>
            </article>

            <article>
                <h3> Genetic correlations: </h3>
                <p>
                    <b>rg</b> shows the <a href="https://finngen.gitbook.io/finngen-analyst-handbook/finngen-data-specifics/green-library-data-aggregate-data/core-analysis-results-files/pairwise-endpoint-genetic-correlation-format" target="_blank" rel="noopener noreferrer external">
                    pairwise genetic correlation</a> between the endpoints in FinnGen together with
                    95% confidence intervals. Genetic correlations are truncated to be between 1.0 and -1.0.
                    Results with statistically significant p-values (threshold 1x10<sup class="small-font">-6</sup>) are indicated by *.
                    <b>Extremity</b> box plot compares the genetic correlation (rg) for a single genetic correlation analysis with
                    the distribution of rg's across all the genetic correlation analyses for the same disease endpoint.
                </p>
            </article>

            <article>
                <h3> Genetic signals: </h3>
                <p>
                    <b>Hits</b> show the number of genome-wide significant hits and <b>Coloc hits</b> show
                    the colocal genome-wide significant hits between the endpoints in the FinnGen data.
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

.small-font {
    font-size: 0.7rem;
}
</style>
