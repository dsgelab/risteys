<template>
	<HelpButton>
		<h4>Case fatality at 5 years</h4>
		<p class="text-center">Using <b>example data</b>:</p>
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
					<td>EXAMPLE_ENDPOINT</td>
					<td>45</td>
				</tr>
				<tr style="color: grey">
					<th>FG1</th>
					<td>ENDPOINT_XYZ</td>
					<td>46</td>
				</tr>
				<tr style="color: grey; border-bottom-width: 1px" class="help-highlight">
					<th>FG1</th>
					<td>DEATH</td>
					<td>47</td>
				</tr>
				<tr>
					<th class="help-highlight">FG2</th>
					<td class="help-highlight">EXAMPLE_ENDPOINT</td>
					<td>30</td>
				</tr>
				<tr style="border-bottom-width: 1px">
					<th>FG2</th>
					<td>EXAMPLE_ENDPOINT</td>
					<td>30.1</td>
				</tr>
				<tr style="color: grey; border-bottom-width: 1px">
					<th>FG3</th>
					<td>ENDPOINT_XYZ</td>
					<td>50</td>
				</tr>
			</tbody>
		</table>
		<p>In this example the <b>case fatality at 5 years is 50%</b>.</p>
		<p>
			The case fatality at 5 years is computed by:
			<ul>
				<li>selecting individuals with EXAMPLE_ENDPOINT events:<br>FG1 and FG2.</li>
				<li>for each of them, checking if they have a DEATH event:<br>FG1 has this event.</li>
				<li>checking the number of individuals for which 5 years or less happened between the first event of EXAMPLE_ENDPOINT and the DEATH event:<br>only 1 (FG1, with 47 - 25 = 2 years between said events).</li>
			</ul>
			Here only 1 individual has less than 5 years between EXAMPLE_ENDPOINT and DEATH, and 2 individuals have EXAMPLE_ENDPOINT. The case fatality at 5 years is 1 / 2 = 50 %.
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
