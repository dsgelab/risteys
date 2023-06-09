<template>
	<HelpButton>
		<h4>Median age at first event</h4>
        <p>Median age at the first occurrence of the endpoint.</p>
		<p>In the following example, persons 1 and 2 got EXAMPLE_ENDPOINT at ages 45 and 30, so the median age at first event would be 37.5.</p>
		<table>
			<thead>
				<tr>
					<th>Person ID</th>
					<th>Endpoint</th>
					<th>Age</th>
				</tr>
			</thead>
			<tbody>
				<tr>
					<th>1</th>
					<td>EXAMPLE_ENDPOINT</td>
					<td class="help-highlight">45</td>
				</tr>
				<tr style="color: grey">
					<th>1</th>
					<td>ENDPOINT_X</td>
					<td>46</td>
				</tr>
                <tr style="color: grey; border-bottom-width: 1px">
					<th>1</th>
					<td>ENDPOINT_Y</td>
					<td>46</td>
				</tr>
                <tr>
					<th>2</th>
					<td>EXAMPLE_ENDPOINT</td>
					<td class="help-highlight">30</td>
				</tr>
				<tr style="color: grey; border-bottom-width: 1px">
					<th>2</th>
					<td>ENDPOINT_Z</td>
					<td>47</td>
				</tr>
				<tr style="color: grey; border-bottom-width: 1px">
					<th>3</th>
					<td>ENDPOINT_X</td>
					<td>50</td>
				</tr>
			</tbody>
		</table>
		<p class= "mt-6">
			<b>FinRegistry index persons</b> refer to a subpopulation of the FinRegistry data that includes only persons alive and living in Finland on 1st of January, 2010.
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
