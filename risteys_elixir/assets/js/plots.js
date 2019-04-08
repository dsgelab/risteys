import * as d3 from "d3";

var width = 600,
    height = 300,
    label_margin = 30,
    margin = {
        top: 0,
        right: 0,
        bottom: 20 + label_margin,
        left: 40 + label_margin,
    };

let accumulate = (data) => {
    let sum_data = [];
    let sum = 0;
    for (var item of data) {
        sum += item.value;
        sum_data.push({name: item.name, value: sum});
    }
    return sum_data;
}

let makeHistogram = (title, xlabel, ylabel, div_name, data) => {
    prepareHistogram(title, xlabel, ylabel, div_name, data);
    putData(div_name, data);
}

let prepareHistogram = (title, xlabel, ylabel, div_name, data) => {
    let selector = "#" + div_name;

    let svg = d3.select(selector)
        .attr("width", width)
        .attr("height", height);

    svg.append("g")
        .attr("id", div_name + "_rects")
        .attr("fill", "steelblue")
        .attr("transform", "translate(0, 300) scale(1, -1)");

    svg.append("g")
        .attr("id", div_name + "_xaxis");

    svg.append("g")
        .attr("id", div_name + "_yaxis");

    // Title
    svg.append("text")
        .attr("transform",
            `translate(${width / 2}, 20)`)
        .style("text-anchor", "middle")
        .text(title);

    // X axis label
    svg.append("text")
        .attr("transform",
              `translate(${width / 2}, ${height - 10})`)  // "10" to make the label fully inside the SVG
        .style("text-anchor", "middle")
        .text(xlabel);

    // Y axis label
    svg.append("text")
        .attr("transform", `rotate(-90) translate(${- height / 2}, ${label_margin})`)
        .style("text-anchor", "middle")
        .text(ylabel)
};

let putData = (div_name, data) => {
    let id_xaxis = "#" + div_name + "_xaxis";
    let id_yaxis = "#" + div_name + "_yaxis";
    let id_bins = "#" + div_name + "_rects";

    let x = d3.scaleBand()
        .domain(data.map(d => d.name))
        .range([margin.left, width - margin.right])
        .padding(0.2);

    let y = d3.scaleLinear()
        .domain([0, d3.max(data, d => d.value)]).nice()
        .range([height - margin.bottom, margin.top + 20]);

    let xAxis = (g) => g
        .attr("transform", `translate(0, ${height - margin.bottom})`)
        .call(d3.axisBottom(x).tickSizeOuter(0));

    let yAxis = (g) => g
        .attr("transform", `translate(${margin.left}, 0)`)
        .call(d3.axisLeft(y));

    d3.select(id_xaxis)
        .call(xAxis);

    d3.select(id_yaxis)
        .call(yAxis);

    d3.select(id_bins)
        .selectAll("rect")
        .data(data)
        .join(
            enter => enter.append("rect")
                        .attr("height", d => y(0) - y(d.value)),
            update => update
                        .call(update => update.transition().duration(100)
                            .attr("height", d => y(0) - y(d.value))),
        )
        .attr("x", d => x(d.name))
        .attr("y", margin.bottom)
        .attr("width", x.bandwidth());
};

export {accumulate, makeHistogram, putData};
