import * as d3 from "d3";

var bars, xLabel, yLabel, xTicks, yTicks, subtitle;

const initWidth = 500;
let setDim = (width, isMobile) => {
    const ratio = isMobile ? 1.3 : 2;  // more square on mobile to improve readability
    bars   = {w: width, h: width / ratio};
    xLabel = {w: bars.w, h: 30};
    yLabel = {w: 15, h: bars.h};
    xTicks = {w: bars.w, h: 20, angledExtra: -20};
    yTicks = {w: 20, h: bars.h, marginTop: 15};
    subtitle = {marginTop: 30};
};
let surface =  (angledXAxis) => {
    let xExtra = angledXAxis ? xTicks.angledExtra : 0;
    return {
        w: bars.w + yTicks.w + yLabel.w,
        h: bars.h + xTicks.h + xLabel.h + xExtra
    }
};

var isCumulative = false;


let accumulate = (data) => {
    let sum_data = [];
    let sum = 0;
    let has_nan = false;
    for (var item of data) {
        if (isNaN(item.value)) {
            has_nan = true;
        }
        // The following line is specific to ACCumulate
        sum += item.value;
        sum_data.push({name: item.name, value: sum});
    }

    // Switch histogram style only if no NaN-values
    if (has_nan) {
        return data;
    } else {
        return sum_data;
    }
}

let decumulate = (data) => {
    let dec_data = [];
    let prev = 0;
    let has_nan = false;

    for (var item of data) {
        if (isNaN(item.value)) {
            has_nan = true;
        }
        // The 2 following lines are specific to DECumulate
        let current = item.value - prev;
        prev = item.value;
        dec_data.push({name: item.name, value: current});
    }

    // Switch histogram style only if no NaN-values
    if (has_nan) {
        return data;
    } else {
        return dec_data;
    }
}

let hasNaN = (data) => {
    let found = data.findIndex(item => isNaN(item.value));
    if (found === -1) {
        return false
    } else {
        return true
    }
}

let removeNaN = (data) => {
    return data.filter(item => ! isNaN(item.value))
}

let makeHistogram = (xlabel, ylabel, angleXAxis, div_name, data, width, isMobile) => {
    let nanTails = hasNaN(data);
    if (nanTails) {
        data = removeNaN(data);
    }

    // We rebuild the histogram on window resize, better remove the old one if it exists!
    d3.select("#" + div_name).selectAll("*").remove();
    // and update the dimensions
    setDim(width, isMobile);

    prepareHistogram(nanTails, xlabel, ylabel, angleXAxis, div_name, data);
    putData(angleXAxis, div_name, data);
}

let prepareHistogram = (nanTails, xlabel, ylabel, angleXAxis, div_name, data) => {
    let selector = "#" + div_name;

    // The whole surface dimensions
    let surf = surface(angleXAxis);

    let svg = d3.select(selector)
        .insert("svg", ":first-child")  // add svg as first item of selected <div>
        .attr("width", surf.w)
        .attr("height", surf.h)
        .attr("viewBox", `0 0 ${surf.w} ${surf.h}`)
        .attr("class", "font-sans");

    /* Tooltip */
    let tooltip = d3.select(selector)
        .append("div")
        .attr("id", div_name + "_tooltip")
        .attr("class", "tooltip")
        .style("display", "none");

    /* Bars */
    svg.append("g")
        .attr("id", div_name + "_rects")
        .attr("fill", "#2779bd")
        .attr("transform", `translate(${yLabel.w + yTicks.w}, ${bars.h}) scale(1, -1)`);

    /* X axis */
    svg.append("g")
        .attr("id", div_name + "_xaxis");

    /* Y axis */
    svg.append("g")
        .attr("id", div_name + "_yaxis");

    // Subtitle if NaN tails
    const bin_msg_pos = yLabel.w + yTicks.w + bars.w / 2;
    if (nanTails) {
        svg.append("text")
            .attr("transform", `translate(${bin_msg_pos}, ${subtitle.marginTop})`)
            .style("text-anchor", "middle")
            .style("font-size", "0.8rem")
            .text("(bins with 1 to 5 individuals are not shown)");
    }

    // X axis label
    const extra = angleXAxis ? 0 : xTicks.angledExtra;
    const xLabelPos = {
        x: yLabel.w + yTicks.w + bars.w / 2,
        y: bars.h + xTicks.h + extra
    };
    svg.append("text")
        .attr("transform",
              `translate(${xLabelPos.x}, ${xLabelPos.y})`)
        .style("text-anchor", "middle")
        .text(xlabel);


    // Y axis label
    const yLabelPos = {
        x: yLabel.w,
        y: - bars.h / 2
    };
    svg.append("text")
        .attr("transform", `rotate(-90) translate(${yLabelPos.y}, ${yLabelPos.x})`)
        .style("text-anchor", "middle")
        .text(ylabel);
};


let toggleCumulative = (div_name, switchToCumulative, angleXAxis) => {
    /* Abort if not changing the state */
    if (switchToCumulative === isCumulative) {
        return;
    } else {
        isCumulative = !isCumulative;
    }

    let selector = "#" + div_name;
    let id_bins = "#" + div_name + "_rects";
    let svg = d3.select(selector);
    let data = svg.select(id_bins).selectAll("rect").data();

    if (isCumulative) {
        putData(angleXAxis, div_name, accumulate(data));
    } else {
        putData(angleXAxis, div_name, decumulate(data));
    }
};

let putData = (angleXAxis, div_name, data) => {
    let id_xaxis = "#" + div_name + "_xaxis";
    let id_yaxis = "#" + div_name + "_yaxis";
    let id_bins = "#" + div_name + "_rects";
    let id_tooltip = "#" + div_name + "_tooltip";

    const surf = surface(angleXAxis);

    /* X scale */
    let x = d3.scaleBand()
        .domain(data.map(d => d.name))
        .range([yLabel.w + yTicks.w, bars.w])
        .paddingInner(0.05);

    /* Y scale */
    let y = d3.scaleLinear()
        .domain([0, d3.max(data, d => d.value)]).nice()
        .range([bars.h - (xLabel.h + xTicks.h), yTicks.marginTop]);

    /* X axis */
    let xAxis = (g) => {
        let elem = g.attr("transform", `translate(${yLabel.w + yTicks.w}, ${bars.h - (xLabel.h + xTicks.h)})`)
                        .call(d3.axisBottom(x).tickSizeOuter(0));
        if (angleXAxis) {
            elem = elem.selectAll("text")
                        .style("text-anchor", "end")
                        .attr("transform", "rotate(-50)");
        }
        return elem
    }

    /* Y axis */
    const yTicksPos = {
        // Not sure why putting "2 *" makes this work, maybe have to do with D3 putting a "text-anchor: end"?
        x: 2 * (yLabel.w + yTicks.w),
        y: 0
    };
    let yAxis = (g) => g
        .attr("transform", `translate(${yTicksPos.x}, ${yTicksPos.y})`)
        .call(d3.axisLeft(y));

    d3.select(id_xaxis)
        .call(xAxis);

    d3.select(id_yaxis)
        .call(yAxis);

    // TODO check error on click in JavaScript console: "Error: unknown type: mouseover"
    let drawBin = (selection) =>
        selection.attr("height", d => {
                        return y(0) - y(d.value)
                    })
            .on("mouseover", (event, d) => {
                d3.select(id_tooltip)
                    .style("display", "block")
                    .html(d.value)
                    .style("left", event.pageX + "px")
                    .style("top", event.pageY + "px");
            })
            .on("mouseout", d => {
                d3.select(id_tooltip)
                    .style("display", "none");
            });

    d3.select(id_bins)
        .selectAll("rect")
        .data(data)
        .join(
            enter => drawBin(enter.append("rect")),
            update => update.call(update => drawBin(update.transition().duration(100))),
        )
        .attr("x", d => x(d.name))
        .attr("y", xTicks.h + xLabel.h)
        .attr("width", x.bandwidth());
};

export {makeHistogram, toggleCumulative};
