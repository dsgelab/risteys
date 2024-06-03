import * as Plot from "../vendor/plot.v0.6.14.js";
import * as d3 from "../vendor/d3.v7.9.0.js";

const formatLocaleEU = d3.formatLocale({
  thousands: " ", // non-breaking space
  decimal: ".",
  grouping: [3],
  currency: ["", ""],
});

const defaultPlotStyle = {
  backgroundColor: "var(--color-risteys-plot-background, white)",
  overflow: "visible", // NOTE(Vincent 2024-05-27) This prevents the tip being truncated.
};

function plotDiscreteAllOf(selector: string) {
  const elements = document.querySelectorAll(selector);

  for (const ee of elements) {
    if (ee instanceof HTMLElement && ee.dataset.obsplotDiscrete !== undefined) {
      const data = JSON.parse(ee.dataset.obsplotDiscrete);

      const plot = Plot.plot({
        marginLeft: 70,
        style: defaultPlotStyle,
        x: {
          label: "Number of records",
          tickFormat: "s",
          nice: true,
          zero: true,
        },
        y: { label: null },
        marks: [
          Plot.gridX({ stroke: "#888" }),
          Plot.ruleX([0]),
          Plot.barX(data.bins, {
            x: "y",
            y: "x",
            channels: { testResult: { value: "x", label: "Test result" } },
            tip: {
              format: {
                testResult: true,
                x: (dd: number) => formatLocaleEU.format(",")(dd),
                y: false,
              },
            },
            sort: { y: "-y" },
            fill: "var(--color-risteys-darkblue, black)",
          }),
        ],
      });
      ee.append(plot);
    }
  }
}

function plotCategoricalAllOf(selector: string) {
  const elements = document.querySelectorAll(selector);

  for (const ee of elements) {
    if (
      ee instanceof HTMLElement &&
      ee.dataset.obsplotCategorical !== undefined
    ) {
      const data = JSON.parse(ee.dataset.obsplotCategorical);

      // NOTE(Vincent 2024-06-03)
      // By default, the bar plot has a width fixed to 640 units.
      // This doesn't play well for some categorical plots that have very few
      // bins. For example, if the plot has 1 bin, then this bin will take the
      // full width of the 640px-wide plot.
      // The solution I took here is to adjust the plot width based on the
      // number of bins. It's kind of a "magic formula" that I made based on
      // trial and error using different categorical plots.
      const plotWidth = 100 + 32 * data.bins.length;

      const plot = Plot.plot({
        marginLeft: 70,
        width: plotWidth,
        style: defaultPlotStyle,
        x: {
          label: "Measured value (" + data.measurement_unit + ")",
          nice: true,
          tickFormat: "",
        },
        y: {
          label: "Number of records",
          tickFormat: "s",
          nice: true,
          zero: true,
        },
        marks: [
          Plot.gridY({ stroke: "#888" }),
          Plot.ruleY([0]),
          Plot.barY(data.bins, {
            x: "x",
            y: "y",
            fill: "var(--color-risteys-darkblue, black)",
          }),
          Plot.tip(
            data.bins,
            Plot.pointerX({
              x: "x",
              y: "y",
              format: {
                x: (dd: number) => formatLocaleEU.format(",")(dd),
                y: (dd: number) => formatLocaleEU.format(",")(dd),
              },
            }),
          ),
        ],
      });

      ee.append(plot);
    }
  }
}

function plotContinuousAllOf(selector: string) {
  const elements = document.querySelectorAll(selector);

  for (const ee of elements) {
    if (
      ee instanceof HTMLElement &&
      ee.dataset.obsplotContinuous !== undefined
    ) {
      const data = JSON.parse(ee.dataset.obsplotContinuous);

      const plot = Plot.plot({
        marginLeft: 70,
        style: defaultPlotStyle,
        x: {
          label: "Measured value (" + data.measurement_unit + ")",
          nice: true,
        },
        y: {
          label: "Number of records",
          tickFormat: "s",
          nice: true,
          zero: true,
        },

        marks: [
          Plot.gridY({ stroke: "#aaa" }),
          Plot.ruleY([0]),
          Plot.rectY(data.bins, {
            x1: "x1",
            x2: "x2",
            y: "y",
            fill: "var(--color-risteys-darkblue, black)",
          }),
          Plot.tip(
            data.bins,
            Plot.pointerX({
              x1: "x1",
              x2: "x2",
              // NOTE(Vincent 2024-05-27)
              // We could set `y: 0` to force the tip to be positioned on the x axis,
              // preventing it from jumping around due to different bin heights.
              y: "y",
              channels: {
                nRecords: { value: "y", label: "Number of records" },
                range: {
                  value: "range",
                  label: "Measured value (" + data.measurement_unit + ")",
                },
              },
              format: {
                x: false,
                range: true,
                nRecords: (dd: number) => formatLocaleEU.format(",")(dd),
              },
            }),
          ),
        ],
      });
      ee.append(plot);
    }
  }
}

export { plotDiscreteAllOf, plotCategoricalAllOf, plotContinuousAllOf };
