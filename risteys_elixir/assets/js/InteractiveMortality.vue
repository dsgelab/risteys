<template>
	<div class="grid-1fr-1fr">
		<div>
			<p class="pt-6 pb-6"> Association between endpoint <span class="italic"> {{ this.mortality_data.name}} </span> and mortality:</p>
			<table class="horizontal pb-6">
				<thead>
					<tr>
						<th>Parameter </th>
						<th>HR [95% CI]</th>
						<th>p-value</th>
					</tr>
				</thead>
				<tbody>
					<tr class="font-bold">
						<td> {{ this.mortality_data.name}} </td>
						<td>
							{{ Math.exp(this.mortality_data.exposure.coef).toFixed(3) }}
							[{{ Math.exp(this.mortality_data.exposure.ci95_lower).toFixed(2)}},
							{{ Math.exp(this.mortality_data.exposure.ci95_upper).toFixed(2)}}]
						</td>
						<td>
							{{ show_p(this.mortality_data.exposure.p_value)}}
						</td>
					</tr>
					<tr>
						<td> Sex </td>
						<td>
							{{ Math.exp(this.mortality_data.sex.coef).toFixed(3) }}
							[{{ Math.exp(this.mortality_data.sex.ci95_lower).toFixed(2)}},
							{{ Math.exp(this.mortality_data.sex.ci95_upper).toFixed(2)}}]
						</td>
						<td>
							{{ show_p(this.mortality_data.sex.p_value)}}
						</td>
					</tr>
					<tr>
						<td> Birth Year </td>
						<td>
							{{ Math.exp(this.mortality_data.birth_year.coef).toFixed(3) }}
							[{{ Math.exp(this.mortality_data.birth_year.ci95_lower).toFixed(2)}},
							{{ Math.exp(this.mortality_data.birth_year.ci95_upper).toFixed(2)}}]
						</td>
						<td>
							{{ show_p(this.mortality_data.birth_year.p_value)}}
						</td>
					</tr>
				</tbody>
			</table>
			<!--<p class="pt-6 pb-6">
				XXX out of XXX (XXX %) individuals with <span class="italic"> {{ this.mortality_data.name}} </span> died between 1998 and 2019.
			</p>-->
		</div>
		<div>
			<p class="pt-6 pb-6 leading-loose">
				<span id="help-mortality"></span>
				Compute absolute risk for a
				<select
					v-model="sex"
					v-on:change="compute_AR(sex, age)"
				>
					<option value="female"> Female</option>
					<option value="male"> Male</option>
				</select>

				of age

				<select
					v-model="age"
					v-on:change="compute_AR(sex, age)"
				>
					<!-- v-for="(item, index) in items" syntax to start the range for age choices from 0-->
					<option v-for="(item, age) in 101" :value=age> {{ age }} </option>
				</select>

				years, who has
				<span class="italic"> {{ this.mortality_data.longname }} ({{ this.mortality_data.name}})</span>.
			</p>
			<table class="horizontal mb-6">
				<thead>
					<tr>
						<th>N-year risk</th>
						<th>Absolute risk (%)</th>
					</tr>
				</thead>
				<tbody>
					<tr>
						<td> 0-1</td>
						<td> {{ this.AR[0] }}  </td>
					</tr>
					<tr>
						<td> 0-5</td>
						<td> {{ this.AR[1] }} </td>
					</tr>
					<tr>
						<td> 0-10</td>
						<td> {{ this.AR[2] }} </td>
					</tr>
					<tr>
						<td> 0-15</td>
						<td> {{ this.AR[3] }}</td>
					</tr>
					<tr>
						<td> 0-20</td>
						<td> {{ this.AR[4] }}</td>
					</tr>
				</tbody>
			</table>
		</div>
	</div>
</template>

<script>

export default {
	data () {
		return {
            sex: "female",
            age: 50,
            AR: [],
			bchMap: new Map(Object.entries(this.mortality_data.bch))
        };
	},

	props: {
		mortality_data: Object,
	},

    methods: {
		show_p (value){
			if(value < 0.001) {
				return "< 0.001"
			} else {
				return value.toFixed(3);
			}
		},

    	/*function to compute AR */
        compute_AR () {

			let n_year = [1,5,10,15,20];

			/* Compute absolute risk for each follow-up time using baseline hazard, age, sex, and birth year */
			for(let i = 0; i < n_year.length; i ++) {
				this.AR[i] = (1 - this.compute_S(this.age + n_year[i]) / this.compute_S(this.age)) * 100

				if(this.AR[i] < 0.001) {
					this.AR[i] = "< 0.001";
				} else if(this.AR[i] > 95) {
					this.AR[i] = "> 95";
				} else {
					this.AR[i] = this.AR[i].toFixed(3);
				}
			}
        },

		compute_S (t) {
			let sex_value = 1
			if(this.sex == "male") {
				sex_value = 0
			};

			let birth_year = 2022 - this.age

			/* S(t) = exp(-baseline_cumulative_hazard(t) * exp(coef_sex * (sex - mean_sex)
			+ coef_birth_year * (birth_year - mean_birth_year)
			+ coef_exposure * (exposure - mean_exposure)) */

			return Math.exp(-this.get_bch(t) * Math.exp(
				this.mortality_data.sex.coef * (sex_value - this.mortality_data.sex.mean)
				+ this.mortality_data.birth_year.coef * (birth_year - this.mortality_data.birth_year.mean)
				+ this.mortality_data.exposure.coef * (1 - this.mortality_data.exposure.mean)))

		},

		get_bch (age) {
			return this.bchMap.get(age.toString())
		}
    },

    created() {
        this.compute_AR();
    }
}
</script>


