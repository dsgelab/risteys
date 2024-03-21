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
const timelineTyped = timelineData.timeline.map((rec) => {
  return {
    ...rec,
    HourTruncated: new Date(rec.HourTruncated),
  }
});
```

<div class="card">
  <h2>Timeline of all requests</h2>
${
  Plot.plot({
    x: {
      type: "utc",
      domain: [new Date(timelineData.date_range.from), new Date(timelineData.date_range.to)],
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
      Plot.dot(timelineTyped, {
        x: "HourTruncated",
        y: "AtMinute",
        tip: true,
        fillOpacity: 0.05,
        fill: "Requester",
        stroke: null,
        r: 1
      }),
    ]
  })
}
</div>

<div class="card">
  <h2>Timeline of all user requests</h2>
${
  Plot.plot({
    x: {
      type: "utc",
      domain: [new Date(timelineData.date_range.from), new Date(timelineData.date_range.to)],
      label: "Time"
    },
    y: {
      domain: [0, 60],
      label: "Minute"
    },
    color: {
      domain: ["User", "Bot"],
      range: ["var(--theme-foreground-focus)", "var(--theme-foreground-fainter)"]
    },
    marks: [
      Plot.ruleY([0]),
      Plot.dot(timelineTyped.filter((dd) => dd.Requester == "User"), {
        x: "HourTruncated",
        y: "AtMinute",
        tip: true,
        fillOpacity: 0.05,
        fill: "Requester",
        stroke: null,
        r: 1
      }),
    ]
  })
}
</div>

<div class="card">
  <h2>Timeline of all bot requests</h2>
${
  Plot.plot({
    x: {
      type: "utc",
      domain: [new Date(timelineData.date_range.from), new Date(timelineData.date_range.to)],
      label: "Time"
    },
    y: {
      domain: [0, 60],
      label: "Minute"
    },
    color: {
      domain: ["User", "Bot"],
      range: ["var(--theme-foreground-focus)", "var(--theme-foreground-fainter)"]
    },
    marks: [
      Plot.ruleY([0]),
      Plot.dot(timelineTyped.filter((dd) => dd.Requester == "Bot"), {
        x: "HourTruncated",
        y: "AtMinute",
        tip: true,
        fillOpacity: 0.15,
        fill: "Requester",
        stroke: null,
        r: 1
      }),
    ]
  })
}
</div>
