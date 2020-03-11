<template>
	<div id="d3-assoc-plot">
	</div>
</template>

<script>
import * as d3 from "d3";
import { drop, filter, flatten, groupBy, map, mapValues, reverse, sortBy, take } from "lodash-es";


// Layout, data independent
let margin = {
		labelX: 90,
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
let nCategories = 12;
let colormap = [
	"#2779bd",
	"#d33c8e",
	"#aaa"  // Other
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
	let categoryNames = map(topCategories, (assocs) => assocs[0].category );
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
		assoc.categoryColor = 2;  // the "Other" color
		return assoc;
	})

	return {
		ticks: xAxisTicks,
		categoryNames: categoryNames,
		data: topCategories.concat(other),
	};
};

let toPlotSpace = (data) => {
	// TODO removing data with p-value = 0 for now, as it stretch the Y axis to +∞...
	let filtered = filter(data, (d) => d.pvalue_num > 1e-323);

	let res = [];
	for (const [index, element] of filtered.entries()) {
		res.push({
			x: index,
			y: - Math.log10(element.pvalue_num),
			color: colormap[element.categoryColor],
			category: element.category,
			hr: element.hr,
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


let getScales = (data) => {
	// X axis
	let xMin = d3.min(data, (d) => d.x);
	let xMax = d3.max(data, (d) => d.x);

	// Y axis
	let yMin = d3.min(data, (d) => d.y);
	let yMax = d3.max(data, (d) => d.y);

	// Scales
	let xScale = d3.scaleLinear().domain([xMin, xMax]).range([0, plotWidth]);
	let yScale = d3.scaleLinear().domain([yMin, yMax]).range([plotHeight, 0]);

	return {
		x: xScale,
		y: yScale,
	}
};

let showTooltip = (tooltip, point, other_pheno) => {
	let text = `
	<p>
		<b>${point.longname}</b> (${point.name})<br>
		happening <b>${point.direction}</b> ${other_pheno}<br>
	</p>
	<p>
		<b>HR:</b>&nbsp;${point.hr}&nbsp;[${point.ci_min},&nbsp;${point.ci_max}]<br>
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

let makePlot = (data, ticks, categoryNames, other_pheno) => {
	let labelX = "Associations grouped by category";
	let labelY = "-log₁₀ (p)";
	let scales = getScales(data);

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
		.call(d3.axisLeft(scales.y));

	// Y label
	svg.append("text")
		.html(labelY)
		.attr("x", - plotHeight / 2)
		.attr("y", margin.labelY)
		.attr("transform", "rotate(-90)")
		.style("text-anchor", "middle");

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
		return {}
	},
	props: {
		assocs: Array,
		phenocode: String,
	},
	mounted() {
		/* "mounted" is the earliest time in the Vue instance lifecycle
		 * where the template will be put into the DOM, thus selectable
		 * by d3.
		 * https://vuejs.org/v2/guide/instance.html#Lifecycle-Diagram
		 */
		let dp = dataPlot(this.assocs);
		let data = toPlotSpace(dp.data);
		makePlot(data, dp.ticks, dp.categoryNames, this.phenocode);
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
