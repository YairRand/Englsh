import commonjs from 'rollup-plugin-commonjs';
import resolve from 'rollup-plugin-node-resolve';

export default {
  input: 'src/compiler.js',
  output: {
    file: 'bundle.js',
    //format: 'iife'
    format: 'es'
  },
  name: 'foo',
  plugins: [
    resolve({
      jsnext: true,
      main: true,
      browser: true,
      //modulesOnly: true
    }),

    commonjs({
      // non-CommonJS modules will be ignored, but you can also
      // specifically include/exclude files
      include: 'node_modules/**',  // Default: undefined
      //exclude: [ 'path', 'node_modules/path/**' ],  // Default: undefined
      // these values can also be regular expressions
      // include: /node_modules/

      // if true then uses of `global` won't be dealt with by this plugin
      ignoreGlobal: false,  // Default: false

      // if false then skip sourceMap generation for CommonJS modules
      sourceMap: false,  // Default: true

      // explicitly specify unresolvable named exports
      // (see below for more details)
      //namedExports: { 'node_modules/escodegen/escodegen.js': 'escodegen' },  // Default: undefined
      namedExports: { 'node_modules/astring/dist/astring.js': ['generate'] },  // Default: undefined

      // sometimes you have to leave require statements
      // unconverted. Pass an array containing the IDs
      // or a `id => boolean` function. Only use this
      // option if you know what you're doing!
      ignore: [ './package.json', 'path' ]
    }),
  ]
};
