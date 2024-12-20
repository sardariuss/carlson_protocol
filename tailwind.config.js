module.exports = {
	content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
    theme: {
        extend: {
            colors: {
                'slate-850' : '#172032',
                'grunt-pink' : '#dc05ff',
                'grunt-green' : '#59ff00',
                'neon-blue' : '#5be7dc',
            },
            fontFamily: {
                'acelon': ['Acelon', 'sans-serif'],
                'neon-spark': ['NeonSpark', 'sans-serif'],
            },
        },
    },
    plugins: [require('@tailwindcss/typography')],
};
