module.exports = {
    entry: "./static/js/main.js",
    output: {
        path: __dirname+"/static/js/",
        filename: "bundle.js"
    },
    // externals: {
    //     // require("jquery") is external and available
    //     //  on the global var jQuery
    //     "jquery": "jQuery"
    // },
    module: {
        rules: [
            { 
              test: /\.scss$/,
              loaders: ["style-loader", "css-loader?-minimize", "sass-loader"],
            }
        ]
    },
};
