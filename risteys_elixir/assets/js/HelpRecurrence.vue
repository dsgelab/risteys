<template>
	<HelpButton>
		<h4>Recurrence within 6 months</h4>
		<table>
			<thead>
				<tr>
					<th>ID</th>
					<th>phenocode</th>
					<th>age</th>
				</tr>
			</thead>
			<tbody>
				<tr class="help-highlight">
					<th>FG1</th>
					<td>{{ phenocode }}</td>
					<td>45</td>
				</tr>
				<tr style="color: grey">
					<th>FG1</th>
					<td>XYZ_ENDPOINT</td>
					<td>46</td>
				</tr>
				<tr style="color: grey; border-bottom-width: 1px">
					<th>FG1</th>
					<td>DEATH</td>
					<td>47</td>
				</tr>
				<tr>
					<th class="help-highlight">FG2</th>
					<td class="help-highlight">{{ phenocode }}</td>
					<td class="help-highlight">30</td>
				</tr>
				<tr style="border-bottom-width: 1px" class="help-highlight">
					<th>FG2</th>
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
		<p>In this example the <b>recurrence within 6 months is 50 %</b>.</p>
		<p>
			The recurrence within 6 months is computed by:
			<ul>
				<li>selecting individuals with {{ phenocode }}:<br>FG1, FG2, so <b>2</b> individuals in total.</li>
				<li>for each of them, checking if they have 2 events of {{ phenocode }} less than 6 months apart:
					<ul>
						<li>FG1 has only 1 event of {{ phenocode }} so FG1 is discarded.</li>
						<li>FG2 has 2 events of {{ phenocode }} less than 6 months apart (one at age 30 and the other at age 30.1).</li>
					</ul>
				</li>
				<li>counting the number of individuals with events less than 6 months apart:<br><b>1</b> in this case (FG2)</li>
			</ul>
			Here the recurrence within 6 months is 1 / 2 = 50 %.
		</p>
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
