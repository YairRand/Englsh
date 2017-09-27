// Lots copied from
// https://github.com/pegjs/pegjs/blob/master/examples/javascript.pegjs
// TODO: error handling, ...
//
// Note for later: It technically is possible to modify earlier stuff, by
// storing the JSON array/object and then modifying it in JS directly.

// I still have no plan for how to send functions as arguments.


{
  function buildList(head, tail, index) {
    return [head].concat(extractList(tail, index));
  }

  function extractList(list, index) {
    return list.map( x => x[ index ] );
  }

  function buildTree(head, tail, builder) {
    var result = head, i;

    for (i = 0; i < tail.length; i++) {
      result = builder(result, tail[i]);
    }

    return result;
  }

  function BinaryExpression( left, op, right ) {
    return {
      type:     "BinaryExpression",
      operator: op,
      left:     left,
      right:    right
    };
  }

  function buildBinaryExpression(head, tail) {
    return buildTree(head, tail, function(result, element) {
      return BinaryExpression( result, element[ 1 ], element[ 3 ] );
    });
  }

  function buildLetStatement( name, val ) {
    var m = name.type === "MemberExpression",
      eReturn = getExpectedReturn();
    // This can be either a var statement or a return statement.
    if ( eReturn && ( name.name === eReturn || val.name === eReturn ) ) {
      var returnValue = name.name === eReturn ? val : name;
      returned = true;
      // TODO: Remember what type the ReturnStatement of the function was.
      return  {
        "type": "ReturnStatement",
        "argument": returnValue,
        loc: loc()
      };
    } else {
      // Var statement
      var preDeclared = m || hasVar( name.name );
      solidifyRemember( name );
      if ( !preDeclared ) {
        addVar( name.name, { type: val.type === "Literal" ? typeof val.value : 'unknown' } );
        return {
          "type": "VariableDeclaration",
          "declarations": [
            {
              "type": "VariableDeclarator",
              "id":   name,
              "init": val
            }
          ],
          "kind": "var",
          loc: loc()
        };
      } else {
        return buildExpressionStatement( {
          "type": "AssignmentExpression",
          "operator": "=",
          "left": name,
          "right": val,
          loc: loc()
        } );
      }
    }
  }

  // Go through the params, look for a param with a matching "return"-style
  // statement in the function body, and return that.
  function getReturnParam( params, body ) {
    var hits = {},
      returnParam;

    // TODO: This should only apply to "direct object" params.
    params && params.forEach( param => hits[ param.name ] = 0 );
    function loop( j ) {
      if ( j && typeof j === 'object' ) {
        if ( j.type === "Identifier" ) {
          ( j.name in hits ) && hits[ j.name ]++;
        } else if ( j.type === "VariableDeclarator" ) {
          loop( j.init );
          // If we're setting the value of a param, without yet having used it
          // in any other way, assume it's meant as a return statement.
          if ( !returnParam && params.some( param => param.name === j.id.name ) && hits[ j.id.name ] === 0 ) {
            returnParam = j.id.name;
          }
        } else {
          // ISSUE: For-in ordering is implementation-dependent, and (in theory)
          // unstable. Options for stability include Object.keys.sort.
          // In practice, this works as intended on all existing JS engines.
          for ( var i in j ) {
            if ( j.type !== "MemberExpression" || i !== "property" ) {
              loop( j[ i ] );
            }
          }
        }
      }
    }
    loop( body );
    return returnParam;
  }
  
  function buildFunctionStatement( id, params, body, isExpression ) {
    // TODO: addVar( name.name ) one context level up.

    // TODO: This shouldn't run for constructors, or indirect-object arguments.
    var RParam = getReturnParam( params, body );
    if ( RParam ) {
      params = params.filter( x => x.name !== RParam );
      body = body.concat( {
         "type": "ReturnStatement",
         "argument": buildIdentifier( RParam )
      } );
    }

    returned = false;

    popContext();

    // Add function's id to context, unless there's already a
    // "undefined-constructor" fn already waiting.
    // (Should probably do an actual check here... TODO.)
    // TODO: Fix the issue that the var only gets created after the function is
    // complete. Probably fiddle with startFunction, add new "id" param or through options.
    //findVar( id.name ) || addVar( id.name );

    return {
      "type": isExpression ? "FunctionExpression" : "FunctionDeclaration",
      "id": id,
      "params": params,
      "body": {
        "type": "BlockStatement",
        //"body": flatten( s )
        "body": body
      },
      loc: loc()
    };
  }

  function buildExpressionStatement( exp ) {
    return {
      "type": "ExpressionStatement",
      "expression": exp,
      loc: loc()
    };
  }

  function buildIdentifier( name ) {
    return {
      type: "Identifier",
      name: name,
      loc: loc()
    };
  }

  function UnaryExpression( op, arg ) {
    return {
      "type": "UnaryExpression",
      "operator": op,
      "argument": arg,
      "prefix": true
    };
  }

  function expr( type, base, ...args ) {
    return ( ...args2 ) => {
      var r = { type, loc: loc() }, _args = args;
      if ( typeof base === 'string' ) {
        _args = [ base ].concat( _args );
      } else {
        Object.assign( r, base );
      }
      _args.forEach( ( p, i ) => r[ p ] = args2[ i ] );
      return r;
    };
  }

  // TODO.
  var exprs = ( () => {
    var r = {}, l = {
      'UnaryExpression': [ { prefix: true }, 'operator', 'argument' ],
      'ExpressionStatement': [ 'expression' ],
      'Identifier': [ 'name' ],
      'AssignmentExpression': [ 'left', 'operator', 'right' ],
      'MemberExpression': [ 'object', 'property', 'computed' ],
    };
    Object.keys( l ).forEach( x => r[ x ] = expr( x, ...l[ x ] ) );
    return r;
  } )();


  // There are a lot of groups needing flattening. Blocks have
  // lines/sentences which have PhraseGroupGroups which have phrase groups
  // which have phrases.
  // Could be activated in a {} inside the expression, though
  function flatten(array) {
    return [].concat.apply( [], array );
  }

  function constructorFormat( string ) {
    if ( string.name ) {
      //string.name = constructorFormat( string.name );
      return Object.assign( {}, string, { name: constructorFormat( string.name ) } );
    } else {
     string = string ? string[ 0 ].toUpperCase() + string.substr( 1 ) : '';
    }
    return string;
  }

  function nonConstructorFormat( string ) {
    if ( string.name ) {
      string.name = nonConstructorFormat( string.name );
    } else {
     string = string ? string[ 0 ].toLowerCase() + string.substr( 1 ) : '';
    }
    return string;
  }

  function ifWhileBlock( term, test, body, alt ) {
    var isIf = ( term & 1 ) === 0;
    if ( term & 2 ) {
      test = UnaryExpression( "!", test );
    }
    if ( isIf && !alt ) {
      returned = false;
    }
    var outer = {
        type: isIf ? "IfStatement" : "WhileStatement",
        test: test,
        //loc: loc()
      },
      block = {
        "type": "BlockStatement",
        "body": body instanceof Array ? body : [ body ]
      };
    return Object.assign( outer, isIf ?
      { consequent: block, alternate: alt || null } :
      { "body": block }
    );
  }

  function logicBlock( type ) {
    return function( left, right ) {
      return {
        "type": "LogicalExpression",
        "operator": type,
        "left": left,
        "right": right,
        loc: loc()
      };
    };
  }
  var orBlock  = logicBlock( '||' ),
      andBlock = logicBlock( '&&' );

  function andOrReduce( x, negation ) {
    // When doing "is not x or y", swap "and" and "or", per weird English.
    var order = negation ? [ orBlock, andBlock ] : [ andBlock, orBlock ];
    return x.map( x => x.reduce( order[ 0 ] ) ).reduce( order[ 1 ] );
  }

  var contextStack = [],
    // For pronouns
    lastUsed,
    tempLastUsed,
    returned = false;
    // How to deal with if ( x ) { return y; } else { ...? }

  function getContext() {
    return contextStack[ contextStack.length - 1 ];
  }
  function pushContext( options ) {
    contextStack.push( {
      block: [],
      vars: {},
      aliases: {},
      expectReturn: options && options.expectReturn,
    } );
  }
  function popContext() {
    return contextStack.pop();
  }
  function addVar( name, options ) {
    getContext().vars[ name ] = Object.assign( { type: 'var' }, options || {} );
  }
  function hasVar( name ) {
    return contextStack.some( s => {
      return name in s.vars;
    } );
  }
  function findVar( name ) {
    for ( var i = contextStack.length - 1; i >= 0; i-- ) {
      if ( contextStack[ i ].vars[ name ] ) {
        return contextStack[ i ].vars[ name ];
      }
    }
  }
  function setAlias( alias, value ) {
    getContext().aliases[ alias ] = value;
  }
  function getAlias( alias, value ) {
    // Should this search in the order direction? (More specific first.)
    for ( var i = 0; i < contextStack.length; i++ ) {
      var aliases = contextStack[ i ].aliases;
      // Don't break if alias = "constructor" or similar.
      if ( aliases.hasOwnProperty( alias ) ) {
        return aliases[ alias ];
      }
    }
  }
  function maybeRemember( val ) {
    tempLastUsed = val;
  }
  function solidifyRemember( val ) {
    lastUsed = val || tempLastUsed;
  }
  function useLast() {
    return lastUsed || buildIdentifier( "undefined" );
  }
  function getExpectedReturn() {
    // .find not supported in IE.
    //return contextStack.reverse().find( x => x.expectReturn );
    // ----
    for ( var i = contextStack.length - 1; i >= 0; i-- ) {
      var expectReturn = contextStack[ i ].expectReturn;
      if ( expectReturn ) {
        return expectReturn;
      }
    }
  }

  function startFunction( options ) {
    var ThisExpression = { "type": "ThisExpression" };

    // If an ID is supplied, mark it as a variable with type 'function' in the outer context.
    if ( options && options.id ) {
      addVar( options.id.name, { type: 'function' } );
    }

    // (This line needs to be before aliases, because setAlias operates on the current context.)
    pushContext( options );

    if ( options ) {
      if ( options.thisAlias ) {
        // PROBLEM: Nested functions mess up when attempting to call higher-
        // level "this". TODO: Fix.
        setAlias(
          nonConstructorFormat( options.thisAlias.name ),
          ThisExpression
        );
      }
    }
    solidifyRemember( options && options.rememberThis && ThisExpression );
  }

  pushContext();

  // DEPENDENCIES
  var dependencies = [],
    dependencyCode = {
      assert: 'var assert = window.assert || function ( ){ }'
    };
  // TODO: Consider just adding raw JS instead of doing this...
  function addDep( dep ) {

  }

  // LOCATIONS, for source maps.
  function loc() {
    return location();
  }

  // Weird constructor stuff.
  function fillFunction( target, fn ) {
    delete target.kind;
    delete target.declarations;
    return Object.assign( target, fn );
  }

  function constructorFallbackDefault( constructor ) {
    // We're doing something with a constructor that may not exist.
    // If it doesn't exist, add a "var C = window.C || function () {};"
    // This can be replaced later by actual constructor content if provided
    // later in the code.
    var returnValue = [],
      preexistingFn = findVar( constructor.name );

    if ( !preexistingFn ) {
      // The type might not exist. This'll be difficult.
      // First, (possibly-temporarily) define the function, with possibility
      // for simple global fallback.
      var fnDef = {
        "type": "VariableDeclaration",
        "declarations": [
          {
            "type": "VariableDeclarator",
            "id": constructor,
            "init": {
              "type": "LogicalExpression",
              "operator": "||",
              "left": {
                 "type": "MemberExpression",
                 "object": buildIdentifier( "window" ),
                 "property": constructor,
                 "computed": false
              },
              "right": {
                 "type": "FunctionExpression",
                 "id": constructor,
                 "params": [],
                 "body": {
                    "type": "BlockStatement",
                    "body": []
                 }
              }
            }
          }
        ],
        "kind": "var"
      };
      // Next, prepare things so that this function can be simply overridden by
      // later definition. (This will be done with fillFunction.)
      addVar( constructor.name, { "type": "undefined-constructor", node: fnDef } );
      returnValue.push( fnDef );
    }

    //returnValue.push( object );

    return returnValue;

  }

  // ...
  function ofAlias( id ) {
    var aliases = {
      'cosine': 'Math.cos',
      'sine': 'Math.sin',
      'tangent': 'Math.tan',
      // 'square root': 'Math.sqrt',
      // 'cube root': 'Math.cbrt',
      'arccosine': 'Math.acos',
      'arcsine': 'Math.asin',
      'arctangent': 'Math.atan'

    };
    if ( aliases[ id.name ] ) {
      var x = aliases[ id.name ].split( '.' );
      return x.slice( 1 ).reduce( ( x, y ) => ( {
        "type": "MemberExpression",
        "object": x,
        "property": buildIdentifier( y ),
        "computed": false
      } ), buildIdentifier( x[ 0 ] ) );
    } else {
      return id;
    }
  }

}

// --- START PARSER ---

Program
  = Header? body:SourceElements? {
      return {
        type: "Program",
        body: body ? body : [],
        dependencies: dependencies
      };
    }

Header
  = _ NoteBlock?

// Maybe merge this into Program? Or maybe leave it to deal with dependencies?
SourceElements
  = head:SourceElement tail:(_ SourceElement _)* {
      return flatten( buildList(head, tail, 1) );
    }

SourceElement
  = FullSentence // / Note

Block
  = DoTheFollowing p:PostIfWhile ":" _ NoteBlock*
  ( "first"i ","? ws )? s:SentenceLevelStatement
  ss:( !{ return returned; } EndFullSentence SentencePrefix SentenceLevelStatement )*
  sss:(
    & { return returned; } { return []; } /
    EndFullSentence Finally ","? ws sss:PhraseGroupGroup { return sss; } /
    EndFullSentence {
      return {
         "type": "ThrowStatement",
         "argument": {
            "type": "NewExpression",
            "callee": buildIdentifier( "Error" ),
            "arguments": [
               {
                  "type": "Literal",
                  "value": "Unclosed list of steps. The final step in the list should begin with \"Finally\" or similar."
               }
            ]
         }
      };
    }
  )
  {
    return p( flatten( buildList( s, ss, 3 ).concat( sss ) ) );
  }

// Capital to period.
FullSentence
  // TODO: Rework "Then"s so that they're only allowed when they make sense.
  = SentencePrefix s:SentenceLevelStatement EndFullSentence
    { return s }
  / QuestionBlock

SentencePrefix // TODO: Only allow each prefix where appropriate.
  = ( ( "First"i / "Then"i / "Next"i ) ","? ws )?
    ( !Finally )

DoTheFollowing
  = (
    "do the following"i /
    "take"i _ ( "the following" / "these" ) _ ( "steps"i / "actions"i ) /
    "follow these instructions"i / "do what follows"i / "do as follows"i
    //"do this"i
  )

Finally
  = "Finally"i / "Last"i / "Lastly"i / "To conclude"i

SentenceLevelStatement
  = DefineFunction
  / PhraseGroupGroup

EndFullSentence
  = SoThat? _ "." _ NoteBlock* / _ !.

PhraseGroupGroup
  = s:PhraseGroup ss:( ( !{ return returned; } SemicolonAndThen ) PhraseGroup)* {
    return flatten( buildList( s, ss, 1 ) );
  }

// Set of phrases, ex. as consequent or fn body.
PhraseGroup
  = s:Statement ss:( ( !{ return returned; } CommaAndThen ) Statement)* {
    //return buildList( s, ss, 1 )
    return flatten( buildList( s, ss, 1 ) );
  }

// Fragment, single clause (and associated block if applicable).
Statement
  = Block /
    NonBlockStatement

NonBlockStatement
  = LetStatement /
    IfStatement /
    WhileStatement /
    MathSetter /
    HaveOrder /
    DoNothing /
    DoAction

CommaAndThen // At least one of: "," "and" "then"
  = "," ( PlainAndThen / ws ) /
    PlainAndThen

SemicolonAndThen // At least one of: ";" "and" "then"
  = ";" ( PlainAndThen / ws ) /
    PlainAndThen

PlainAndThen
  = ws "and" ws ("then" ","? ws)? /
    ws "then" ","? ws

// --- CONDITIONS ---

Condition // In conditions, "is" means "===", "and" means "&&", etc.
  = ConditionOrExpression

ConditionOrExpression // cond or cond
  = c:ConditionAndExpression cc:( ( ws "or" ws ) ConditionAndExpression )* {
    return buildList( c, cc, 1 ).reduce( orBlock );
  }

ConditionAndExpression // cond and cond
  = c:ConditionOrOp cc:( And ConditionOrOp )* {
    return buildList( c, cc, 1 ).reduce( andBlock );
  }

ConditionOrOp
  = left:(
        // Need a bizarre pile of lookaheads to make "it's" work...
        PronounIsContraction !( ws "is" / MathCompareOpNoIs / ConditionUnaryOp ) { return useLast(); }
      / v:Value              &( ws "is" / MathCompareOpNoIs / ConditionUnaryOp ) { return v; }
    )
    c:ConditionAndOp cc:( ( ws "or" ) ConditionAndOp )*
  {
    var u = buildList( c, cc, 1 );
    return u.map( fn => fn( left ) ).reduce( orBlock );
  }

ConditionAndOp
  = c:ConditionPredicate cc:( ( ws "and" ) ConditionPredicate )* {
    var u = buildList( c, cc, 1 );
    return function ( left ) {
      return u.map( fn => fn( left ) ).reduce( andBlock );
    };
  }

ConditionPredicate // op right or right or op right or right. "is less than x or y or more than z"
    // Priorities: "exists" (not ='exists') > "is a x" > "x is x" > ...?
  = op:ConditionUnaryOp {
      return function ( left ) {
        return op( left );
      };
    }
    // This needs to take priority over MathCompareOp so that we don't get "=== new X()"
  / ConditionIsKW? negation:( "n't" / ws "not" WordBreak )? !MathCompareOp ws rights:ConditionOrIsV {
      return function ( left ) {
        var conditions = rights.map( x => x.map( y => y( left, negation ) ) );
        return andOrReduce( conditions, negation );
      };
    }
  / op:MathCompareOp rights:ConditionOrValue {
      return function ( left ) {
        var conditions = rights.map( x => x.map( right => BinaryExpression( left, op, right ) ) );
        return andOrReduce( conditions, op === '!==' );
      };
    }

ConditionIsKW
  = ws "is"

ConditionIsValue
    // Typeof checks
  = a ws type:PrimitiveType {
    return function ( left, negation ) {
      return BinaryExpression( UnaryExpression( "typeof", left ), negation ? "!==" : "===", {
        "type": "Literal",
        "value": type,
        "raw": '"' + type + '"'
      } );
    };
  } // Instanceof
  / a ws type:( compositeLiteralType / SimpleId ) {
    return function ( left, negation ) {
      var expr = BinaryExpression( left, "instanceof", constructorFormat( type ) );
      return negation ? UnaryExpression( "!", expr ) : expr;
    };
  }
    // In an array
  / "one of" ws right:Value {
    return function ( left, negation ) {
      var expr = {
        "type": "CallExpression",
        "callee": {
          "type": "MemberExpression",
          "object": right,
          "property": buildIdentifier( "includes" ),
          "computed": false
        },
        "arguments": [ left ]
      };
      return negation ? UnaryExpression( "!", expr ) : expr;
    };
  }
    // Simple equality
  / right:Value !"'" !ConditionOpLookahead {
    return function ( left, negation ) {
      return BinaryExpression( left, negation ? "!==" : "===", right );
    };
  }

ConditionOrIsV
  = right:ConditionAndIsV rights:( ( ws "or" ws ) ConditionAndIsV !ConditionOpLookahead )* {
    return buildList( right, rights, 1 );
  }

ConditionAndIsV
  = right:ConditionIsValue rights:( ( ws "and" ws ) ConditionIsValue !ConditionOpLookahead )* {
    return buildList( right, rights, 1 );
  }

ConditionOrValue // right or right
  = right:ConditionAndValue rights:( ( ws "or" ws ) ConditionAndValue !ConditionOpLookahead )* {
    return buildList( right, rights, 1 );
  }

ConditionAndValue // right and right
  = right:Value !"'" rights:( And Value !"'" !ConditionOpLookahead )* {
    return buildList( right, rights, 1 );
  }

ConditionOpLookahead
  = MathCompareOp / ConditionUnaryOp / ConditionIsKW

ConditionUnaryOp
  = ws "exists" {
      return left => left;
    }
  / ws "doesn't exist" {
      return left => UnaryExpression( "!", left );
    }


Expression
  = AdditiveExpression

// --- MATH ---

MathCompareOp // I think I lost the literal "=" op somewhere along the line.
    // Fake optional "is": required by earlier lookahead except for "it's".
  = ws ( "is" ws )? k:MathCompareKeyword ws "than"
      e:( ws "or equal" ( ws "to" )? )? ws
      { return k + ( e ? '=' : '' ); }
  / MathCompareOpNoIs
    // Fake optional "is": required by earlier lookahead except for "it's".
  / ( ws "is" )? negation:( ws "not" / "n't" )? ( ws "equal to" / ws "the same as" ) ws { return negation ? "!==" : "==="; }

MathCompareOpNoIs
  = _ o:$( [><]"="? ) _ { return o; }
  / ws "does" negation:( ws "not" / "n't" )? ws "equal" ws { return negation ? "!==" : "==="; }
  / ws "equals" ws { return "==="; }

// TODO: For "Is X Y?", etc. (Currently unused.)
MathCompareOpInvertedCase
  = ws

MathCompareKeyword
  = ( "more" / "higher" / "greater" / "larger" ) { return ">" }
  / ( "less" / "lower" ) { return "<" }

// TODO: Move this somewhere else.
MathSetter
  = l:MathSetterBinaryOp p:PostIfWhile { return p( buildExpressionStatement( {
      "type": "AssignmentExpression",
      "operator": l.op,
      "left": l.s,
      "right": l.v
     } ) ); }
  / l:MathSetterUnaryOp p:PostIfWhile  { return p( buildExpressionStatement( {
      "type": "UpdateExpression",
      "operator": l.op,
      "argument": l.s,
      "prefix": false
     } ) ); }

MathSetterBinaryOp
  // Maybe also allow "Make X Y more than before"? Would interfere with var.
  = ("Increment"i/"Increase"i) ws s:Setable ws "by" ws v:Value
      { return {s,v,op:"+="}; }
  / "Add"i ws v:Value ws "to" ws s:Setable { return {s,v,op:"+="}; }
  / ("Decrement"i/"Decrease"i) ws s:Setable ws "by" ws v:Value
      { return { s, v, op: "-=" }; }
  / "Subtract"i ws v:Value ws "from" ws s:Setable
      { return { s, v, op: "-=" }; }
  / "Multiply"i ws s:Setable ws "by" ws v:Value { return {s,v,op:"*="}; }
  / "Divide"i ws s:Setable ws "by" ws v:Value { return {s,v,op:"/="}; }

MathSetterUnaryOp
  = ("Increment"i/"Increase"i) ws s:Setable { return {s, op:"++"}}
  / ("Decrement"i/"Decrease"i) ws s:Setable { return {s, op:"--"}}

MultiplicativeExpression
  = head:SimpleValue
    tail:(ws MultiplicativeOperator ws SimpleValue)*
    { return buildBinaryExpression(head, tail); }

MultiplicativeOperator
  = ("multiplied by"/"times"/"*") { return "*"; }
  / ("divided by"/"over"/"/")     { return "/"; }

AdditiveExpression
  = head:MultiplicativeExpression
    tail:(ws AdditiveOperator ws MultiplicativeExpression)*
    { return buildBinaryExpression(head, tail); }

AdditiveOperator // "Added to"?
  = ("plus"/"more than"/"+")  { return "+"; }
  / ("minus"/"-") { return "-"; }
  // Concatenation. Should probably be handled differently, to
  // force toString: x followed by y > '' + x + y;
  / "followed by" { return "+"; }

// --- IF, WHILE, QUESTIONS ---
// TODO: Consider moving this above Conditions.

IfStatement
  = term:IfKW ws test:Condition
    cblock:ThenPhrase
    // If no return statement in consequent, don't end the block even if the
    // alternate has a return statement.
    ret:( !{} { var r = returned; returned = false; return r; } )
    // TODO: The punctuation rules here should be stricter.
    // Actually, maybe not. PG and PGG kind of enforce certain limits anyway.
    alt:Otherwise
  {
    if ( !ret ) {
      returned = false;
    }
    return ifWhileBlock( term, test, cblock, alt ? {
      "type": "BlockStatement",
      "body": alt
    } : null );
  }

WhileStatement
  = term:WhileKW ws test:Condition
    cblock:ThenPhrase
  {
    return ifWhileBlock( term, test, cblock );
  }

Otherwise // TODO, maybe: "If not", for otherwise. "Or else"?
  = (
    ( ( "." / ";" / "," )? ws ( "and" / "or" ) ws / ( "." / ";" / "," ) ws )
    "otherwise"i
    alt:(
      ( ","? ws ) PhraseGroup /
      ( ":" ws ) PhraseGroupGroup
    )
    { return alt[ 1 ]; }
  )?

// TODO: Assert block, for both.
QuestionBlock
  = QuestionIfBlock
  / QuestionIntBlock

QuestionIfBlock
  = test:QuestionIf ws cblock:QuestionThen alt:Otherwise
  {
    return ifWhileBlock( 0, test, cblock, alt );
  }

// TODO: Grammar. This currently doesn't work, bc Condition requires, ex.
// "Is X is Y?" "Does X is equal to Y?"
// Related to the issue with contractions ("it's", etc.).
QuestionIf
  = "Is"i ws test:Condition "?" { return test; }
  / "Does"i ws test:Condition "?" { return test; }

QuestionThen
  = "If so"i ","? ws cblock:PhraseGroupGroup EndFullSentence { return cblock; }

QuestionIntBlock
  = base:QuestionInt
  cases:( ws cases:QuestionIntIfIts+ defaultCase:QuestionIntIfOtherwise? {
    return defaultCase ? cases.concat( defaultCase ) : cases;
  } )?
  {
    if ( cases ) {
      return {
        "type": "SwitchStatement",
        "discriminant": base,
        "cases": cases
      };
    } else {
      return buildExpressionStatement( {
        "type": "CallExpression",
        "callee": {
          "type": "MemberExpression",
          "object": buildIdentifier( "console" ),
          "property": buildIdentifier( "log" ),
          "computed": false
        },
        "arguments": [ base ]
      } );
    }
  }

QuestionInt
  = ( "What"i / "Who"i ) ( ws "is" / "'s" ) ws value:Value "?" { return value; }

QuestionIntIfIts
  = "if it"i ( "'s" / ws "is" ) ws value:Value phrase:ThenPhrase EndFullSentence {
      return {
        "type": "SwitchCase",
        "test": value,
        "consequent": phrase.concat( {
          "type": "BreakStatement",
          "label": null
        } )
      };
  }

QuestionIntIfOtherwise
  = (
        "if"i ws ( "it's not" / "it isn't" ) ws "any of" ws
        ( "them" / ( "those" / "these" / "the above" ) ( ws "options" )? )
      / "otherwise"i
    )
    cblock:ThenPhrase EndFullSentence {
      return {
        "type": "SwitchCase",
        "test": null,
        "consequent": cblock
      };
    }

// TODO: Consider allowing this for Do the following blocks:
// ("When creating a x, x if x is x.")
// TODO: Allow "otherwise" for post-ifs.

PostIfWhile
  = ws term:IfWhileKW ws test:Condition {
      return ( o ) => ifWhileBlock( term, test, o );
    }
  / '' { return x => x }

IfWhileKW
  = IfKW / WhileKW

IfKW
  = "if"i                        { return 0; }
  / "unless"i                    { return 2; }

WhileKW
  = ( "while"i / "so long as"i ) { return 1; }
  / "until"i                     { return 3; }

ThenPhrase
  = ( ","? ws "then" ws / "," ws ) cblock:PhraseGroup { return cblock; }
  / ":" _ cblock:PhraseGroupGroup { return cblock; }

// --- VARIABLE ASSIGNMENT ---

LetStatement
  = st:( CreateCompositeLiteral / CreateStatement / VarStatement ) p:PostIfWhile {
    return p( st );
  }

// Lotsa duplication here, but I can't figure out any other way to do this.
// TODO: Array.pushUnique(), "Make x one of the ys."
VarStatement
  = l:(
      ( "let"i ws )
        Setable EqualKW CValue
          ( And Setable EqualKW CValue )* /
      ( "make"i ws )
        Setable ( ws ( "equal to" ) ws / EqualKW / ws ) CValue
          ( And Setable ( ws ( "equal to" ) ws / EqualKW / ws ) CValue )* /
      ( "set"i ws )
        // Setable ( ws ( "to be" / "to equal" / "to" / "as" ) ws ) CValue
        Setable ( ws "to" ( EqualKW / ws ) / ws "as" ws ) CValue
          // ( And Setable ( ws ( "to be" / "to equal" / "to" / "as" ) ws ) CValue )* /
          ( And Setable ( ws "to" ( EqualKW / ws ) / ws "as" ws ) CValue )* /
      ( "have"i ws )
        Setable EqualKW CValue
          ( And Setable EqualKW CValue )* /
      (_) Setable ( ws ( "equals" / "is equal to" / "is" ) ws / _"="_ ) CValue
    ) {

      return [
        [ l[ 1 ], l[ 3 ] ],
        ...( l[ 4 ] || [] ).map( x => [ x[ 1 ], x[ 3 ] ] )
      ].map( x =>
        buildLetStatement( x[ 0 ], x[ 1 ] )
      );
    }
  / ( "let's"i ws )? l:(
      // No CValues here because it sounds silly.
      // TODO Maybe: "Call x y and z q."
      // TODO: Merge the first parts of these lines outside of l?
      ( ( "call"i / "name"i ) ws ) Value ws Setable /
      ( ( "call"i / "name"i ) ws ) Value ws QuotableIdentifier /
      ( "refer"i ws "to"i ws ) Value ( ws "as"i ws ) QuotableIdentifier
    ) {
      return buildLetStatement( l[ 3 ], l[ 1 ] );
    }
    // ARRAY CONSTRUCTION
  / s:(
        ( ( "these"i / "the following"i ) ws "are"i ws ) Setable ( ":" ws )
      / (_) Setable ( ws "are" ws
          ( (
              ( "the following"i / "these"i )
            / a ws arrayLiteral ws "containing"i
          ) ":"? ws )?
        )
    )
    vals:(
      first:Value
      middle:( "," ws v:Value { return v; } )*
      last:( ","? And last:Value { return last; } )?
      {
        return [ first ].concat( middle, last || [] );
      }
    ) {
      return buildLetStatement( s[ 1 ], {
        "type": "ArrayExpression",
        "elements": vals
      } );
    }

EqualKW
  = ws ( "equal" / "be equal to" / "be" ) ws / _ "=" _

And
  = ( ws "and" ws ) !Keyword

// x = {}; x = [];
CreateCompositeLiteral
  = ( CreateKW / "there"i ( ws "is" / "'s" ) ) ws a ws c:compositeLiteral id:CreateCalled? {
      return buildLetStatement(
        id || buildIdentifier( c.text ),
        c.init
      );
    }

// x = new Y();
CreateStatement
  = ( CreateKW / "there"i ( ws "is" / "'s" ) ) ws c:Constructor id:CreateCalled? {
      var name = c.callee.name;
      return buildLetStatement(
        id || buildIdentifier( nonConstructorFormat( name ) ),
        c
      );
    }

CreateKW
  = "Make"i / "Build"i / "Create"i / "Set up"i / "Construct"i

CreatingKW
  = "making"i / "building"i / "creating"i / "setting up"i / "constructing"i

CreatedKW
  = "made"i / "built"i / "created"i / "set up"i / "constructed"i

CreateCalled // " which we'll call X". TODO: Merge with Called.
  = ( ","?  ws Called )
    ws id:QuotableIdentifier { return id; }


Called // Related: CallIt
  = (
      "called" /
      "named" /
      ( ( "that" / "which" ) ws (
        ( "we'll" / "we shall" / "we can" ) ws ( "call" / "name" / "designate as" / "refer to as" ) /
        ( "shall" / "will" ) ws "be" ws ( "called" / "named" / "referred to as" )
      ) )
    )

// --- DEFINING FUNCTIONS ---

DefineFunction
  = DefineGetFunction /
    DefineMethod /
    DefineConstructor /
    FunctionStatement /
    DefineSimpleGetFunction /
    PrototypeInherit /
    ConstructorDuplicate

FunctionStatement
  //= ("to do"i ws/"to"i ws) id:SimpleId params:ParamGroup
  = ("to do"i ws/"to"i ws) id:MultiwordVarLoose params:ParamGroup
  ( ":" ws / "," ws / ws "is to" ws )
  !{ startFunction( { id: id } ); } s:PhraseGroupGroup
  {
    return buildFunctionStatement( id, params, s );
  }

DefineConstructor
  = type:(
      ( ( "When"i ws CreatingKW / "To"i ws CreateKW ) ws type:TypeEntity { return type; } ) /
      ( ( "When"i / "Every time"i ) ws type:TypeEntity ws "is" ws CreatedKW { return type; } )
    )
    params:ParamGroupRequirePreposition "," ws
    !{ startFunction( { thisAlias: type, rememberThis: true, id: constructorFormat( type ) } ); }
    s:PhraseGroupGroup
    {
      type = constructorFormat( type );
      var fnStatement = buildFunctionStatement( type, params, s ),
        pre = findVar( type.name );
      if ( pre && pre.type === "undefined-constructor" ) {
        fillFunction( pre.node, fnStatement );
        return [];
      } else {
        return fnStatement;
      }
    }

// TODO: Allow "A X can Y by doing the following:"
// No wait, that would force the whole block toward the present tense.
DefineMethod
  = type:(
      "For"i ws type:PrototypeOrValue ws "to" { return type; } /
      "To have"i ws type:PrototypeOrValue { return type; }
    )
  ws method:SimpleId params:ParamGroup ( "," / ":" ) ws
  !{ startFunction( { thisAlias: type.alias, rememberThis: true } ); }
  s:PhraseGroupGroup
  {
    var q = buildExpressionStatement( {
      "type": "AssignmentExpression",
      "operator": "=",
      "left": {
        "type": "MemberExpression",
        "object": type.val,
        "property": method,
        "computed": false
      },
      "right": buildFunctionStatement( method, params, s, true )
    } );
    return type.extras.concat( q );
  }

PrototypeOrValue // Needs to return an array, a "this" alias, and a value.
  = type:TypeEntity {
      var constructor = constructorFormat( type );
      var r = constructorFallbackDefault( constructor );
      var val = {
        "type": "MemberExpression",
        "object": constructor,
        "property": buildIdentifier( "prototype" ),
        "computed": false
      };
      return { extras: r,  val: val, alias: type };
    }
  / val:PropGet {
      return { extras: [], val: val, alias: val.property };
    }
  / val:Identifier {
      return { extras: [], val: val, alias: val };
    }

DefineGetFunction
  = "to get"i ws id:Identifier ws "of" params:ParamGroupNoPreposition
  ( "," / ":" ) ws
  !{ startFunction( { expectReturn: id.name, id: id } ); }
  s:PhraseGroupGroup
  //!{ popContext(); returned = false; }
  {
    return buildFunctionStatement( id, params, s );
  }

DefineSimpleGetFunction // Maybe solidifyRemember here.
  = id:Identifier ws "of" args:ParamGroupNoPreposition ws "is" ws
  !{ startFunction(); }
  v:CValue
  // Should args be remembered?
  {
    return buildFunctionStatement( id, args, [ {
        "type": "ReturnStatement",
        "argument": v
    } ] );
  }

/*
PrototypeValue // Is this really necessary?
  = type:TypeEntity "'s" ws prop:SimpleId
*/

PrototypeInherit
  // Should this attach this.call( parentClass ) to the function body?
  // (Completely possible to do, without much difficulty.)
  // Long-term TODO: ", which is ...".
  // TODO: "Every X is a y". (Maybe just change/fork TypeEntity, bc that might
  // also apply to other uses.)
  = type:TypeEntity ws "is" ws a ( ws ( "kind" / "type" ) ws "of" )? ws parent:SimpleId {
    type = constructorFormat( type );

    var xx = buildExpressionStatement( {
        "type": "AssignmentExpression",
        "operator": "=",
        "left": {
          "type": "MemberExpression",
          "object": type,
          "property": buildIdentifier( 'prototype' ),
          "computed": false
        },
        "right": {
          "type": "CallExpression",
          "callee": {
            "type": "MemberExpression",
            "object": buildIdentifier( 'Object' ),
            "property": buildIdentifier( 'create' ),
            "computed": false
          },
          "arguments": [ {
            "type": "MemberExpression",
            "object": constructorFormat( parent ),
            "property": buildIdentifier( 'prototype' ),
            "computed": false
          } ]
        }
      } );


      return constructorFallbackDefault( type ).concat( xx );
  }

ConstructorDuplicate
  = type:TypeEntity ws "is the same thing as" ws targetType:TypeEntity {
      return buildLetStatement( constructorFormat( type ), constructorFormat( targetType ) );
    }

// - ARGUMENTS, PARAMETERS

// TODO: Only allow preps after objects.
ParamGroup // TODO: Only allow "and" after first param.
//  = s:( ( ( ws "and" )? ( ws ArgPreposition / "" ) ) ( SingleParam ) )* {
  = noprep:ParamGroupNonPrepositional? prep:ParamGroupRequirePreposition {
    return ( noprep || [] ).concat( prep );
  }

// For constructors. Can't have "When making a X Y".
ParamGroupRequirePreposition
  = params:( s:ParamGroupPrepGroup ss:( ( ws "and" )? ParamGroupPrepGroup )* {
      return s.concat( ...ss.map( x => x[ 1 ] ) );
    } )? {
      return params || [];
    }

ParamGroupPrepGroup
  = ws ArgPreposition s:SingleParam ss:( ( ws "and" ) SingleParam )* {
      return buildList( s, ss, 1 );
    }

// Only use this for "ofs", too greedy otherwise.
ParamGroupNoPreposition
  = s:SingleParam ss:( ( ( "," )? ws "and" / "," ) SingleParam )* {
    return buildList( s, ss, 1 );
  }

ParamGroupNonPrepositional // Issue: Anything after "and" can't be a returnvalname anyway.
  = s:SingleParam ss:( ( ws "and" )? SingleParam )* {
    return buildList( s, ss, 1 );
  }

SingleParam
  = ws ( "a thing" / "something" / "someone" )
    name:ParamName?
    {
      var s = name ? name : buildIdentifier( "thing" );
      maybeRemember( s );
      return s;
    }
  / ws type:TypeEntity name:ParamName? {
      var s = name || type;
      // TODO: Actual type check.
      maybeRemember( s );
      return s;
    }

ParamName
  = ws "(" _ ("let's" ws)? id:CallIt "\)"
  {
    return id;
  }
  / ws Called ws id:QuotableIdentifier {
    return id;
  }
  / ws "(" _ Called ws id:QuotableIdentifier _ ")" {
    return id;
  }

CallIt
  = ( ( "call" / "name" ) ws "it" / "refer to it as" ) ws id:QuotableIdentifier {
    return id;
  }

// TODO: MAJOR CLEANUPS in this area. Everything's a mess.

// NEW RULE: Preps come after non-preps.
ArgGroup // TODO: "X Y and Z".
  = s:ArgGroupNonPrep ss:ArgGroupRequirePreposition call:CallItVar {
    var r = call || false;
    // TODO: Fix the "X a Y with Z" bug. SingleArg calls Constructor which
    // swallows prep arguments.
    // (Is this^ fixed?)

    //r = r || ( s.varBind ? s.args.splice( s.args.indexOf( s.varBind ), 1 )[ 0 ].callee : false );
    var aBound = s.varBind && s.args.splice( s.args.indexOf( s.varBind ), 1 )[ 0 ].callee;
    r = r || aBound;
    return {
      varBind: x => r ?
        buildLetStatement( nonConstructorFormat( r ), x ) :
        buildExpressionStatement( x ),
      args: s.args.concat( ss )
    };
  }

ArgGroupNoPreposition // Specifically for "of"s, doesn't allow indirect objects.
  = s:SingleArg ss:( ( ( "," )? ws "and" / "," ) ( SingleArg ) )* {
    return buildList( s, ss, 1 );
  }

ArgGroupNonPrep
  = argGroups:(
      !( ws ArgPreposition )
      s:( SimpleConstructor / SingleArg )
      ss:( ( ( ws "and" ) !( ws ArgPreposition ) ) ( SimpleConstructor / SingleArg ) )*
      { return buildList( s, ss, 1 ); }// [ s ].concat( ss.map( sss => sss[ 1 ] ) );
    )*
    {
      var r, allArgs = [].concat( ...argGroups );

      argGroups.some( argGroup => r = !argGroup[ 1 ] && argGroup[ 0 ].type === "NewExpression" && argGroup[ 0 ] );

      return { varBind: r, args: allArgs };
    }
  / '' { return { args: [] }; }

// "with x and with y"
ArgGroupRequirePreposition
  = args:(
      s:ArgGroupPrepGrouping ss:( ( ws "and" )? ArgGroupPrepGrouping )* {
        return s.concat( ...ss.map( x => x[ 1 ] ) );
      }
    )? {
      return args || [];
    }

// "with the x y and a z and a b c"
ArgGroupPrepGrouping
  = s:SingleArgWithPreposition ss:( ( ws "and" ) PostPrepArg )* {
      //return s.concat( ss.map( x => x[ 1 ] ) );
      return buildList( s, ss, 1 );
    }

// To consider: "X as the Y".
SingleArgWithPreposition
  = ws ArgPreposition ws s:( ( !( a ws ) ) Identifier ws s:Value { return s; } / SimpleConstructor / Value ) {
      return s;
    }

PostPrepArg
  = ws s:( !( a ws ) Identifier ws s:Value { return s; } / Value ) {
      return s;
    }

SingleArg
  = ws !("and" ws) s:( SimpleConstructor / Value ) { return s }

// Unused.
SingleArgNoPreposition
  = ws !( "and" ws ) s:Value {
      return { mayReturn: true, val: s };
    }

ArgPreposition
  = ( "by" / "to" / "with" / "on" / "in" ) & ws

// --- CALLING FUNCTIONS ---

DoAction
= ("do"i ws)?
  s:MultiwordVarStrict args:ArgGroup p:PostIfWhile
  {
    var f = {
      "type": "CallExpression",
      "callee": s,
      "arguments": args.args
    };
    return p( args.varBind( f ) );
  }

CallItVar // "CreateCalled" doesn't really fit for non-a situations here...
  = ( CommaAndThen id:CallIt { return id; } / CreateCalled )?

HaveOrder
  = id:(
      "Have"i ws id:Value { return id; } /
      id:Value ws ( "should" / "must" ) { return id; }
    )
    ws method:SimpleId args:ArgGroup p:PostIfWhile {
      return p( args.varBind( {
        "type": "CallExpression",
        "callee": {
          "type": "MemberExpression",
          "object": id,
          "property": method,
          "computed": false
        },
        "arguments": args.args,
        loc: loc()
      } ) );
    }

// Only for actually building.
Constructor
  = a ws id:RawSimpleId args:ArgGroupRequirePreposition { return {
      "type": "NewExpression",
      "callee": constructorFormat( id ),
      "arguments": args,
      loc: loc()
    }; }


SimpleConstructor
  = a ws id:RawSimpleId { return {
      "type": "NewExpression",
      "callee": constructorFormat( id ),
      "arguments": [],
      loc: loc()
    }; }

// TODO: "Get X of Y, call it Z." "Get X of Y."

CallGetFunction
  = id:Identifier ws "of" args:ArgGroupNoPreposition {
      id = ofAlias( id );
      return {
        "type": "CallExpression",
        "callee": id,
        "arguments": args
      };
    }

DoNothing
  = ( "do nothing"i / ( "don't"i / "do not"i ) ws Statement ) { return []; }

// --- VALUES ---

CValue
  = ConditionalValue
  / Value

Value
  = Expression /
    SimpleValue

// Currently only used in Expressions themselves, to prevent loops.
SimpleValue
= CallGetFunction /
  Literal /
  PropGet /
  CompositeLiteralConstructor /
  Constructor /
  Identifier

ConditionalValue
  = v:Value ws "if" ws c:Condition
  ( ","? ws ( ( "and" / "or" ) ws )? / "," ws )
  // TODO: Work for "or else"
  av:( av:Value ws "otherwise" { return av; } / "otherwise" ws av:Value { return av; } )
  {
    return {
      "type": "ConditionalExpression",
      "test": c,
      "consequent": v,
      "alternate": av
    };
  }

// --- LITERALS ---

Literal
  = v:( stringLiteral / numberLiteral ) { return {
      "type": "Literal",
      value: v,
      // astring requires this. It's not part of the estree spec.
      // TODO: Fix this for English number literals.
      //raw: text()
    }; }

// Literals and Primitive types
stringLiteral
  // Line breaks being allowed is deliberate, as is lack of escape rules.
  = '"' s:([^"]*) '"' { return s.join(""); }
  / "'" s:([^']*) "'" { return s.join(""); }

numberLiteral
  = s:$( "-"? [0-9]+("."[0-9]+)?) { return parseFloat( s ); }
  / s:stringNumber WordBreak { return s; }

// Numbers
// TODO: Fractions, maybe 'point ...', uh... Also, condense this.
// Maybe also allow commas after things like thousands.
stringNumber
  = i:stringNumberInteger
    f:(
        // PROBLEM: "One hundred and one quarter" breaks. Need more lookaheads somewhere.
        ws f:stringNumberFraction s:'s'? &{ return ( i === 1 ) === !s } {
          return i / f;
        }
      / And ii:( stringNumberInteger / a { return 1 } ) ws
        f:stringNumberFraction s:'s'? &{ return ( ii === 1 ) === !s } {
          return i + ii / f;
        }
      // / !( And stringNumberFraction )
    )?
    {
      return f || i;
    }
  / a ws f:stringNumberFraction { return 1 / f; }
  / "zero" { return 0; }

stringNumberInteger
  = stringNumberBaseThousandPlus

stringNumberGroupUnit
  = t:( stringNumberTeen / stringNumberBaseOne ) ( '-' / ws ) { return t; }
  / 'a' ws { return 1; }

stringNumberBaseOne
  = t:( 'one'i / 'two'i / 'three'i / 'four'i / 'five'i / 'six'i / 'seven'i
    / 'eight'i / 'nine'i
  ) WordBreak {
    return ( 'one|two|three|four|five|six|seven|eight|nine'
      ).split( '|' ).indexOf( t.toString().toLowerCase() ) + 1;
  }

stringNumberTeen
  = t:stringNumberTeenUnit WordBreak {
    return t;
  }

stringNumberTeenUnit
  = t:$( 'ten'i / 'eleven'i / 'twelve'i / ( 'thir'i
        / 'four'i / 'fif'i / 'six'i / 'seven'i / 'eigh'i / 'nine'i ) 'teen'i
  ) {
    return ( 'ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen' +
        '|eighteen|nineteen'
      ).split( '|' ).indexOf( t.toString().toLowerCase() ) + 10;
  }

stringNumberBaseTen
  = t:stringNumberBaseTenUnit 'ty'i o:( ( '-' / ' ' ) stringNumberBaseOne )? WordBreak {
    return t +
      ( o ? o[ 1 ] : 0 );
  }
  / stringNumberTeen
  / stringNumberBaseOne

stringNumberBaseTenUnit // 'twen' + -'ty' / -'tieth'
  = t:( 'twen'i / 'thir'i / 'for'i / 'fif'i / 'six'i / 'seven'i / 'eigh'i
    / 'nine'i
  ) {
    return ( 'twen|thir|for|fif|six|seven|eigh|nine'
      .split( '|' ).indexOf( t.toString().toLowerCase() ) + 2 ) * 10;
  }

stringNumberBaseHundred
  = u:stringNumberGroupUnit 'hundred' t:( ( ws 'and' ws / '-' / ws ) stringNumberBaseTen )? WordBreak {
    return u * 100 + ( t ? t[ 1 ] : 0 );
  }
  / stringNumberBaseTen

stringNumberBaseThousandPlus
  = u:( h:stringNumberBaseHundred ws { return h; } / stringNumberGroupUnit )
    base:stringNumberBaseThousandPlusUnit WordBreak
    t:( ( ws 'and' ws / '-' / ws ) stringNumberBaseThousandPlus )? {
      if ( t && t[ 1 ] ) {
        if ( t > base ) {
          // ERROR. TODO.
        }
      }
      return u * base + ( t ? t[ 1 ] : 0 );
    }
  / stringNumberBaseHundred

stringNumberBaseThousandPlusUnit
  = 'thousand' { return 1000; }
  / s:( s:(
      'm'i / 'b'i / 'tredec'i / 'tr'i / 'quadr'i / 'quint'i / 'sext'i /
      'sept'i / 'oct'i / 'non'i / 'dec'i / 'undec'i / 'duodec'i
    ) {
        return Math.pow( 1000, (
          'm|b|tr|quadr|quint|sext|sept|oct|non|dec|undec|duodec|tredec'
        .split( '|' ).indexOf( s.toString().toLowerCase() ) + 2 ) );
    } )
    'illion' { return s; }

// TODO. Use ordinal grouping. Maybe use together with the "next" things, and "slots".
// WIP.
// Ambiguous is "one hundred and two fifths", need lookaheads.
stringNumberFraction
  = 'half' { return 2; }
  / 'quarter' { return 4; }
  / stringNumberFractionUnit

stringNumberFractionUnit
  = stringNumberOrdinal

ordinalNumber
  = stringNumberOrdinal
  / n:$[0-9]+ ( "st"i / "nd"i / "rd"i / "th"i ) { return n; }

stringNumberOrdinal
  = stringNumberOrdinalBaseHigher / stringNumberOrdinalBaseTen / stringNumberOrdinalTeen / stringNumberOrdinalBaseOne

stringNumberOrdinalBaseOne
  = t:( 'first'i / 'second'i / 'third'i / 'fourth'i / 'fifth'i / 'sixth'i
      / 'seventh'i / 'eighth'i / 'ninth'i
  ) {
    return ( 'first|second|third|fourth|fifth|sixth|seventh|eighth|ninth'
      ).split( '|' ).indexOf( t.toString().toLowerCase() ) + 1;
  }

/*
stringNumberOrdinalTeen
  = t:( 'tenth'i / 'eleventh'i / 'twelfth'i / 'thirteenth'i / 'fourteenth'i
      / 'fifteenth'i / 'sixteenth'i / 'seventeenth'i / 'eighteenth'
      / 'nineteenth'i
  ) {
    return ( 'tenth|eleventh|twelfth|thirteenth|fourteenth|fifteenth|sixteenth'
      + '|seventeenth|eighteenth|nineteenth' ).split( '|' ).indexOf( t.toString().toLowerCase() ) + 10;
  }
*/

stringNumberOrdinalTeen
  = t:( stringNumberTeenUnit / 'twelf' { return 12; } ) 'th'i { return t; }

stringNumberOrdinalBaseTen
  = t:stringNumberBaseTenUnit 'tieth'i { return t; }

stringNumberOrdinalBaseHigher
  = s:( 'hundred' { return 100; } / stringNumberBaseThousandPlusUnit ) 'th' { return s; }

compositeLiteral
  = t:arrayLiteral  WordBreak { return { type: 'array', text: t, init: {
      "type": "ArrayExpression",
      "elements": []
    } }; }
  / t:objectLiteral WordBreak { return { type: 'object', text: t, init: {
      "type": "ObjectExpression",
      "properties": []
    } }; }

compositeLiteralType
  = c:compositeLiteral { return buildIdentifier( c.type ); }

CompositeLiteralConstructor
  = a ws c:compositeLiteral { return c.init; }

arrayLiteral
  = "group"i / "list"i / "array"i

objectLiteral
  = "thing"i / "object"i


// --- TYPES ---

a
  = "a"i ("n" "other"?)?

TypeEntity
  = a ws type:SimpleId { return type; }

PrimitiveType = NumberType / StringType
NumberType = ( "number" / "amount" / "quantity" ) { return "number"; }
StringType = ( "string" / "sentence" / "phrase" / "word" / "text" )
  { return "string"; }

// --- IDENTIFIERS, PROPERTIES ---

Identifier
  = Pronoun
  / The? v:SimpleId {
    //return { "type": "Identifier", "name": text().replace( ' ', '_' ) };
    maybeRemember( v );
    return v;
  }

SimpleId // Should these accept numbers in non-initial characters?
  // For some reason, this is matching characters like "\".
  = !( Keyword ( [^A-Za-z_] / !. ) )
    v:$([A-Za-z_] [A-Za-z0-9_]*) {
      var name = nonConstructorFormat( v );
      return getAlias( name ) || buildIdentifier( name );
    }

RawSimpleId
  = !( Keyword ( [^A-Za-z_] / !. ) )
    v:$([A-Za-z_]+) {
      var name = nonConstructorFormat( v );
      return buildIdentifier( name );
    }

QuotableIdentifier
  = Identifier
  / ( '"' The / The '"' / '"' ) s:SimpleId '"' { return s; }
  / ( "'" The / The "'" / "'" ) s:SimpleId "'" { return s; }

The // TODO: Consider whether "this"/"that" should be "the"s, pronouns, or somehow both.
  = ( "the"i / "this"i ) ws

Keyword
  = ( IfKW / WhileKW / ArgPreposition / "do"i / "otherwise"i / "and"i / "or"i / "make"i /
      "have"i / "set"i / "the"i / "get"i / "is"i / "does" / "doesn't" / "exist" /
      "exists" / MathCompareKeyword / "equals" / "equal" / "as" / "same" /
      "for"i / "then"i / "so"i
    )

Pronoun // PROBLEM: "her" is ambiguous from possessive. Breaks for example, To eat a person, have her bah. TODO.
  = ( "it"i / "him"i / "her"i / "he"i / "she"i / "that"i ) WordBreak !"'"
      { return useLast(); }

PronounIsContraction
  = "it's" / "he's" / "she's"

PropGet // I really dislike this PossessivePronoun hack. TODO: Change.
  = !PronounIsContraction
    id:( &PossessivePronoun { return useLast(); } / Identifier )
    props:(
        ( "'s" / PossessivePronoun ) ws num:NumSlot   { return [ num, true ]; }
      / ( "'s" / PossessivePronoun ) ws p:RawSimpleId { return [ p, false ]; }
    )+ {
      return props.reduce(
        ( object, prop ) => exprs.MemberExpression( object, ...prop ),
        id
      );
    }

NumSlot
  = n:ordinalNumber ws slot {
    return {
      "type": "Literal",
      value: parseInt( n ) - 1
    };
  }

slot
  = "slot" / "spot" / "entry"

PossessivePronoun // TODO: "her" doesn't work bc of ambiguity with non-possessive.
  = ( "its"i / "his"i / "her"i / "their"i ) WordBreak

Setable = Pronoun / PropGet / Identifier

AccessIdent // Unused
  // Requires ! followed by any valid later tokens.
  // Actually, more like !{ check all variables and stuff }
  = [A-z_ ]+ & { x = arguments; } { return arguments; }

// WIP. Should notice issues, and notice when hitting a full existing var name.
// Should work with Setable/pronouns/etc.
// Currently unused.
MultiwordVarLoose
  = The? v:MWVLPart {
    return v;
  }

MWVLPart
  = v:$( [A-Za-z_]+ ) l:( ws !( !The Keyword / a WordBreak ) MWVLPart )? {
    var name = nonConstructorFormat( v ) + ( l ? constructorFormat( l[ 2 ] ).name : '' );
    return getAlias( name ) || buildIdentifier( name );
  }

// Only match previously established multi-word variables.
// Requires a different model than loose. Can be used for some calls.
// Still unclear what to do for x.y();s, unless those are also tracked.
MultiwordVarStrict
  = The? start:( t:$[A-Za-z_]+ { return nonConstructorFormat( t ); } ) name:(
      // TODO: Rewrite this.
        p1:MWVSPart p2:MWVSPart p3:MWVSPart &{ return hasVar( start + p1 + p2 + p3 ); }
          { return start + p1 + p2 + p3; }
      / p1:MWVSPart p2:MWVSPart &{ return hasVar( start + p1 + p2 ); }
            { return start + p1 + p2; }
      / p1:MWVSPart &{ return hasVar( start + p1 ); }
            { return start + p1; }
      / "" { return start; }
    )? {
    return getAlias( name ) || buildIdentifier( name );
  }

MWVSPart
  = ws ( &The / !Keyword ) c:$[A-Za-z_]+ { return constructorFormat( c ); }

// --- WHITESPACE, COMMENTS ---

// - Comments
InlineNote
  = "(Note"i ( ":" / ws "that" ) [^\)]+ ")"

NoteBlock // Should this also allow "Note that"?
  = "Note"i "s"? ":" [^\n]* ( _ NoteBlockPoint )* _
  / ( _ NoteBlockPoint )+ _

NoteBlockPoint
  = "*" [^\n]+

SoThat // TODO: Consider allowing just "so". Problem with that: "so long as".
  = ws "so"i ws "that"i ws [^,;\.]+

// - Whitespace
WordBreak
  = ![A-Za-z_]

ws
  = ( [ \t\n\r] / InlineNote )+

_ "whitespace"
  = ( [ \t\n\r] / InlineNote )*
