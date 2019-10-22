<template>
	<HelpButton>
		<h4>Number of individuals</h4>
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
		<p>In this example the <b>number of individuals is 2</b>, since only 2 unique individuals (FG1 and FG2) have {{ phenocode }} events.</p>
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
