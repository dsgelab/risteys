<template>
	<HelpButton>
		<h4>Median number of events per individual</h4>
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
				<tr>
					<th class="help-highlight">FG1</th>
					<td class="help-highlight">EXAMPLE_ENDPOINT</td>
					<td>45</td>
				</tr>
				<tr style="color: grey">
					<th>FG1</th>
					<td>ENDPOINT_XYZ</td>
					<td>46</td>
				</tr>
				<tr style="color: grey; border-bottom-width: 1px">
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
					<th class="help-highlight">FG2</th>
					<td class="help-highlight">EXAMPLE_ENDPOINT</td>
					<td>30.1</td>
				</tr>
				<tr style="color: grey; border-bottom-width: 1px">
					<th>FG3</th>
					<td>ENDPOINT_XYZ</td>
					<td>50</td>
				</tr>
			</tbody>
		</table>
		<p>In this example the <b>median number of events is 1.5</b>.</p>
		<p>
			The median number of events is computed by:
			<ul>
				<li>selecting individuals with EXAMPLE_ENDPOINT:<br>FG1, FG2</li>
				<li>counting the number of EXAMPLE_ENDPOINT events for each of these individuals:
					<ul>
						<li>1 event for FG1</li>
						<li>2 events for FG2</li>
					</ul>
				</li>
				<li>computing the median of these values.</li>
			</ul>
			Here the median number of events per individual is Median(1, 2) = 1.5.
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
