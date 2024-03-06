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

# Risteys Analytics


```js
const data = FileAttachment("./data/summary_logs.json").json();
```
Showing statistics using data from ${data.time_span.min_date} to ${data.time_span.max_date}.
Updated daily. 🤖


```js
const daily_hits = data.stats_hits_per_day.map((rr) => {return {...rr, Day: new Date(rr.Day)}});
```

```js
const domainRange = [new Date(data.time_span.min_date), new Date(data.time_span.max_date)];
```

```js
function makeDomain(minDate, maxDate) {
  const length = (maxDate - minDate) + 1;
  let domain = [];

  let currentDate = minDate;
  while (currentDate <= maxDate) {
    domain.push(currentDate);
    currentDate = new Date(currentDate);
    currentDate.setUTCDate(currentDate.getUTCDate() + 1);
  }

  return domain;
}
```

```js
const domain = makeDomain(new Date(data.time_span.min_date), new Date(data.time_span.max_date));
```

```js
const top_page_hits = data.top_page_hits.map(
  (rec) => {
    const maxLength = 31;

    let shortPath = rec.Path;
    if (rec.Path.length >= maxLength) {
      shortPath = rec.Path.slice(0, maxLength - 1) + "…";
    }

    return {
      ...rec,
      shortPath: shortPath
    }
  }
)
```

```js
const bots_users = data.traffic.map(
  (rec) => {
    return {...rec, color: rec.source == "Users" ? "var(--theme-foreground-focus)" : "var(--theme-foreground-fainter)"}
  }
);
```

<div class="grid grid-cols-2">
  <div class="card">
    <h2>Daily page hits</h2>
  ${
  Plot.plot({
    style: "font-family: sans-serif",
    x: {label: null, ticks: "monday", domain: domain},
    y: {label: "Page hits"},
    marks: [
      Plot.gridY(),
      Plot.barY(daily_hits, {
        x: "Day",
        y: "HitsPerDay",
        fill: "var(--theme-foreground-focus)",
        tip: true,
      }),
      Plot.ruleY([0]),
    ]
  })
  }
  </div>

  <div class="card">
    <h2>Top page hits</h2>
  ${
  Plot.plot({
    style: "font-family: sans-serif",
    marginLeft: 230,
    color: {domain: ["OK", "Error"], range: ["var(--theme-foreground-focus)", "darkred"], legend: true},
    x: {label: "Page hits", grid: true},
    y: {label: "Page"},
    marks: [
      Plot.barX(top_page_hits, {
          x: "NHits",
          y: "shortPath",
          fill: "RequestResult",
          sort: {y: "-x"},
      }),
      Plot.ruleX([0]),
    ]
  })
  }
  </div>

  <div class="card">
    <h2>Bots vs. Users</h2>
  ${
  Plot.plot({
    style: "font-family: sans-serif",
    x: {
      label: "Relative number of requests",
      grid: true,
      domain: [0, 1],
      tickFormat: "%",
    },
    marks: [
      Plot.barX(bots_users, {
        x: "relative_hits",
        y: "source",
        fill: "color",
      }),
      Plot.axisY({label: null}),
      Plot.ruleX([0]),
    ]
  })
  }
    <p>Requests include: pages, images, data, etc.</p>
  </div>
</div>

