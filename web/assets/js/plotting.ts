// TODO(Vincent 2024-06-20)  Provide proper types where its missing.
// Not done for now as I might refactor all the plotting functions soon(TM).

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

type BinContinuous = {
  x1: number;
  x2: number;
  y: number;
};
type BinNotContinuous = {
  x: number;
  y: number;
};
type Bins = BinContinuous[] | BinNotContinuous[];

interface ObsData {
  bins: Bins;
}

interface ObsDataWithLabels extends ObsData {
  x_label: string;
  y_label: string;
}

function plotAllObs() {
  const elements = document.querySelectorAll("[data-obsplot]");

  for (const ee of elements) {
    if (ee instanceof HTMLElement && ee.dataset.obsplot !== undefined) {
      const data = JSON.parse(ee.dataset.obsplot);

      switch (ee.dataset.obsplotType) {
        case "discrete":
          ee.append(plotDiscrete(data));
          break;
        case "categorical":
          ee.append(plotCategorical(data));
          break;
        case "years":
          ee.append(plotYearOfBirh(data));
          break;
        case "year-months":
          ee.append(plotYearMonths(data));
          break;
        case "n-measurements-per-person":
          ee.append(plotNMeasurementsPerPerson(data));
          break;
        case "continuous":
          ee.append(plotContinuous(data));
          break;
        default:
          console.warn(`Unsupported plot type: ${ee.dataset.obsplotType}`);
      }
    }
  }
}

function plotDiscrete(data: ObsDataWithLabels) {
  return Plot.plot({
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
}

function plotCategorical(data: ObsDataWithLabels) {
  // NOTE(Vincent 2024-06-03)
  // By default, the bar plot has a width fixed to 640 units.
  // This doesn't play well for some categorical plots that have very few
  // bins. For example, if the plot has 1 bin, then this bin will take the
  // full width of the 640px-wide plot.
  // The solution I took here is to adjust the plot width based on the
  // number of bins. It's kind of a "magic formula" that I made based on
  // trial and error using different categorical plots.
  const plotWidth = 100 + 32 * data.bins.length;

  return Plot.plot({
    marginLeft: 70,
    width: plotWidth,
    style: defaultPlotStyle,
    x: {
      label: data.x_label,
      nice: true,
      tickFormat: "",
    },
    y: {
      label: data.y_label,
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
}

function plotContinuous(data: ObsDataWithLabels) {
  return Plot.plot({
    marginLeft: 70,
    style: defaultPlotStyle,
    x: {
      label: data.x_label,
      nice: true,
    },
    y: {
      label: data.y_label,
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
            x_formatted: {
              value: "x_formatted",
              label: data.x_label,
            },
            y_formatted: {
              value: "y_formatted",
              label: data.y_label,
            },
          },
          format: {
            x: false,
            y: false,
            x_formatted: true,
            y_formatted: true,
          },
        }),
      ),
    ],
  });
}

function plotYearOfBirh(data: ObsData) {
  return Plot.plot({
    marginLeft: 70,
    style: defaultPlotStyle,
    x: {
      label: "Year of birth",
      tickFormat: "d",
      nice: true,
    },
    y: {
      label: "Number of people",
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
            x_formatted: {
              value: "x_formatted",
              label: "Year of birth",
            },
            y_formatted: {
              value: "y_formatted",
              label: "Number of people",
            },
          },
          format: {
            x: false,
            y: false,
            x_formatted: true,
            y_formatted: true,
          },
        }),
      ),
    ],
  });
}

function plotYearMonths(data) {
  // Convert Year-Month value from string to JS Date
  const bins = data.bins.map((bin) => {
    return { ...bin, yearMonthDate: new Date(bin.year_month) };
  });

  return Plot.plot({
    marginLeft: 70,
    style: defaultPlotStyle,
    x: {
      label: "Time",
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
      Plot.rectY(bins, {
        x: "yearMonthDate",
        y: "nrecords",
        interval: "month",
        fill: "var(--color-risteys-darkblue, black)",
        insetRight: 0, // ::MOIRE Remove the default 1px inset, as it leads to a strong Moiré pattern.
      }),
      Plot.tip(
        bins,
        Plot.pointerX({
          x: "yearMonthDate",
          y: "nrecords",
          channels: {
            timePeriod: {
              label: "Time period",
              value: (bin) => {
                return bin.yearMonthDate.toLocaleString(undefined, {
                  month: "short",
                  year: "numeric",
                });
              },
            },
            yFormatted: {
              label: "Number of records",
              value: (bin) => formatLocaleEU.format(",")(bin.nrecords),
            },
          },
          format: {
            x: false,
            y: false,
            timePeriod: true,
            yFormatted: true,
          },
        }),
      ),
    ],
  });
}

function plotNMeasurementsPerPerson(data) {
  const minDisplayBins = 50;

  // NOTE(Vincent 2024-06-20) Setting `undefined` as the domain makes Plot.plot
  // infer it from the data as [min, max].
  const xDomain =
    data.bins.length >= minDisplayBins ? undefined : [1, minDisplayBins];

  return Plot.plot({
    marginLeft: 70,
    style: defaultPlotStyle,
    x: {
      label: "Number of measurements per person",
      nice: true,
      domain: xDomain,
    },
    y: {
      label: "Number of people",
      tickFormat: "s",
      nice: true,
      zero: true,
    },

    marks: [
      Plot.gridY({ stroke: "#aaa" }),
      Plot.ruleY([0]),
      Plot.rectY(data.bins, {
        x: "n_measurements",
        y: "npeople",
        interval: 1,
        fill: "var(--color-risteys-darkblue, black)",
        insetRight: 0, // see ::MOIRE
      }),
      Plot.tip(
        data.bins,
        Plot.pointerX({
          x: "n_measurements",
          y: "npeople",
          channels: {
            NMeasurements: {
              label: "N. measurements",
              value: (bin) => bin.n_measurements,
            },
            NPeople: {
              label: "N. people",
              value: (bin) => bin.npeople,
            },
          },
          format: {
            x: false,
            y: false,
            NMeasurements: true,
            NPeople: true,
          },
        }),
      ),
    ],
  });
}

export { plotAllObs };
