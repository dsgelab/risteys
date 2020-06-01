import * as d3 from 'd3';

// Dimensions
let dim = {
	svgWidth: 60,
	svgHeight: 16,

	// Gives a nice margin for the [2.5, 97.5] percentile box
	hrMin: -3,
	hrMax:  3,
};


let svgPath = (dobj, stroke, fill) => {
	return `<path stroke="${stroke}" fill="${fill}" d="${dobj.toString()}" />`;
};

let svgCircle = (x, y, r, stroke, fill) => {
	return `<circle cx="${x}" cy="${y}" r="${r}" fill="${fill}" stroke="${stroke}"></circle>`;
};

let drawRect = (x0, y0, x1, y1, stroke, fill) => {
	const p = d3.path();
	p.rect(x0, y0, x1 - x0, y1 - y0);
	return svgPath(p, stroke, fill);
};

let drawLine = (x0, y0, x1, y1, stroke) => {
	const l = d3.line()([[x0, y0], [x1, y1]]);
	return svgPath(l, stroke, "none");
};

let toBoxSpace = (x, hr_min, hr_max) => {
	return (x - hr_min) / (hr_max - hr_min) * dim.svgWidth;
};

let drawCompBox = (hr, hr_min, hr_max, lop, q1, median, q3, hip) => {
	var hr_min = Math.min(hr_min - 1, dim.hrMin);
	var hr_max = Math.max(hr_max + 1, dim.hrMax);

	const background = drawRect(0, 0, dim.svgWidth, dim.svgHeight, "none", "#ffffff");
	const outline = drawRect(0, 0, dim.svgWidth, dim.svgHeight, "black", "none");

	const median_plot = toBoxSpace(median, hr_min, hr_max);
	const median_line = drawLine(median_plot, 0, median_plot, dim.svgHeight, "#666");

	const q1_plot = toBoxSpace(q1, hr_min, hr_max);
	const q3_plot = toBoxSpace(q3, hr_min, hr_max);
	const quart_box = drawRect(q1_plot, 0, q3_plot, dim.svgHeight, "none", "#cacaca");

	const lop_plot = toBoxSpace(lop, hr_min, hr_max);
	const hip_plot = toBoxSpace(hip, hr_min, hr_max);
	const perc_box = drawRect(lop_plot, 0, hip_plot, dim.svgHeight, "none", "#ececec");

	const hr_plot = toBoxSpace(hr, hr_min, hr_max);
	const hr_dot = svgCircle(
		hr_plot,            // x position
		dim.svgHeight / 2,  // y position
		dim.svgHeight / 5,  // circle radius
		"black",
		"black"
	);

	return `<svg height="${dim.svgHeight}" width="${dim.svgWidth}">
		${background}
		${perc_box}
		${quart_box}
		${median_line}
		${hr_dot}
		${outline}
	</svg>`
};


export {drawCompBox};
