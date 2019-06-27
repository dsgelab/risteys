<template>
  <div class="home-page">
    <SearchBox :results="results" :example="searchvalue"/>
    <div id="home-interactive-examples">
      <p>Examples:</p>
      <ul>
        <li>Search for <a href="#" @click="setSearch('angina')" class="font-mono">angina</a>,
          <a href="#" @click="setSearch('N14')" class="font-mono">N14</a> or
          <a href="#" @click="setSearch('dry')" class="font-mono">dry</a>
        </li>
        <li>Get statistics for the <a href="/phenocode/L12_ATOPIC" class="font-mono">L12_ATOPIC</a> phenocode</li>
      </ul>
    </div>
  </div>
</template>

<script>
import SearchBox from "./SearchBox.vue";

export default {
   data () {
        return {
          searchvalue: ''
        }
    },
    props: {
      results: {
        type: Array,
        default: function () {
          return []
        }
      },
    },
    methods: {
      setSearch (value) {
        var search_box = document.getElementById('search-input');
        search_box.focus();
        this.searchvalue = value;
      }
    },
    components: {
      SearchBox
    }
}
</script>
