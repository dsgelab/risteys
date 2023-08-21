import * as d3 from '../vendor/d3.v6.js';

// Dimensions
const dim = {
	svgWidth: 55,
	svgHeight: 14,
};
const dotRadius = dim.svgHeight / 5;
const boxMargin = dotRadius + 1;  // + 1 to make sure we don't clip
const boxWidth = dim.svgWidth - 2 * boxMargin;


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

let toBoxSpace = (x) => {
	return x * boxWidth;
};

let drawCompBox = (hrBinned) => {
	const background = drawRect(0, 0, boxWidth, dim.svgHeight, "none", "#ffffff");
	const outline = drawRect(0, 0, boxWidth, dim.svgHeight, "black", "none");

	const mean_plot = toBoxSpace(0.5);
	const mean_line = drawLine(mean_plot, 0, mean_plot, dim.svgHeight, "#666");

	const q1_plot = toBoxSpace(0.25);
	const q3_plot = toBoxSpace(0.75);
	const quart_box = drawRect(q1_plot, 0, q3_plot, dim.svgHeight, "none", "#cacaca");

	const lop_plot = toBoxSpace(0.025);
	const hip_plot = toBoxSpace(0.975);
	const perc_box = drawRect(lop_plot, 0, hip_plot, dim.svgHeight, "none", "#ececec");

	const hr_plot = toBoxSpace(hrBinned);
	const hr_dot = svgCircle(
		hr_plot,            // x position
		dim.svgHeight / 2,  // y position
		dotRadius,
		"black",
		"black"
	);

	return `<svg height="${dim.svgHeight}" width="${dim.svgWidth}">
		<g transform="translate(${boxMargin}, 0)">
			${background}
			${perc_box}
			${quart_box}
			${mean_line}
			${outline}
			${hr_dot}
		</g>
	</svg>`
};


export {drawCompBox};
