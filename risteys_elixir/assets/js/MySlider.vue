<!-- Adapted from https://www.w3.org/TR/wai-aria-practices/examples/slider/multithumb-slider.html -->
<!--
This content is licensed according to the W3C Software License at
https://www.w3.org/Consortium/Legal/2015/copyright-software-and-document

File:   slider.js

Desc:   Slider widget that implements ARIA Authoring Practices
-->

<template>
  <label> Age 
    <div class="aria-widget-slider">
      <div class="rail-label min">
        {{ ageMin }}
      </div>
      <div class="rail" :style="cssRailWidth">
        <img id="slider-age-min"
        src="/images/min-arrow.png"
        role="slider"
        tabindex="0"
        class="min thumb"
        :aria-valuemin="limitMin"
        :aria-valuenow="ageMin"
        :aria-valuemax="limitMax"
        aria-label="Data Minimum Age"

        @keydown.arrow-left.stop.prevent="minMinus1"
        @keydown.arrow-down.stop.prevent="minMinus1"
        
        @keydown.arrow-right.stop.prevent="minPlus1"
        @keydown.arrow-up.stop.prevent="minPlus1"

        @keydown.page-down.stop.prevent="minMinus10"
        @keydown.page-up.stop.prevent="minPlus10"

        @mousedown="startMoveMin"
        @mousemove="mouseMoveMin"
        @mouseup="stopMoveMin"

        :style="cssPosMin" 
        >
        <img id="slider-age-max"
        src="/images/max-arrow.png"
        role="slider"
        tabindex="0"
        class="max thumb"
        :aria-valuemin="limitMin"
        :aria-valuenow="ageMax"
        :aria-valuemax="limitMax"
        aria-label="Data Maximum Age"

        @keydown.arrow-left.stop.prevent="maxMinus1"
        @keydown.arrow-down.stop.prevent="maxMinus1"
        
        @keydown.arrow-right.stop.prevent="maxPlus1"
        @keydown.arrow-up.stop.prevent="maxPlus1"
        
        @keydown.page-down.stop.prevent="maxMinus10"
        @keydown.page-up.stop.prevent="maxPlus10"

        :style="cssPosMax"
        >
      </div>
      <div class="rail-label max">
        {{ ageMax }}
      </div>
    </div>
  </label>
</template>



<script>
export default {
  data: function () {
    return {
      sliderWidth: 200,
      limitMin: 0,
      limitMax: 100,
      ageMin: 25,
      ageMax: 70,
      minPrevPos: null,
    }
  },
  computed: {
    cssRailWidth: function() {
      return "width: " + this.sliderWidth + "px"
    },
    cssPosMin: function() {
      var pos = this.toPosSpace(this.ageMin) - 30;
      return "left: " + pos +"px"
    },
    cssPosMax: function() {
      var pos = this.toPosSpace(this.ageMax);
      return "left: " + pos +"px"
    },
  },
  methods: {
    toPosSpace: function(age) {
      return parseInt((age / this.limitMax) * this.sliderWidth)
    },
    moveMin: function(value) {
      console.log("move value: " + value);
      if (value < this.limitMin) {
        this.ageMin = this.limitMin
      } else if (value > this.ageMax) {
        this.ageMin = this.ageMax
      } else {
        this.ageMin = value
      }
    },
    moveMax: function(value) {
      if (value > this.limitMax) {
        this.ageMax = this.limitMax
      } else if (value < this.ageMin) {
        this.ageMax = this.ageMin
      } else {
        this.ageMax = value
      }
    },

    startMoveMin: function(event) {
      console.log("start moving")
      this.minPrevPos = event.clientX
    },
    mouseMoveMin: function(event) {
      if (this.minPrevPos !== null) {
        var diffX = event.clientX - this.minPrevPos;
        console.log("diff: " + diffX)
        var age = this.ageMin + (diffX / this.sliderWidth * this.limitMax + this.limitMin) 
        this.moveMin(age)

        this.minPrevPos = event.clientX
      }
    },
    stopMoveMin: function() {
      console.log("stop moving")
      this.minMoving = false
    },

    minMinus1: function() {
      this.moveMin(this.ageMin - 1)
    },
    minMinus10: function() {
      this.moveMin(this.ageMin - 10)
    },
    
    minPlus1: function() {
      this.moveMin(this.ageMin + 1)
    },
    minPlus10: function() {
      this.moveMin(this.ageMin + 10)
    },
    
    maxMinus1: function() {
      this.moveMax(this.ageMax - 1)
    },
    maxMinus10: function() {
      this.moveMax(this.ageMax - 10)
    },

    maxPlus1: function() {
      this.moveMax(this.ageMax + 1)
    },
    maxPlus10: function() {
      this.moveMax(this.ageMax + 10)
    },
  }
}
</script>


<style>
/* CSS Document */

div.aria-widget-slider {
  clear: both;
  padding-top: 0.5em;
  padding-bottom: 1em;
}

div.rail-label {
  padding-right: 0.5em;
  text-align: right;
  float: left;
  width: 4em;
  position: relative;
  top: -0.5em;
}

div.rail-label.max {
  padding-left: 0.5em;
  text-align: left;
}

div.aria-widget-slider .rail {
  background-color: #eee;
  border: 1px solid #888;
  position: relative;
  height: 4px;
  float: left;
}

div.aria-widget-slider img[role="slider"] {
  position: absolute;
  padding: 0;
  margin: 0;
  top: -10px;
}


div.aria-widget-slider img[role="slider"]:hover {
  cursor: grab;
}
div.aria-widget-slider img[role="slider"]:focus {
  cursor: grabbing;
}

div.aria-widget-slider img[role="slider"]:focus,
div.aria-widget-slider img[role="slider"]:hover {
  outline-color: rgb(140, 203, 242);
  outline-style: solid;
  outline-width: 2px;
  outline-offset: 2px;
}

div.aria-widget-slider .rail.focus {
  background-color: #aaa;
}

</style>
