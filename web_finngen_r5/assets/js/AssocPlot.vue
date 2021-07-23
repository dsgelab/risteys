<template>
	<div>
		<p class="mb-2">Y:
			<input type="radio" id="pvalue" value="pvalue" v-model="y_axis" checked><label v-on:click="set_yaxis('pvalue')" for="pvalue" class="radio-left">p-value</label><input type="radio" id="hr" value="hr" v-model="y_axis"><label v-on:click="set_yaxis('hr')" for="hr" class="radio-right">HR</label>
		</p>
		<div id="d3-assoc-plot"></div>
	</div>
</template>

<script>
import * as d3 from "d3";
import { drop, filter, flatten, groupBy, map, mapValues, reverse, sortBy, take } from "lodash-es";


// Layout, data independent
let margin = {
		labelX: 120,
		labelY: 20,
		axisX: 40,
		axisY: 40,
		right: 10,  // extra blank space, otherwise it cuts some dots
	},
	plotWidth = 1000,
	plotHeight = 300;

let width = margin.labelY + margin.axisY + plotWidth + margin.right;
let height = margin.labelX + margin.axisX + plotHeight;

let tooltipMargin = {
	x: 20,
};

// Style
let dot = {
	opacity: 0.8,
	size: 5,
};
let square = {
	opacity: 0.8,
	size: 9,
}

// Category colormap
let nCategories = 18;
let colormap = [
	"#4e98e1",
	"#9f0065",
	"#cecece"  // p-value >= 0.05
]

/* Group data by category, name the top 7, order by number of associations. */
let dataPlot = (data) => {
	let groups = groupBy(data, (d) => d.category);
	let sorted = sortBy(groups, (assocs) => assocs.length);
	let reversed = reverse(sorted);  // now biggest groups first

	let topCategories = take(reversed, nCategories);

	// Compute X axis ticks, one per category
	let topCategoriesSizes = map(topCategories, "length");
	let xAxisTicks = [0];
	let sum = 0;
	for (const size of topCategoriesSizes) {
		sum += size;
		xAxisTicks.push(sum);
	}

	// Get category names
	let categoryNames = map(topCategories, (assocs) => {
		let name = assocs[0].category;
		if (name.length < 50) {
			return name;
		} else {
			return name.substr(0, 50) + "…";
		}
	});
	categoryNames.push("Other");

	// Assign different category for Top7
	for (const [index, assocs] of topCategories.entries()) {
		map(assocs, (assoc) => {
			assoc.categoryColor = index % 2;  // alternate between two colors
			return assoc;
		})
	}
	topCategories = flatten(topCategories);

	// Put every other associations in a single category
	let other = drop(reversed, nCategories);
	other = flatten(other);
	other = map(other, (assoc) => {
		assoc.categoryColor = nCategories % 2;  // alternate color after last category
		return assoc;
	})

	return {
		ticks: xAxisTicks,
		categoryNames: categoryNames,
		data: topCategories.concat(other),
	};
};

let toPlotSpace = (data, y_axis) => {
	// TODO removing data with p-value = 0 for now, as it stretch the Y axis to +∞...
	let filtered = filter(data, (d) => d.pvalue_num > 1e-323);

	let res = [];
	for (const [index, element] of filtered.entries()) {
		// Set y value to be either p-value or HR
		if (y_axis === "pvalue") {
			var y = - Math.log10(element.pvalue_num);
		} else if (y_axis === "hr") {
			var y = element.hr;
		}

		// Grey color for non-low p-values
		if (element.pvalue_num < 0.05) {
			var color = colormap[element.categoryColor];
		} else {
			var color = colormap[2];
		}

		res.push({
			x: index,
			y: y,
			color: color,
			category: element.category,
			hr: element.hr,
			hr_str: element.hr_str,
			ci_min: element.ci_min,
			ci_max: element.ci_max,
			direction: element.direction,
			longname: element.longname,
			name: element.name,
			nindivs: element.nindivs,
			pvalue: element.pvalue_str,
		})
	}
	return res;
};


let getScales = (data, y_axis) => {
	// X axis
	let xMin = d3.min(data, (d) => d.x);
	let xMax = d3.max(data, (d) => d.x);

	// Y axis
	let yMin = d3.min(data, (d) => d.y);
	let yMax = d3.max(data, (d) => d.y);

	// X Scale
	let xScale = d3.scaleLinear().domain([xMin, xMax]).range([0, plotWidth]);

	// Y Scale
	if (y_axis === "pvalue") {
		var yScale = d3.scaleLinear().domain([yMin, yMax]).nice().range([plotHeight, 0]);
		var yFmt = yScale.tickFormat();  // use the default tick format
	} else if (y_axis === "hr") {
		var yScale = d3.scaleLog().domain([yMin, yMax]).range([plotHeight, 0]);
		var yFmt = yScale.tickFormat(100, "");
	}

	return {
		x: xScale,
		y: yScale,
		yFmt: yFmt,
	}
};

let showTooltip = (tooltip, point, other_pheno) => {
	let text = `
	<p>
		<b>${point.longname}</b> (${point.name})<br>
		happening <b>${point.direction}</b> ${other_pheno}<br>
	</p>
	<p>
		<b>HR:</b>&nbsp;${point.hr_str}&nbsp;[${point.ci_min},&nbsp;${point.ci_max}]<br>
		<b>p-value:</b>&nbsp;${point.pvalue}<br>
		<b>N. individuals:&nbsp;</b>${point.nindivs}<br>
		<b>Category:</b>&nbsp;${point.category}<br>
	</p>
	`;

	tooltip.style("display", "block")
		.html(text)
		.style("left", `${d3.event.pageX + tooltipMargin.x}px`)
		.style("top", `${d3.event.pageY}px`);
};

let hideTooltip = (tooltip) => {
	tooltip
		.style("display", "none");
};

let makePlot = (data, y_axis, ticks, categoryNames, other_pheno) => {
	// Remove a previous assoc plot if it existed, for example before we toggled the Y-axis that triggered this method to be re-run.
	// TODO this could be enhanced by updating data only via D3, instead of destroying everything and re-creating everything.
	d3.select("#d3-assoc-plot").select("svg").remove();

	let labelX = "Survival analyses grouped by category";

	if (y_axis === "pvalue") {
		var labelY = "-log₁₀ (p)";
	} else if (y_axis === "hr") {
		var labelY = "Hazard Ratio";
	}
	let scales = getScales(data, y_axis);

	let tooltip = d3.select("#d3-assoc-plot")
		.append("div")
		.attr("id", "tooltip")
		.attr("class", "tooltip")
		.style("display", "none");

	const svg = d3.select("#d3-assoc-plot")
		.insert("svg", ":first-child")
		.attr("width", width)
		.attr("height", height);

	// Main plot surface
	const g = svg.append("g")
		.attr("transform", `translate(${margin.labelY + margin.axisY}, 0)`);

	// Grey background
	g.append("rect")
		.attr("width", plotWidth)
		.attr("height", plotHeight)
		.style("fill", "#fafafa");

	// X axis
	let xAxis = d3.axisBottom(scales.x)
		.tickValues(ticks)
		.tickFormat( (d, i) => categoryNames[i] );
	svg.append("g")
		.attr("transform", `translate(${margin.labelY + margin.axisY}, ${plotHeight})`)
		.call(xAxis)
		// Rotate category names
		.selectAll("text")
			.attr("transform", "rotate(20)")
			.attr("x", 15)
			.style("text-anchor", "start")
			.style("font-size", "0.8rem");

	// Y axis
	svg.append("g")
		.attr("transform", `translate(${margin.labelY + margin.axisY}, 0)`)
		.call(d3.axisLeft(scales.y).tickFormat(scales.yFmt));

	// Y label
	svg.append("text")
		.html(labelY)
		.attr("x", - plotHeight / 2)
		.attr("y", margin.labelY)
		.attr("transform", "rotate(-90)")
		.style("text-anchor", "middle");

	// HR middle-line
	if (y_axis === "hr") {
		g.append("path")
			.attr("d", d3.line()([[scales.x(0), scales.y(1)], [plotWidth, scales.y(1)]]))
			.attr("stroke", "#65727d");
	}

	// Scatter
	let befores = filter(data, (d) => d.direction.toLowerCase() === "before");
	let circles = g.selectAll("points")
		.data(befores)
		.enter()
		.append("circle")
		.attr("cx", (d) => scales.x(d.x))
		.attr("cy", (d) => scales.y(d.y))
		.attr("fill", (d) => d.color)
		.attr("r", dot.size)
		.attr("opacity", dot.opacity)
		.on("mouseover", (d) => showTooltip(tooltip, d, other_pheno));

	let afters = filter(data, (d) => d.direction.toLowerCase() === "after");
	let squares = g.selectAll("points")
		.data(afters)
		.enter()
		.append("rect")
		.attr("x", (d) => scales.x(d.x) - square.size / 2)
		.attr("y", (d) => scales.y(d.y) - square.size / 2)
		.attr("fill", (d) => d.color)
		.attr("height", square.size)
		.attr("width", square.size)
		.attr("opacity", dot.opacity)
		.on("mouseover", (d) => showTooltip(tooltip, d, other_pheno));

	// Hide tooltip when mouse leaves the svg
	svg.on("mouseleave", () => hideTooltip(tooltip));
};


export default {
	data () {
		return {
			y_axis: "pvalue",
		}
	},
	props: {
		assocs: Array,
		phenocode: String,
	},
	methods: {
		set_yaxis(metric) {
			this.y_axis = metric;
			this.comp();  // refresh plot
		},
		comp() {
			let dp = dataPlot(this.assocs);
			let data = toPlotSpace(dp.data, this.y_axis);
			makePlot(data, this.y_axis, dp.ticks, dp.categoryNames, this.phenocode);
		}
	},
	mounted() {
		/* "mounted" is the earliest time in the Vue instance lifecycle
		 * where the template will be put into the DOM, thus selectable
		 * by d3.
		 * https://vuejs.org/v2/guide/instance.html#Lifecycle-Diagram
		 */
		this.comp();
	}
}
</script>


<style>
.tooltip {
    position: absolute;
	padding: .3rem;
	background-color: rgb(0, 0, 0, 0.75);
	color: white;
}
</style>
