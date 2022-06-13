import * as d3 from "d3";

const margin = {
	top: 0,
	right: 0,
	bottom: 50,
	left: 55
};
const width = 535;
const height = 260;
const age = {
  min: 0,
  max: 100,
};
const cumulinc = {
  min: 0,
  max: 100,
};

// Linear interpolation used for the elements drawn on hover
function lerp(xm, points) {
  // No value if no points
  if (points.length === 0) {
    return null
  }

  // No value to return if outside of points range
  const mini = points[0].age;
  const maxi = points[points.length - 1].age;
  if (xm < mini || xm > maxi) {
    return null
  }

  // Value (finally!)
  else {
    const bisectPoints = d3.bisector(d => d.age).right;

    const idxRight = bisectPoints(points, xm);
    const idxLeft = Math.max(0, idxRight - 1);

    const x1 = points[idxLeft].age;
    const x2 = points[idxRight].age;
    const xNorm = (xm - x1) / (x2 - x1);

    const y1 = points[idxLeft].value;
    const y2 = points[idxRight].value;
    const y = y1 + xNorm * (y2 - y1);

    return y;
  }
}


function drawPlot(selector, data) {
  let female_serie;
  let male_serie;
  if (data[0].name === "female") {
    female_serie = 0;
    male_serie = 1;
  } else {
    female_serie = 1;
    male_serie = 0;
  }

  // Setup axes domain / range
  const line = d3
    .line()
    .x(d => x(d.age))
    .y(d => y(d.value))
  ;
  // Domain (ages) to range (pixels)
  const x = d3
  	  .scaleLinear()
  	  .domain(d3.extent([age.min, age.max]))
  	  .range([margin.left, width - margin.right])
  	  .clamp(true)
  ;
  // Domain (cumulative incidence) to range (pixels)
  const y = d3
  	  .scaleLinear()
  	  .domain([cumulinc.min, cumulinc.max]).nice()
  	  .range([height - margin.bottom, margin.top])
  ;
  const xAxis = (g) => {
     g.attr("transform", `translate(0,${height - margin.bottom})`)
      .call(d3.axisBottom(x).tickValues(d3.range(0, age.max + 1, 10)).tickSizeOuter(0))
      .attr("font-size", 12)
  };
  const yAxis = (g) => {
    g.attr("transform", `translate(${margin.left},0)`)
     .call(d3.axisLeft(y))
     .attr("font-size", 12)
  };


  // Build SVG
  const svg = d3
    .select(selector)
    .insert("svg", ":first-child")
    .attr("viewBox", [0, 0, width, height])
    .style("overflow", "visible")
  ;

  svg.append("g")
    .call(xAxis);

  svg.append("g")
    .call(yAxis);

  svg.append("g")
       .attr("fill", "none")
       .attr("stroke-width", 3)
     .selectAll("path")
     .data(data)
     .join("path")
       .style("mix-blend-mode", "multiply")
       .style("stroke-dasharray", d => d.dasharray)
       .attr("stroke", d => d.color)
       .attr("d", d => line(d.cumulinc))
  ;

  // Axis labels
  const xlabel = {
    text: "Age",
    x: 293,
    y: 250
  };
  svg.append("text")
      .attr("transform",
            `translate(${xlabel.x}, ${xlabel.y})`)
      .style("text-anchor", "middle")
      .text(xlabel.text);


  // Y axis label
  const ylabel = {
    text: "Probability of first incidence (%)",
    x: -110,
    y: 15
  };
  svg.append("text")
      .attr("transform", `rotate(-90) translate(${ylabel.x}, ${ylabel.y})`)
      .style("text-anchor", "middle")
      .text(ylabel.text);

  // Tooltip elements, drawn in order
  const tooltips = svg.append("g")
    .attr("display", "none")
    .style("font", "0.8rem sans-serif")
  ;

  const vertline = tooltips.append("path")
    .attr("fill", "none")
    .attr("stroke", "hsl(10deg, 0%, 58%)")
    .attr("stroke-width", 1)
    .style("stroke-dasharray", "1 1")
  ;

  const tooltipFemale = tooltips.append("g");
  const dotFemale = tooltipFemale.append("circle")
    .attr("r", 4)
    .attr("stroke", "white")
    .attr("stroke-width", 2)
  ;
  const textFemale = tooltipFemale
    .append("text")
    .attr("text-anchor", "end")
    .attr("x", -4)
  ;
  const tooltipMale = tooltips.append("g");
  const dotMale = tooltipMale.append("circle")
    .attr("r", 4)
    .attr("stroke", "white")
    .attr("stroke-width", 2)
  ;
  const textMale = tooltipMale.append("text");


  // Data to get values from pointer position
  svg.on("touchstart mouseenter", () => {
    tooltips.attr("display", null);
  });

  svg.on("touchend mouseleave", () => {
    tooltips.attr("display", "none");
  });

  svg.on("touchmove mousemove", (event) => {
    const mouseX = d3.pointer(event, this)[0];
    const xDomainVal = x.invert(mouseX);
    const xRangeVal = x(xDomainVal);  // pass it in x() to clamp the value

    // These can be null if cursor falls outside of curve domain
    const yFemaleDomainVal = lerp(xDomainVal, data[female_serie].cumulinc);
    const yMaleDomainVal = lerp(xDomainVal, data[male_serie].cumulinc);

    // Hide tooltips independetly if no value
    if (yFemaleDomainVal === null) {
      tooltipFemale.attr("display", "none");
    } else {
      tooltipFemale.attr("display", null);  // "null" will be transformed to CSS "unset"
    }
    if (yMaleDomainVal === null) {
      tooltipMale.attr("display", "none");
    } else {
      tooltipMale.attr("display", null);  // "null" will be transformed to CSS "unset"
    }

    const yFemaleRangeVal = y(yFemaleDomainVal);
    const yMaleRangeVal = y(yMaleDomainVal);

    // Vertline
    vertline
    .datum([
      {x: xRangeVal, y: 0},
      {
        x: xRangeVal,
        y: height - margin.bottom  // position of the X axis line
      }
    ])
      .attr("d", d3.line().x(d => d.x).y(d => d.y))
    ;

    // Position dots
    tooltipFemale.attr("transform", `translate(${xRangeVal}, ${yFemaleRangeVal})`);
    tooltipMale.attr("transform", `translate(${xRangeVal}, ${yMaleRangeVal})`);

    // Set and position texts
    textFemale.text(`Female: ${Math.floor(yFemaleDomainVal)}%`);
    textMale.text(`Male: ${Math.floor(yMaleDomainVal)}%`);

    // Reposition textMale if we are close to the right-side
    const percToLeft = xRangeVal / width;
    if (percToLeft > 0.9) {
       textMale
         .attr("text-anchor", "end")
         .attr("x", -4)
    } else {
       textMale
         .attr("text-anchor", "start")
         .attr("x", 4)
    }

  });
}

export {drawPlot};
