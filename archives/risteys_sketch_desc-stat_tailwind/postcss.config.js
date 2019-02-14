var tailwindcss = require('tailwindcss');

module.exports = {
    plugins: [
	require('precss'),
	tailwindcss('./src/tailwind.js'),
	require('autoprefixer')
    ]
}
