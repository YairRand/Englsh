import * as parser from '../parser.js';
import { generate } from 'astring'
import sourceMap from 'source-map'

//import escodegen from 'escodegen';

//var astring = require( 'astring' );
//var generate = astring.generate;
//import * as compiler from 'astring';
//import { generate } from 'escodegen';
//import { generate } from '../node_modules/escodegen/escodegen.js';
//import * as escodegen from 'escodegen';
//var escodegen = require( 'escodegen' );

/**
 * @return {Object}
 * @return {String} return.code
 * @return {SourceMapGenerator} return.map
 */
function compile( text, format ) {
  //console.log( astring );

  var map = new sourceMap.SourceMapGenerator({
    // Arbitrary name, which apparently needs to be set.
    file: '_placeholder.js',
  });

  return {
    code: generate( parser.parse( text ), Object.assign( {
    //return escodegen.generate( parser.parse( text ), {
    //return generate( parser.parse( text ), {
      //format: format || { indent: { style: '' }, newline: '' }
      indent: '', lineEnd: '',
      sourceMap: map
    }, format || {} ) ),
    map
  };
}

export { compile, sourceMap }
