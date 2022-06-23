<template>
	<div class="grid-2fr-3fr">
		<div>
			<h3 class="pt-3"> Association</h3>
			<p> Association between endpoint <span class="italic"> {{ this.mortality_data.name}} </span> and mortality:</p>
			<div v-for="sex in sexes">
				<h4 class="pt-6 italic">{{ make_sex_title(sex) }}</h4>
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
							<td> {{ template_mortality_data.name }} </td>
							<td>
								{{ get_HR_and_CIs(
									template_mortality_data[sex].exposure.coef,
									template_mortality_data[sex].exposure.ci95_lower,
									template_mortality_data[sex].exposure.ci95_upper
									)
								}}
							</td>
							<td>
								{{ show_p(template_mortality_data[sex].exposure.p_value)}}
							</td>
						</tr>

						<tr>
							<td> Birth Year </td>
							<td>
								{{ get_HR_and_CIs(
									template_mortality_data[sex].birth_year.coef,
									template_mortality_data[sex].birth_year.ci95_lower,
									template_mortality_data[sex].birth_year.ci95_upper
									)
								}}
							</td>
							<td>
								{{ show_p(template_mortality_data[sex].birth_year.p_value)}}
							</td>
						</tr>
					</tbody>
				</table>
			</div>
			<!--<p class="pt-6 pb-6">
				XXX out of XXX (XXX %) individuals with <span class="italic"> {{ this.mortality_data.name}} </span> died between 1998 and 2019.
			</p>-->
		</div>
		<div>
			<h3 class="pt-3"> Mortality risk</h3>
			<p class="pb-6 leading-loose">
				<span id="help-mortality"></span>
				Mortality risk for people of age

				<select
					v-model="age"
					v-on:change="get_AR()"
				>
					<!-- v-for="(item, index) in items" syntax to start the range for age choices from 0-->
					<option v-for="(item, age) in 101" :value=age> {{ age }} </option>
				</select>

				years, who have
				<span class="italic"> {{ this.mortality_data.longname }} ({{ this.mortality_data.name}})</span>.
			</p>
			<table class="horizontal mb-6">
				<thead>
					<tr>
						<th>N-year risk</th>
						<th>Females</th>
						<th>Males</th>
					</tr>
				</thead>
				<tbody>
					<tr v-for="(item, index) in follow_up_times">
						<td> {{ item }} </td>
						<td> {{ AR_females[index] }}  </td>
						<td> {{ AR_males[index] }}  </td>
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
            sexes: ["female", "male"],
			age: 50,
			follow_up_times: [1, 5, 10, 15, 20],
            AR_females: [],
			AR_males: [],
			/* this.mortality_data is assigned as data value to access the data from template, otherwise undefined.
			different name for mortality_data is used to avoid warning about already declared property (mortality_data cannot be removed from props).
			"The data property "mortality_data" is already declared as a prop. Use prop default value instead." */
			template_mortality_data: this.mortality_data
        };
	},

	props: {
		mortality_data: Object // if missing: Property or method "mortality_data" is not defined on the instance but referenced during render.
	},

    methods: {
		make_sex_title(sex){
			sex = sex + "s"
			sex = sex.replace(/^\w/, (c) => c.toUpperCase()); /* capitalize first letter */
			return sex
		},

		show_p (value){
			if(value == null) {
				return "no data"
			} else if (value < 0.001) {
				return "<" + String.fromCharCode(160) + "0.001" // Non-breakable space is char 160
			} else {
				return value.toFixed(3);
			}
		},

		/* get mortality risk (absolute risk) for females and males*/
		get_AR () {
			this.AR_females = this.compute_AR("female")
			this.AR_males = this.compute_AR("male")
		},

    	/*function to compute AR */
        compute_AR (sex) {
			let n_year = [1,5,10,15,20];
			let AR = []

			/* Compute mortality risk (absolute risk) for each follow-up time using baseline hazard, age, sex, and birth year */
			for(let i = 0; i < n_year.length; i ++) {

				AR[i] = (1 - this.compute_S(this.age + n_year[i], sex) / this.compute_S(this.age, sex)) * 100

				if (isNaN(AR[i])) { // some of the input values is not available
					AR[i] = "no data";
				} else if(AR[i] < 0.001) {
					AR[i] = "<" + String.fromCharCode(160) + "0.001%"; // Non-breakable space is char 160
				} else if(AR[i] > 95) {
					AR[i] = ">" + String.fromCharCode(160) + "95%";
				} else {
					AR[i] = AR[i].toFixed(3) + "%";
				}
			}
			return AR;
        },

		compute_S (t, sex) {

			let birth_year = 2022 - this.age

			/* S(t) = exp(-baseline_cumulative_hazard(t) * exp(
			coef_birth_year * (birth_year - mean_birth_year)
			+ coef_exposure * (exposure - mean_exposure))

			where baseline_cumulative_hazard(t) is sex-specific
			*/

			let bch = this.get_bch(t, sex)

			/* handle missing values.
			calculate S only if all input values are found,
			otherwise null's are considered as 0, resulting to incorrect results */
			if(
				bch != null &
				this.mortality_data[sex].birth_year.coef != null &
				this.mortality_data[sex].birth_year.mean != null &
				this.mortality_data[sex].exposure.coef != null &
				this.mortality_data[sex].exposure.mean != null
			){
				return Math.exp(-bch * Math.exp(
					this.mortality_data[sex].birth_year.coef * (birth_year - this.mortality_data[sex].birth_year.mean)
					+ this.mortality_data[sex].exposure.coef * (1 - this.mortality_data[sex].exposure.mean)))
			} else {
				return undefined // this will make result of AR computation to NaN, which can be handled
			}
		},

		get_bch (age, sex) {
			/* age need to be converted to float to match keys in the map */
			age = age.toFixed(1)

			/* use try...catch to handle missing data (null values) that throw TypeError*/
			try {
				return this.mortality_data[sex].bch[age]
			} catch (error) {
				return null
			}
		},

		get_HR_and_CIs (hr, ci_lower, ci_upper) {
			if(hr != null & ci_lower != null & ci_upper != null) {
				return this.get_exp(hr, 3) + " [" + this.get_exp(ci_lower, 2) + ", " + this.get_exp(ci_upper, 2) + "]"
			} else {
				return "no data"
			}
		},

		get_exp (value, decimal) {
			/* return exp of the value, rounded to given precision and converted to string */
			return Math.exp(value).toFixed(decimal)
		}
    },

    created() {
        this.get_AR();
    }
}
</script>
