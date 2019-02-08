const path = require('path');

module.exports = {
    entry: './src/index.js',
    mode: 'development',
    output: {
	filename: 'main.js',
	path: path.resolve(__dirname, 'dist')
    },
    resolve: {
	alias: {
	    // Needed as we compile templates that are in HTML
	    'vue$': 'vue/dist/vue.esm.js' // 'vue/dist/vue.common.js' for webpack 1
	}
    },
    module: {
	rules: [
	    {
		test: /\.css$/,
		exclude: /node_modules/,
		use: [
		    {
			loader: 'style-loader',
		    },
		    {
			loader: 'css-loader',
			options: {
			    importLoaders: 1,
			}
		    },
		    {
			loader: 'postcss-loader'
		    }
		]
	    }
	]
    }
};
