// WIP.

// Load this module on any html page, and it will run the Englsh content of all
// script tags with type="text/englsh". Currently only works with inline
// content.

import * as compiler from "../bundle.js";
// console.log( window.c = compiler );
window.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll( 'script[type="text/englsh"]' ).forEach( script => {
    var englshContent = script.innerText,
      jsContent = compiler.compile( englshContent ).code;
    // console.log( 'evaling: \n' + jsContent );
    eval( jsContent );
  } );
}, false);
