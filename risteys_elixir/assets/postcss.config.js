const tailwindcss = require('tailwindcss')

const purgecss = require('@fullhuman/postcss-purgecss')({

  // Specify the paths to all of the template files in your project
  content: [
    '../lib/risteys_web/templates/**/*.html.eex',
    './js/**/*.vue',
    './js/*.js',

    // Special cases for some Phoenix files that generate HTML.
    '../lib/risteys_web/channels/search_channel.ex',
    '../lib/risteys_web/views/phenocode_view.ex',
  ],

  // Include any special characters you're using in this regular expression
  defaultExtractor: content => content.match(/[A-Za-z0-9-_:/]+/g) || []
})

module.exports = {
  plugins: [
    require('precss'),
    tailwindcss('./js/tailwind.js'),
    require('autoprefixer'),
    // NOTE we need to run webpack with "env NODE_ENV=production webpack --mode production"
    // for the following to consider the "production" var. If "NODE_ENV=production" is omitted
    // then NODE_ENV will be "development" even if "--mode production" was specified.
    // See https://github.com/webpack/webpack/issues/7074
    ...process.env.NODE_ENV === 'production'
      ? [purgecss]
      : []
  ]
}
