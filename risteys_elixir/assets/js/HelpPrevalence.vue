<template>
	<HelpButton>
		<h4>Unadjusted prevalence</h4>
		<table>
			<thead>
				<tr>
					<th>ID</th>
					<th>phenocode</th>
					<th>age</th>
				</tr>
			</thead>
			<tbody>
				<tr>
					<th class="help-highlight">FG1</th>
					<td>{{ phenocode }}</td>
					<td>45</td>
				</tr>
				<tr style="color: grey">
					<th>FG1</th>
					<td>XYZ_ENDPOINT</td>
					<td>55</td>
				</tr>
				<tr style="color: grey; border-bottom-width: 1px">
					<th>FG1</th>
					<td>DEATH</td>
					<td>47</td>
				</tr>
				<tr>
					<th class="help-highlight">FG2</th>
					<td>{{ phenocode }}</td>
					<td>30</td>
				</tr>
				<tr style="border-bottom-width: 1px">
					<th class="help-highlight">FG2</th>
					<td>{{ phenocode }}</td>
					<td>30.1</td>
				</tr>
				<tr style="color: grey; border-bottom-width: 1px">
					<th>FG3</th>
					<td>XYZ_ENDPOINT</td>
					<td>50</td>
				</tr>
			</tbody>
		</table>
		<p>In this example the <b>unadjusted prevalence is 66 %</b>.</p>
		<p>The unadjusted prevalence is the number of individuals having an endpoint divided by the total number of individuals.</p>
		<p>Here:
		<ul>
			<li>2 unique individuals (FG1 and FG2) have {{ phenocode }} events</li>
			<li>1 individual (FG3) has no {{ phenocode }} event</li>
		</ul>
		So the unadjusted prevalence is 2 / 3 = 66 %.</p>
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
