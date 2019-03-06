const tailwindcss = require('tailwindcss')

module.exports = {
  plugins: [
    require('precss'),
    tailwindcss('./js/tailwind.js'),
    require('autoprefixer')
  ]
}
