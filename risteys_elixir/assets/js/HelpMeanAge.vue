<template>
	<HelpButton>
		<h4>Mean age at first event</h4>
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
					<th>FG1</th>
					<td>{{ phenocode }}</td>
					<td class="help-highlight">45</td>
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
					<th>FG2</th>
					<td>{{ phenocode }}</td>
					<td class="help-highlight">30</td>
				</tr>
				<tr style="border-bottom-width: 1px">
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
		<p>In this example the <b>mean age at first event is 37.5</b>.</p>
		<p>
			The mean age at first event for {{ phenocode }} is computed by:
			<ul>
				<li>selecting individuals having {{ phenocode }}: FG1 and FG2</li>
				<li>for these individuals, taking the age of their first event of {{ phenocode }}: 45 for FG1 and 30 for FG2</li>
				<li>computing the mean of these values</li>
			</ul>
			So the mean age at first event is Mean(45, 30) = 37.5.
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
