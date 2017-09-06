var assert = require('assert');
var fs = require( 'fs' );
require('@std/esm');
//eval( fs.readFileSync('./parser.js','utf8') );
//var parser = this.parser;
var parser = require( '../parser.js' );
var escodegen = require( 'escodegen' );
//console.log( e, e.generate,e.escodegen,Object.keys(e).length );
function translate( text ) {
  return escodegen.generate( parser.parse( text ), {
    //sourceMap:'q.js',
    //sourceMapWithCode: true,
    format: { indent: { style: '    ' } }
  } );
}
//import parse from '../parser';
/*
describe( 'General', function() {
  assert.equal( translate( 'Make x 1.' ), 'var x = 1;' );
} );*/

function runPhrasingGroup( phrasings ) {
  Object.keys( phrasings ).forEach( descr => {
    it( descr, () => {
      var phrasingGroup = phrasings[ descr ];
      Object.keys( phrasingGroup ).forEach( code => {
        phrasingGroup[ code ].forEach( phrasing => {
          try {
            var translated = translate( phrasing );
            assert.equal( translated, code );
          } catch ( e ) {
            throw Error( e + '\n"' + phrasing + '"' );
          }
          //expect( translate( phrasing ) ).to.equal( code );
        } );
      } );
    } );
    //assert.equal( translate( 'Make x 1.' ), 'var x = 1;' );
  } );
}

describe( 'Variables', function() {
  runPhrasingGroup( {
    'should process basic variable declarations': {
      'var x = 1;': [
        'Make x 1.',
        'Set x to 1.',
        'Have x equal 1.',
        'Let x = 1.',
        'X is 1.'
      ],
      'var x = \'thing\';': [
        'Make x equal "thing"'
      ]
    },
    'should avoid repeating var statements for the same variable': {
      'var x = 1;\nx = 2;': [
        'Make x 1. Set x to 2.'
      ]
    },
    'should allow definite articles': {
      'var test = target;': [
        'The test is equal to the target.',
        'Let the test equal the target.',
        'The test=the target.',
        // Let's refer to the target as test.
        'Let\'s call the target test.',
        'Name the target "test".'
      ]
    },
    'should work with mathematical operations': {
      'var x = 1 + 2;': [
        'X is 1 plus 2.',
        'Make x 1 + 2.'
      ],
      'var x = y - z;': [
        'Have x equal y minus z.',
        'X is equal to y - z.'
      ],
      'var x = y * z;': [
        'Make x y times z.',
        'X equals y multiplied by z.',
        'Set x to equal y * z.'
      ],
      'var x = y / z;': [
        'Set x as y divided by z.',
        'X is y over z.',
        'X equals y / z.'
      ]
    },
    'should allow operator assignment': {
      'x++;': [
        'Increment x.',
        'Increase x.'
      ],
      'x += 1 + 2;': [
        'Add 1 plus 2 to the x.',
        'Increase x by 1 + 2.'
      ],
      'x--;': [
        'Decrement x.',
        'Decrease x.'
      ],
      'x -= 2 * 3;': [
        'Subtract 2 times 3 from x.',
        'Decrease x by 2 times 3.'
      ],
      'x *= y;': [
        'Multiply the x by y.'
      ],
      'x /= y * z;': [
        'Divide x by y times z.'
      ]
    },
    'should support composite literals': {
      'var x = [];': [
        'X is  a group.',
        'Make x an array.',
        'Create a list named x.',
        'Build a group that we\'ll call "x".'
      ],
      'var x = {};': [
        'Make x a thing.',
        'Set up an object, which we shall refer to as "x".',
        'X is a thing.',
        'Make a thing called x.'
      ]
    },
    'should allow property assignment': {
      'x.y = z;': [
        'Make x\'s y z.',
        'Set the x\'s y to equal z.',
        'X\'s y equals the z.'
      ],
      'x.y.z = \'word\';': [
        'Let x\'s y\'s z equal "word".'
      ]
    },
    'should allow pronouns': {
      'var x = 1;\nx += 2;': [
        'X is 1. Add 2 to it.',
        'Let x = 1. Increment him by 2.',
        'Let x = 1. Increment her by 2.',
      ]
    },
    'should allow possessive pronouns': {
      'var x = {};\nx.y = z;': [
        'X is a thing. Its y is z.',
        'Make x a thing. Make its y z.',
        'X is an object. Its y is z.',
        'Make a thing called x. His y is z.',
        // Doesn't work. TODO.
        //'Make a thing named x. Her y is z.',
      ]
    },
    'should support English numbers': {
      'var x = 101 + 2;': [
        'X is one hundred and one plus two.',
        'Make X equal a hundred and one plus two.',
        'Make X equal one-hundred one plus two.'
      ],
      'var x = 2018 / 111;': [
        'X is two-thousand and eighteen over one hundred eleven.'
      ],
      'var x = 1345 * 0;': [
        'X is thirteen hundred and forty-five times zero.',
        'X equals one thousand three hundred forty-five multiplied by zero.'
      ]
    }
  } );

} );

describe( 'Functions', function() {
  runPhrasingGroup( {
    'should allow calling functions': {
      'x();': [
        'X.',
        'Do x.'
      ]
    },
    'should allow calling functions with arguments': {
      'x(y);': [
        'X y.',
        'X with y.',
        'X to y.',
        'X by y.',
        'X on y.',
        'X in y.',
      ],
      'x(y, z);': [
        'X y and z.',
        'X with y and z.',
        'X to y with z.'
      ],
      // TODO.
      /*
      'x(y + z)': [
        'X y plus z.'
      ]
    ]
      */
    },
    'should process basic function statements': {
      'function x() {\n    var y = z;\n}': [
        'To x, make y equal z.',
        'To x is to set y to z.',
        'To x: Make y z.'
      ]
    },
    /*
    'should give return values': {
      // TODO.
      'function x() {\n   return y;\n}': [
        // TODO: Make this work v
        // 'To x: the result is y.'
        //
      ]
    },
    */
    'should allow arguments': {
      // TODO
      /*
      'function x() {\n    var y = z;\n}': [
        'To x, make y equal z.',
        'To x is to set y to z.',
        'To x: Make y z.'
      ]
      */
    }
  } );

} );

describe( 'Conditions/loops', function () {
  runPhrasingGroup( {
    'should support basic if syntax': {
      'if (x === y) {\n    x++;\n}': [
        'If x equals y, increment x.',
        'If x equals y then increment x.',
        'If x equals y, then increment x.',
        'If x equals y: increment x.'
      ]
    },
    'should support postfix': {
      'if (x === y) {\n    z();\n}': [
        'Z if x is y.'
      ]
    },
    'should support math comparisons': {
      'if (x < y) {\n    x++;\n}': [
        "If the x is less than y, increment x.",
        "If the x is lower than y, increment x."
      ],
      'if (x > y + z) {\n    x++;\n}': [
        "If the x is more than y plus z, increment x.",
        "If x is greater than y plus z, increment x.",
        "If x is higher than y + z then increment x.",
        "If x is larger than y + z: increment x."
      ],
      'if (x >= 3) {\n    x++;\n}': [
        "If the x is more than or equal to 3, increment x.",
        "If the x is greater than or equal to 3, increment x."
      ],
    },
    'should support basic loop syntax': {
      'var x = 0;\nwhile (x < 3) {\n    x++;\n}': [
        'X is 0. While x is less than 3, increment x.',
        'Make x 0. So long as x is less than 3, increment x.'
      ],
      'var x = 0;\nwhile (!(x > 3)) {\n    x++;\n}': [
        'X is 0. Until x is more than 3, increment x.',
        'X is 0. Increment x until it is more than 3.',
        // TODO. Support it's.
        //'X is 0. Increment x until it\'s more than 3.',
      ]
    },
    'should support logical operators': {
      'if (x === 0 && y === 1) {\n    x++;\n}': [
        'If x is 0 and y is 1, increment x.'
      ],
      'if (x > 0 && x < 3) {\n    x++;\n}': [
        'If x is more than 0 and less than 3, increment x.'
      ],
      'if (x === 0 || x === 1) {\n    x++;\n}': [
        'If x equals 0 or 1, increment x.',
        'Increment x if x equals 0 or 1.',
      ],
      'if (x > 5 && x < 8 || x > 12) {\n    x++;\n}': [
        'If x is more than 5 and lower than 8 or greater than 12, increment x.'
      ],
      'if ((x > y || x > z) && x < max) {\n    x++;\n}': [
        'If x is more than y or z and lower than the max, increment x.'
      ],
      'if (x + y !== z) {\n    x();\n}': [
        'If x plus y doesn\'t equal z then x.',
        'If x plus y does not equal z then x.',
        // TODO.
        //'If x plus y is not equal to z then x.',
        'If x + y isn\'t equal to z, x.',
        'X if x + y isn\'t equal to z.'
      ],
      // This v doesn't work. Should it?
      // 'If x or y are lower than z'?
      // TODO.
      /*
      'if (x !== y && x !== z) { x(); }': [
        'If x doesn\'t equal y or z, x.'
      ]
    ]
      */
    },
    'should support until/unless': {
      'if (!(x === y)) {\n    z();\n}': [
        'Unless x equals y, z.',
        'Z unless x is y.'
        // Should this be supported?
        //'Z, unless x is y.'
      ],
      'while (!(1 === x)) {\n    y();\n}': [
        'Until 1 is x, y.',
        'Y until 1 equals x.'
      ]
    },
    // TODO: otherwise
  } );
} );

describe( 'Constructors', function () {
  runPhrasingGroup( {
    'Basic creation': {
      'var x = new X();': [
        'Create a x.',
        'Build an x.',
        'Make an x.',
        'Set up an x.',
        'Construct an x.',
        'There is an x.'
      ],
      'var y = new X();': [
        'Make y an x.',
        'Y is an x.',
        'Create an x called y.',
        'Make a x, which we\'ll call "y".',
        'Make a x, that shall be referred to as "y".',
        'Build a x which we shall refer to as y.',
        'Set up an x, that will be called \'y\'.',
        'Make a x, which shall be named "y".',
        'There\'s an x that we shall designate as y.'
      ]
    },
    'definition': {
      'function X() {\n    y(this);\n}': [
        'When creating an x, y it.',
        'When an x is created, y it.',
        'Every time an x is made, y the x.',
        'To create an x, y it.',
        'When setting up an x, y the x.'
      ]
    },
    'prototype inheritence': {
      'function X() {\n    b();\n}\nX.prototype = Object.create(Y.prototype);': [
        'When creating an x, b. An x is a y.'
      ]
    },
    'should create default constructor': {
      'var X = window.X || function X() {\n};\nX.prototype = Object.create(Y.prototype);': [
        'An x is a y.',
        'An x is a kind of y.',
        'An x is a type of y.'
      ]
    },
    'with arguments': {
      'function X(y, z) {\n    this.y = y;\n}': [
        'When making an x with a y and a z, make its y the y.',
        // TODO
        //'When an x is made with a y to a z, make the x\'s y the y.'
      ]
    }
  } );
} );

describe( 'Blocks', function () {
  runPhrasingGroup( {
    'should support L1 construction': {
      'x();\ny();': [
        // This doesn't work. It should. See ArgGroupNonPrep, which shouldn't allow & as first.
        // I feel like I fixed this in the other version.
        //'X and y.',
        'X, y.',
        'X, and y.',
        'X, and then y.'
      ]
    },
    // TODO.
    /*
    'should support L2 construction': {
      'if (b === c) {\n    x();\n    y();\n}': [
        // Same.
        //'If b is c, x and y.'
        //'If b is c, x and then y.'
        //'X and y if b is c.'
      ],
      'if (b === c) {\n    x();\n}\ny();': [
        // Same.
        //'If b is c, x and y.'
      ],
    },
    */
    'should support L3 construction': {
      'if (b === c) {\n    x();\n    y();\n}': [
        // Same.
        //'If b is c, x and y.'
        'If b is c, do the following: First, x. Finally, y.'
      ],
      // TODO: Meaningful separations. Nest ifs and whatnots. Also, plain dtfs.
      // TODO> Sequences of same-level blocks.
    },

  } );
} );

describe( 'Comments', function () {
  runPhrasingGroup( {
    'should support blocks': {
      'x();\ny();': [
        'X.\nNote: This is a note.\nY.',
        'X.\nNotes:\n*This is a note.\n*This is another note.\nY.',
        'Note: A note in the header.\nX. Y.',
        'X. Y. Note: A note at the bottom.',
        'Notes:\n* Multi-line note\n* in the header.\nX. Y.',
        'X. Notes:\n\n* Multi-line note\n\n* with gaps.\nY.',
      ],
    },
    'should support inline notes': {
      'x(y);': [
        'X the (note: lorum ipsum) y.',
        'X (Note: lorum ipsum) the y.',
        'X (Note that this also works.) the y.',
        '(Note: lorum ipsum) X the y.',
        'X y (Note: lorum ipsum).',
        'X y. (Note: lorum ipsum)',
        'X (Note: lorum ipsum, with a line\nbreak) the y.',
      ],
    },
  } );
} );

/*
describe( '', function () {
  runPhrasingGroup( {
    '': {
      '': [
        ''
      ],
    },
  } );
} );
*/
