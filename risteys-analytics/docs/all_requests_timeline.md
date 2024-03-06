---
theme: dashboard
toc: false
---

<style>
body {
  font-family: serif;
}
.card {
  font-family: sans-serif;
}
</style>


# Timeline of all requests

```js
const timelineData = FileAttachment("./data/log_timeline.json").json();
```

```js
// Set the plot dimension to this fixed values so that:
// - y axis: 1px ⇔ 1 hour
// - x axis: 1px ⇔ 10 s
//
// NOTE(Vincent 2024-03-25): Maybe check this for scaling the SVG https://css-tricks.com/scale-svg/
//
// TODO(Vincent 2024-03-25):
// The 1px/1h 1px/10s is not working correctly because the dimensions we give to the plot
// include the axis ticks and labels, not just the drawing surface.
// Could use Plot.raster with pre-computed rasters in polars, and setting `pixelSize` to 1
// and `imageRendering` to pixelated.
const plotWidth = 720;
const plotHeight = 360;

const xDomain = [
  new Date(timelineData.date_range.from),
  new Date(timelineData.date_range.to)
];

const all_x1s = timelineData.timeline.x1.map((dd) => new Date(dd));
const all_x2s = timelineData.timeline.x2.map((dd) => new Date(dd));
```

```js
const user_x1s = [];
const user_x2s = [];
const user_y1s = [];
const user_y2s = [];

const bot_x1s = [];
const bot_x2s = [];
const bot_y1s = [];
const bot_y2s = [];

for (let ii = 0; ii < timelineData.timeline.Requester.length; ii++) {
  if (timelineData.timeline.Requester[ii] === "User") {
    user_x1s.push(all_x1s[ii]);
    user_x2s.push(all_x2s[ii]);
    user_y1s.push(timelineData.timeline.y1[ii]);
    user_y2s.push(timelineData.timeline.y2[ii]);
  } else if (timelineData.timeline.Requester[ii] === "Bot") {
    bot_x1s.push(all_x1s[ii]);
    bot_x2s.push(all_x2s[ii]);
    bot_y1s.push(timelineData.timeline.y1[ii]);
    bot_y2s.push(timelineData.timeline.y2[ii]);
  }
}
```

<div class="card">
  <h2>Timeline of all requests</h2>
${
  Plot.plot({
    width: plotWidth,
    height: plotHeight,
    x: {
      type: "utc",
      domain: xDomain,
      label: "Time"
    },
    y: {
      domain: [0, 60],
      label: "Minute"
    },
    color: {
      legend: true,
      domain: ["User", "Bot"],
      range: ["var(--theme-foreground-focus)", "var(--theme-foreground-fainter)"]
    },
    marks: [
      Plot.ruleY([0]),
      Plot.rect({length: all_x1s.length}, {
        x1: all_x1s,
        x2: all_x2s,
        y1: timelineData.timeline.y1,
        y2: timelineData.timeline.y2,
        fill: timelineData.timeline.Requester,
        fillOpacity: 0.12
      })
    ]
  })
}
</div>

<div class="card">
  <h2>Timeline of user requests</h2>
${
  Plot.plot({
    width: plotWidth,
    height: plotHeight,
    x: {
      type: "utc",
      domain: xDomain,
      label: "Time"
    },
    y: {
      domain: [0, 60],
      label: "Minute"
    },
    marks: [
      Plot.ruleY([0]),
      Plot.rect({length: user_x1s.length}, {
        x1: user_x1s,
        x2: user_x2s,
        y1: user_y1s,
        y2: user_y2s,
        fill: "var(--theme-foreground-focus)",
        fillOpacity: 0.18
      })
    ]
  })
}
</div>

<div class="card">
  <h2>Timeline of bot requests</h2>
${
  Plot.plot({
    width: plotWidth,
    height: plotHeight,
    x: {
      type: "utc",
      domain: xDomain,
      label: "Time"
    },
    y: {
      domain: [0, 60],
      label: "Minute"
    },
    marks: [
      Plot.ruleY([0]),
      Plot.rect({length: bot_x1s.length}, {
        x1: bot_x1s,
        x2: bot_x2s,
        y1: bot_y1s,
        y2: bot_y2s,
        fill: "var(--theme-foreground)",
        fillOpacity: 0.12
      })
    ]
  })
}
</div>
