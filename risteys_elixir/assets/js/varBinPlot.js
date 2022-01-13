import * as d3 from "d3";
import {filter, flatMap, indexOf, map, take, uniq, zipWith} from "lodash-es";


// -- CONFIG --
let config = {};

// Debug grid
config.debug = false;

// Whole SVG area
config.canvas = {};
config.canvas.height = 320;  // px
config.canvas.width = 580;  // px
config.canvas.fontFamily = "sans-serif";

// Margins
// Following https://observablehq.com/@d3/margin-convention
config.margin = {};
config.margin.left = 55; // px
config.margin.right = 15; // px
config.margin.top =  15; // px. Give a little headroom to not truncate text
config.margin.bot =  45; // px

// X tick labels
config.xTickLabels = {};
config.xTickLabels.marginBot = 27; // px. Push the labels above the X axis label
config.xTickLabels.fontSize = 10;
config.xTickLabels.textAnchor = "middle";
config.xTickLabels.yBaseline = config.canvas.height - config.xTickLabels.marginBot; // px

// Y tick labels
config.yTickLabels = {};
config.yTickLabels.fontSize = config.xTickLabels.fontSize;

// Horizontal bins
config.hbin = {};
config.hbin.height = 3;  // px
config.hbin.gap = 3;     // px
config.hbin.defaultDuration = 10;  // years. used for unbounded intervals, e.g. 90+ will visually appear as spanning 10 years

// Inner plotting area where the vertical bins lie
// The inner plotting area
config.vbinSurface = {};
config.vbinSurface.x1 = config.margin.left;                                // px
config.vbinSurface.x2 = config.canvas.width - config.margin.right;         // px
config.vbinSurface.y1 = config.margin.top;                                 // px
config.vbinSurface.y2 = config.canvas.height - config.margin.bot;          // px
config.vbinSurface.width = config.vbinSurface.x2 - config.vbinSurface.x1;  // px
config.vbinSurface.height = config.vbinSurface.y2 - config.vbinSurface.y1; // px

// X ticks
config.xTicks = {};
config.xTicks.stroke = "black";
config.xTicks.height = 5;  // px
config.xTicks.y1 = config.vbinSurface.y2 + config.hbin.height + 1;  // + 1 just make it look better
config.xTicks.y2 = config.xTicks.y1 + config.xTicks.height;

// Vertical bins
config.vbin = {};
config.vbin.width = 30;  // px
config.vbin.color = "#0b592f";

// Capture bins: transparent area drawn over bins to capture mouse or touch events
config.capbin = {};
config.capbin.fillOpacity = 0;

// Background bins
config.bgbin = {};
config.bgbin.fill = "#eee";

// Tooltips with numbers
config.tooltip = {};
config.tooltip.fontSize = 12;
config.tooltip.marginTop = 12;  // px. Push the tooltip baseline a bit down so it displays inside the canvas
config.tooltip.textAnchor = "middle";

// X axis label
config.xAxisLabel = {};
config.xAxisLabel.x = config.margin.left + config.vbinSurface.width / 2;  // px
config.xAxisLabel.y = config.canvas.height - 5;  // px

// Y axis label
config.yAxisLabel = {};
config.yAxisLabel.x = 15;  // px. push text to the right so it's not truncated
config.yAxisLabel.y = (config.vbinSurface.y2 - config.vbinSurface.y1) / 2;
config.yAxisLabel.textAnchor = "middle";


// -- HELPER FUNCTIONS --

/* Close open-ended intervals.
 *
 * Given a datum with an open-ended interval, we close it with a pre-defined default duration.
 * The purpose is to set a duration so the interval can be positioned.
 */
function closeInterval(datum) {
	var closedInterval;
	if (datum.interval.left === null) {
		closedInterval = {
			...datum.interval,
			left: datum.interval.right - config.hbin.defaultDuration
		}
	} else if (datum.interval.right === null) {
		closedInterval = {
			...datum.interval,
			right: datum.interval.left + config.hbin.defaultDuration
		}
	} else {
		closedInterval = datum.interval;
	}

	return {
		...datum,
		interval: closedInterval
	}
}


/* Return x1 and x2 bin positions (on canvas range) given the full set of bins and a specific bin,
 * taking into account the gap between bins by default.
 */
function binXpos(data, datum, withGaps = true) {
	const first = 0;
	const last = data.length - 1;
	const datumIdx = indexOf(data, datum);
	const halfGap = config.hbin.gap / 2;

	let x1 = scaleX(data)(datum.interval.left);
	if (withGaps && datumIdx !== first) {
		x1 += halfGap;
	}
	let x2 = scaleX(data)(datum.interval.right)
	if (withGaps && datumIdx !== last) {
		x2 -= halfGap;
	}

	return {
		x1: x1,
		x2: x2,
	}
}

/* Return the textual representation of a bin label */
function stringLabel(datum) {
	return datum.interval.left === null ? "" : datum.interval.left;
};

/* Display a grid to help identify drawing issues */
function debug(svg) {
	let dbgData = [];

	// Vertical lines
	for (var xx = 0; xx < config.canvas.width; xx += 10) {
		let stroke = "rgba(178, 232, 217, 0.5)";
		if (xx % 100 === 0) {
			stroke = "rgba(255, 182, 88, 0.5)";
		}
		dbgData.push({"x1": xx, "y1": 0, "x2": xx, "y2": config.canvas.height, "stroke": stroke});
	}

	// Horizontal lines
	for (var yy = 0; yy < config.canvas.height; yy += 10) {
		let stroke = "rgba(0, 0, 0, 0.1)";
		if (yy % 100 === 0) {
			stroke = "rgba(0, 0, 0, 0.20)";
		}
		dbgData.push({"x1": 0, "y1": yy, "x2": config.canvas.width, "y2": yy, "stroke": stroke});
	}

	svg.append("g")
		.selectAll("line")
		.data(dbgData)
		.enter()
			.append("line")
			.attr("x1", d => d.x1)
			.attr("y1", d => d.y1)
			.attr("x2", d => d.x2)
			.attr("y2", d => d.y2)
			.attr("stroke", d => d.stroke)
	;
}

// -- DATA TRANSFORMATION --
// Functions that helps mapping input data (domain) to output (range on canvas)

// The X and Y scales are in the plotting area
let scaleX = (data) => {
	// Data with closed intervals, so they can be positioned
	const cdata = map(data, closeInterval);
	return d3.scaleLinear()
			.domain(d3.extent(flatMap(cdata, d => [d.interval.left, d.interval.right])))
			.range([config.vbinSurface.x1, config.vbinSurface.x2]);
};

let scaleY = (data) => {
	const cdata = map(data, closeInterval);
	return d3.scaleLinear()
		.domain([0, d3.max(cdata, d => d.count)])
		.range([config.vbinSurface.y2, config.vbinSurface.y1]);
}

// VBin
function vbinPosDim(data) {
	return map(data, (datum) => {
		const pos = binXpos(data, datum);
		const middle = (pos.x1 + pos.x2) / 2;
		const left = middle - config.vbin.width / 2;

		const top = scaleY(data)(datum.count);
		const height = scaleY(data)(0) - top;  // rect height is drawn towards bottom
		return {
			x: left,
			width: config.vbin.width,
			y: top,
			height: height,
			fill: config.vbin.color
		}
	})
};

// HBin
function hbinPosDim(data) {
	const hbins = map(data, (datum) => {
		const pos = binXpos(data, datum);
		const x1 = pos.x1;
		const x2 = pos.x2;
		const width = x2 - x1

		return {
			x: x1,
			width: width,
			y: config.vbinSurface.y2,
			height: config.hbin.height
		}
	})

	return hbins
};


// capbin: Capture Bin
function capbinPosDim(data) {
	return map(data, (datum) => {
		const pos = binXpos(data, datum, false);
		const width = pos.x2 - pos.x1;
		const height = (
			(config.vbinSurface.y2 - config.vbinSurface.y1)  // vbinSurface height
			+ config.hbin.height                             // reach bottom of hbins
		);

		return {
			x: pos.x1,
			y: config.vbinSurface.y1,
			width: width,
			height: height,
			fillOpacity: config.capbin.fillOpacity,
		}
	})
}


// X ticks
function xTicksAndLabels(data) {
	let values = flatMap(data, (datum) => [datum.interval.left, datum.interval.right]);
	values = uniq(values);
	values = filter(values, (datum) => datum !== null);

	const ticks = map(values, (vv) => {
		const posX = scaleX(data)(vv);
		return {
			tick: {
				x1: posX,
				x2: posX,
				y1: config.xTicks.y1,
				y2: config.xTicks.y2,
				stroke: config.xTicks.stroke
			},
			label: {
				text: vv,
				x: posX,
				y: config.xTickLabels.yBaseline
			}
		}
	})

	return ticks
}


// Y ticks
let yAxis = (data) => {
	const axis = d3
		.axisLeft(scaleY(data))
		.ticks(10, "s");  // shortens tick labels, e.g. 6000 -> 6k
	return (g) => {
		g
		.attr("transform", `translate(${config.margin.left}, 0)`)
		.call(axis)
	}
}

// Tooltips
function tooltipPosDim(data) {
	return map(data, (datum) => {
		const pos = binXpos(data, datum);
		const x = (pos.x1 + pos.x2) / 2;
		return {
			x: x,
			y: config.tooltip.marginTop,
			text: datum.count
		}
	})
}

// Apply all data transformations
function dataToPlot(plotId, data, config) {
	const ids = map(data, (_datum, idx) => `${plotId}-datum${idx}`);
	const cdata = map(data, closeInterval);

	// Compute capbin
	const capbins = capbinPosDim(cdata);

	// Compute hbin
	const hbins = hbinPosDim(cdata);

	// Compute vbin
	const vbins = vbinPosDim(cdata);

	// Tooltips
	const tooltips = tooltipPosDim(cdata);

	const res = zipWith(
		ids, capbins, hbins, vbins, tooltips,
		(id, capbin, hbin, vbin, tooltip) => {
			return {
				id: id,
				selector: "#" + id,
				capbin: capbin,
				hbin: hbin,
				vbin: vbin,
				tooltip: tooltip
			}
	})

	return res
};


// -- PLOTTING --
function plot(selector, data, xAxisLabel, yAxisLabel) {
	const plotId = selector.slice(1);  // turn the selector into letter only by removing the leading '#'
	const pdata = dataToPlot(plotId, data, config);

	// Separate data for X ticks since we remove the last datum
	const xTicksData = xTicksAndLabels(data);

	const svg = d3.select(selector)
		.append("svg")
		// Setting the viewBox and not setting the SVG width and height allows for dynamic resizing
		.attr("viewBox", [0, 0, config.canvas.width, config.canvas.height])
		.attr("font-family", config.canvas.fontFamily);


	// Bin groups
	const groups = svg.selectAll("g")
		.data(pdata)
		.enter()
			.append("g");

	// .. Hover elements (bin background & tooltip)
	const hover = groups.append("g")
		.attr("id", d => d.id)
		.style("display", "none");  // hide by default, will be shown on hover

	// .. .. Draw the mouse/touch capture area
	hover.append("rect")
		.attr("x", d => d.capbin.x)
		.attr("y", d => d.capbin.y)
		.attr("width", d => d.capbin.width)
		.attr("height", d => d.capbin.height)
		.attr("fill", config.bgbin.fill);

	// .. .. Draw the tooltip
	hover.append("text")
		.attr("x", d => d.tooltip.x)
		.attr("y", d => d.tooltip.y)
		.attr("font-size", config.tooltip.fontSize)
		.attr("text-anchor", config.tooltip.textAnchor)
		.text(d => d.tooltip.text);

	// .. Draw HBins
	groups.append("rect")
		.attr("x", d => d.hbin.x)
		.attr("y", d => d.hbin.y)
		.attr("width", d => d.hbin.width)
		.attr("height", d => d.hbin.height);

	// .. Draw VBins
	groups.append("rect")
		.attr("x", d => d.vbin.x)
		.attr("y", d => d.vbin.y)
		.attr("width", d => d.vbin.width)
		.attr("height", d => d.vbin.height)
		.attr("fill", d => d.vbin.fill);

	// .. Draw (invisible) capture bins
	groups.append("rect")
		.attr("x", d => d.capbin.x)
		.attr("y", d => d.capbin.y)
		.attr("width", d => d.capbin.width)
		.attr("height", d => d.capbin.height)
		.attr("fill-opacity", d => d.capbin.fillOpacity)
		.on("touchstart mouseenter", (_event, d) => {
			d3.select(d.selector)
				.style("display", "block");
		})
		.on("touchend mouseleave", (_event, d) => {
			d3.select(d.selector)
				.style("display", "none")
		});


	// Draw X ticks
	svg.append("g")
		.selectAll("line")
		.data(xTicksData)
		.enter()
			.append("line")
			.attr("x1", d => d.tick.x1)
			.attr("x2", d => d.tick.x2)
			.attr("y1", d => d.tick.y1)
			.attr("y2", d => d.tick.y2)
			.attr("stroke", d => d.tick.stroke);

	// Draw X ticks labels
	svg.append("g")
		.attr("font-size", config.xTickLabels.fontSize)
		.selectAll("text")
		.data(xTicksData)
		.enter()
			.append("text")
			.attr("x", d => d.label.x)
			.attr("y", d => d.label.y)
			.attr("text-anchor", config.xTickLabels.textAnchor)
			.text(d => d.label.text);


	// Draw Y ticks
	svg.append("g")
		.call(yAxis(data))
		.attr("font-size", config.yTickLabels.fontSize);


	// Draw X label
	svg.append("text")
		.attr("text-anchor", "middle")
		.attr("x", config.xAxisLabel.x)
		.attr("y", config.xAxisLabel.y)
		.text(xAxisLabel);


	// Draw Y label
	svg.append("text")
		.attr("text-anchor", config.yAxisLabel.textAnchor)
		.attr("transform", `translate(${config.yAxisLabel.x}, ${config.yAxisLabel.y}) rotate(-90)`)
		.text(yAxisLabel);


	// Graphical debugging
	if (config.debug) {
		debug(svg);
	}
}

export {plot};
