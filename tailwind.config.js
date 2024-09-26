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
                'wild-wolf': ['WildWolf', 'sans-serif'],
                'neon-spark': ['NeonSpark', 'sans-serif'],
            },
        },
    },
    darkMode: 'class',
    plugins: [require('@tailwindcss/typography')],
};
