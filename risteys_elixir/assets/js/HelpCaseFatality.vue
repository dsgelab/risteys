<template>
	<HelpButton>
		<h4>Case fatality at 5 years</h4>
		<table>
			<thead>
				<tr>
					<th>ID</th>
					<th>age</th>
					<th>phenocode</th>
				</tr>
			</thead>
			<tbody>
				<tr class="help-highlight">
					<th>FG1</th>
					<td>45</td>
					<td>{{ phenocode }}</td>
				</tr>
				<tr style="color: grey">
					<th>FG1</th>
					<td>55</td>
					<td>XYZ_ENDPOINT</td>
				</tr>
				<tr style="color: grey; border-bottom-width: 1px" class="help-highlight">
					<th>FG1</th>
					<td>47</td>
					<td>DEATH</td>
				</tr>
				<tr>
					<th class="help-highlight">FG2</th>
					<td>30</td>
					<td class="help-highlight">{{ phenocode }}</td>
				</tr>
				<tr style="border-bottom-width: 1px">
					<th>FG2</th>
					<td>30.1</td>
					<td>{{ phenocode }}</td>
				</tr>
				<tr style="color: grey; border-bottom-width: 1px">
					<th>FG3</th>
					<td>50</td>
					<td>XYZ_ENDPOINT</td>
				</tr>
			</tbody>
		</table>
		<p>In this example the <b>case fatality at 5 years is 50%</b>.</p>
		<p>
			The case fatality at 5 years is computed by:
			<ul>
				<li>selecting individuals with {{ phenocode }} events:<br>FG1 and FG2.</li>
				<li>for each of them, checking if they have a DEATH event:<br>FG1 has this event.</li>
				<li>checking the number of individuals for which 5 years or less happened between the first event of {{ phenocode }} and the DEATH event:<br>only 1 (FG1, with 47 - 25 = 2 years between said events).</li>
			</ul>
			Here only 1 individual has less than 5 years between {{ phenocode }} and DEATH, and 2 individuals have {{ phenocode }}. The case fatality at 5 years is 1 / 2 = 50 %.
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
