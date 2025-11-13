const path = require('path');

module.exports = {
    env: {
        es6: true,
        node: true,
    },
    parser: '@typescript-eslint/parser',
    parserOptions: {
        project: [path.resolve(__dirname, 'tsconfig.json')],
        sourceType: 'module',
    },
    plugins: [
        '@typescript-eslint',
        'import',
    ],
    root: true,
    rules: {
        'import/no-unresolved': 'error',
    },
    ignorePatterns: [
        '/lib/**/*', // Ignore built files.
        '.eslintrc.js', // Ignore this config file.
    ],
};