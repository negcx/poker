const purgecss = require("@fullhuman/postcss-purgecss")({
    content: ["../lib/poker_web/templates/**/*.html.eex",
        "../lib/poker_web/templates/**/*.html.leex"],
    defaultExtractor: content => content.match(/[\w-/:]+(?<!:)/g) || []
});

module.exports = {
    plugins: [
        require("tailwindcss"),
        require("autoprefixer"),
        ...(process.env.MIX_ENV === "prod" ? [purgecss] : [])
    ]
};
