// Lots copied from
// https://github.com/pegjs/pegjs/blob/master/examples/javascript.pegjs
// TODO: error handling, ...
//
// Note for later: It technically is possible to modify earlier stuff, by
// storing the JSON array/object and then modifying it in JS directly.
// When updating the parser, remember to change the "module" stuff
// to "parser".

// I still have no plan for how to send functions as arguments.



{  
  function buildList(head, tail, index) {
    return [head].concat(extractList(tail, index));
  }

  function extractList(list, index) {
    var result = new Array(list.length), i;

    for (i = 0; i < list.length; i++) {
      result[i] = list[i][index];
    }

    return result;
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
        addVar( name.name );
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

  function buildFunctionStatement( id, params, body, expression ) {
    return {
      "type": expression ? "FunctionExpression" : "FunctionDeclaration",
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
    }
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
        "body": body
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
    }
  }
  var orBlock  = logicBlock( '||' ),
      andBlock = logicBlock( '&&' );

  function andOrReduce( x ) {
    return x.map( x => x.reduce( andBlock ) ).reduce( orBlock );
  }

  var contextStack = [],
    // For pronouns
    lastUsed,
    tempLastUsed,
    returned = false;
    // How to deal with if ( x ) { return y; } else { ...? }

  function pushContext( options ) {
    contextStack.push( { vars: {}, aliases: {}, expectReturn: options && options.expectReturn } );
  }
  function popContext() {
    contextStack.pop();
  }
  function addVar( name, options ) {
    contextStack[ contextStack.length - 1 ].vars[ name ] = options || { type: 'var' };
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
    contextStack[ contextStack.length - 1 ].aliases[ alias ] = value;
  }
  function getAlias( alias, value ) {
    // Should this search in the order direction? (More specific first.)
    for ( var i = 0; i < contextStack.length; i++ ) {
      var aliasValue = contextStack[ i ].aliases[ alias ];
      if ( aliasValue ) {
        return aliasValue;
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
    return lastUsed;
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
    var TE = { "type": "ThisExpression" };
    pushContext( options );
    if ( options && options.thisAlias ) {
      setAlias(
        nonConstructorFormat( options.thisAlias.name ),
        TE
      );
    }
    solidifyRemember( options && options.rememberThis && TE );
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
                 "object": {
                    "type": "Identifier",
                    "name": "window"
                 },
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

}

// --- START PARSER ---

Program
  = Body

Body
  = Header? body:SourceElements? {
      return {
        type: "Program",
        body: body ? body : [],
        dependencies: dependencies
      };
    }

Header
  = _ NoteBlock

SourceElements
  = head:SourceElement tail:(_ SourceElement _)* {
      return flatten( buildList(head, tail, 1) );
    }

SourceElement
  = FullSentence // / Note

Block
  = "do the following:"i _ NoteBlock*
  ( "first"i ","? ws )? s:SentenceLevelStatement
  ss:( !{ return returned; } EndFullSentence SentencePrefix SentenceLevelStatement )*
  sss:(
    & { return returned; } { return []; } /
    EndFullSentence "Finally"i ","? ws sss:PhraseGroupGroup { return sss; }
  )
  {
    return flatten( buildList( s, ss, 3 ).concat( sss ) );
  }

// Capital to period.
FullSentence
  // TODO: Rework "Then"s so that they're only allowed when they make sense.
  = SentencePrefix s:SentenceLevelStatement EndFullSentence
    { return s }
  / QuestionBlock

SentencePrefix // TODO: Only allow each prefix where appropriate.
  = ( ( "First"i / "Then"i / "Next"i ) ","? ws )?
    ( !"Finally"i )

SentenceLevelStatement
  = DefineFunction
  / PhraseGroupGroup

EndFullSentence
  = _ "." _ NoteBlock* / _ !.

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
  = c:ConditionOrOp cc:( ( ws "and" ws ) ConditionOrOp )* {
    return buildList( c, cc, 1 ).reduce( andBlock );
  }

ConditionOrOp
  = left:Value c:ConditionAndOp cc:( ( ws "or" ) ConditionAndOp )* {
    var u = buildList( c, cc, 1 );
    return u.map( fn => fn( left ) ).reduce( orBlock );
  }

ConditionAndOp
  = c:ConditionPredicate cc:( ( ws "and" ) ConditionPredicate )* {
    var u = buildList( c, cc, 1 );
    return function ( left ) {
      return u.map( fn => fn( left ) ).reduce( andBlock );
    }
  }

ConditionPredicate // op right or right or op right or right
    // COMPLICATED: Should allow "If X is Y or a Z or a number", combining types.
  = ConditionIsKW ws rights:ConditionOrIsV {
      return function ( left ) {
        var conditions = rights.map( x => x.map( y => y( left ) ) );
        return andOrReduce( conditions );
      }
    }
  / op:ConditionMathOp rights:ConditionOrValue {
      return function ( left ) {
        var conditions = rights.map( x => x.map( right => op( left, right ) ) );
        return andOrReduce( conditions );
      }
    }
  / op:ConditionUnaryOp {
      return function ( left ) {
        return op( left );
      }
    }

ConditionIsKW
  = ws "is"

ConditionIsValue
  = a ws type:PrimitiveType {
    return function ( left ) {
      return BinaryExpression( UnaryExpression( "typeof", left ), "===", {
        "type": "Literal",
        "value": type,
        "raw": '"' + type + '"'
      } );
    }
  } // Instanceof
  / a ws type:( compositeLiteralType / SimpleId ) {
    return function ( left ) {
      return BinaryExpression( left, "instanceof", constructorFormat( type ) );
    };
  }
  // Remember to lookahead for ops, avoid the "x is more ...." > "x === more" problem.
  / right:Value {
    return function ( left ) {
      return BinaryExpression( left, "===", right );
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
  = right:Value rights:( ( ws "and" ws ) Value !ConditionOpLookahead )* {
    return buildList( right, rights, 1 );
  }

ConditionOpLookahead
  = ConditionMathOp / ConditionUnaryOp / ConditionIsKW

ConditionMathOp // op
  = op:MathCompareOp {
    return ( left, right ) => BinaryExpression( left, op, right );
  }

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

// TODO: Add "not" support" "If x is not a y, ..."
MathCompareOp
  = ws ( "is" ws )? k:MathCompareKeyword ws "than"
      e:( ws "or equal" ( ws "to" )? )? ws
      { return k + ( e ? '=' : '' ); }
  / _ o:$( [><]"="? ) _ { return o; }
  / ( ws ( // TODO: Do something with this so "and"/"or" aren't messed up.
          ( "doesn't" / "does not" ) ws "equal" / 
          ( "is not" / "isn't" ) ( ws "equal to" / ws "the same as" / "" )
        ) ws )
      { return "!=="; }
  / ( ws ( "equals" / "is equal to" / "is the same as" / "is" ) ws / _"="_ )
      { return "==="; }

// TODO: For "Is X Y?", etc.
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

AdditiveOperator
  = ("plus"/"+")  { return "+"; }
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

Otherwise
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
QuestionIf
  = "Is"i ws test:Condition "?" { return test; }
  / "Does"i ws test:Condition "?" { return test; }

QuestionThen
  = "If so"i ","? ws cblock:PhraseGroupGroup EndFullSentence { return cblock; }

QuestionIntBlock // TODO: Logs. (IntBlocks without cases.)
  = base:QuestionInt ws cases:QuestionIntIfIts+ defaultCase:QuestionIntIfOtherwise? {
    return {
      "type": "SwitchStatement",
      "discriminant": base,
      "cases": defaultCase ? cases.concat( defaultCase ) : cases
    }
  }

QuestionInt
  = ( "What"i / "Who"i ) ws "is" ws value:Value "?" { return value; }
  
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
  = "if"i ws ( "it's not" / "it isn't" ) ws "any of" ws 
    ( "these" / "them" / "the above" " options"? )
    cblock:ThenPhrase EndFullSentence {
      return {
        "type": "SwitchCase",
        "test": null,
        "consequent": cblock
      }
    }

// TODO: Consider allowing this for Do the following blocks:
// ("Do the following while x is y:")
// TODO: Allow "otherwise" for post-ifs.
PostIfWhile
  = ws term:IfWhileKW ws test:Condition {
      return ( o ) => ifWhileBlock( term, test, [ o ] );
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

VarStatement
  = l:(
    ( "let"i ws )  Setable
      (ws ("equal"/"be equal to"/"be") ws/_"="_) CValue /
    ( "make"i ws ) Setable
      (ws ("equal"/"be equal to"/"equal to"/"be") ws/_"="_/ws) CValue /
    ( "set"i ws )  Setable (ws ("to be"/"to equal"/"to"/"as") ws) CValue /
    ( "have"i ws ) Setable (ws ("equal"/"be equal to"/"be") ws/"=") CValue /
    (_) Setable (ws ("equals"/"is equal to"/"is") ws/_"="_) CValue
    ) {
    return buildLetStatement( l[ 1 ], l[ 3 ] );
  } / l:(
    // No CValues here because it sounds silly.
    ( ("call"i/"name"i) ws ) Value ws Setable /
    ( ("call"i/"name"i) ws ) Value ( ws  [\"\'] ) Setable [\"\']
    ) {
    return buildLetStatement( l[ 3 ], l[ 1 ] );
  }

CreateCompositeLiteral
  = CreateKW ws a ws c:compositeLiteral id:CreateCalled? {
      return buildLetStatement(
        id || c.text,
        c.init
      );
    }

CreateStatement
  = CreateKW ws c:Constructor id:CreateCalled? {
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

CreateCalled
  = ws "called" ws [\"\']? id:SimpleId [\"\']? { return id; }

// --- DEFINING FUNCTIONS ---

DefineFunction
  = DefineMethod /
    DefineConstructor /
    FunctionStatement /
    DefineGetFunction /
    DefineSimpleGetFunction / 
    PrototypeInherit / 
    ConstructorDuplicate

FunctionStatement
  = ("to do"i ws/"to"i ws) id:SimpleId params:ParamGroup 
  ( ":" ws / "," ws / ws "is to" ws )
  !{ startFunction(); } s:PhraseGroupGroup !{ popContext(); }
  {
    return buildFunctionStatement( id, params, s );
  }

DefineConstructor
  = type:(
      ( ( "When"i ws CreatingKW / "To"i ws CreateKW ) ws type:TypeEntity { return type; } ) /
      ( "When"i ws type:TypeEntity ws "is" ws CreatedKW { return type; } )
    )
    params:ParamGroupRequirePreposition "," ws
    !{ startFunction( { thisAlias: type, rememberThis: true } ); }
    s:PhraseGroupGroup
    !{ popContext(); } {
      type = constructorFormat( type );
      var fnStatement = buildFunctionStatement( constructorFormat( type ), params, s ),
        pre = findVar( constructorFormat( type ).name );
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
  !{ popContext(); }
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
      return { extras: [], val: val, alias: val.property }
    }
  / val:Identifier {
      return { extras: [], val: val, alias: val };
    }

DefineGetFunction
  = "to get"i ws id:Identifier ws "of" params:ParamGroupNoPreposition 
  ( "," / ":" ) ws
  !{ startFunction( { expectReturn: id.name } ); }
  s:PhraseGroupGroup
  !{ popContext(); returned = false; }
  {
    return buildFunctionStatement( id, params, s );
  }

DefineSimpleGetFunction // Maybe solidifyRemember here.
  = id:Identifier ws "of" args:ParamGroupNoPreposition ws "is" ws v:CValue
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
  = type:TypeEntity ws "is" ws a ( ws ( "kind" / "type" ) ws "of" ws )? ws parent:SimpleId {
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

// - ARGUMENTS
ParamGroup
  = s:( ( ws ArgPreposition / "" ) ( SingleParam ) )* {
    return extractList( s, 1 );
  }

// For constructors. Can't have "When making a X Y".
ParamGroupRequirePreposition
  = s:( ( ws ArgPreposition ) ( SingleParam ) )* {
    return extractList( s, 1 );
  }

ParamGroupNoPreposition
  = s:SingleParam ss:( ( ( "," )? ws "and" / "," ) ( SingleParam ) )* {
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
  / ws ParamNameCalled ws [\"\']? id:Identifier [\"\']? {
    return id;
  }
  / ws "(" _ ParamNameCalled ws [\"\']? id:Identifier [\"\']? _ ")" {
    return id;
  }

CallIt
  = ( "call it" / "refer to it as" ) ws [\"\']? id:Identifier [\"\']? {
    return id;
  }

ParamNameCalled
  = ("that"/"which") ws (
        "we'll" ws ("call"/"name"/"designate as"/"refer to as")
      / ("shall"/"will") ws "be" ws ("called"/"referred to as")
    )

ArgGroup // TODO: "X Y and Z".
  = s:( ( ws ArgPreposition / "" ) ( SingleArg ) )* {
    return extractList( s, 1 );
  }

ArgGroupRequirePreposition // For constructors. Can't have "Make a X Y".
  = s:( ( ws ArgPreposition ) ( SingleArg ) )* {
    return extractList( s, 1 );
  }

ArgGroupNoPreposition
  = s:SingleArg ss:( ( ( "," )? ws "and" / "," ) ( SingleArg ) )* {
    return buildList( s, ss, 1 );
  }

SingleArg
  = ws !("and" ws) s:Value { return s }

ArgPreposition
  = ( "by" / "to" / "with" / "on" / "in" ) & ws

// --- CALLING FUNCTIONS ---

DoAction
= ("do"i ws)?
  s:SimpleId args:ArgGroup call:CallItVar p:PostIfWhile
  {
    var f = buildExpressionStatement( {
      "type": "CallExpression",
      "callee": s,
      "arguments": args
    } );
    return p( call( f ) );
  }

CallItVar
  = id:( CommaAndThen id:CallIt { return id; } )? { 
      return id ? ( p ) => buildLetStatement( id, p ) : x => x;
    }

HaveOrder
  = id:( 
      "Have"i ws id:Value { return id; } / 
      id:Value ws "should" { return id; }
    )
    ws method:SimpleId args:ArgGroup call:CallItVar p:PostIfWhile {
      return p( call( buildExpressionStatement( {
        "type": "CallExpression",
        "callee": {
          "type": "MemberExpression",
          "object": id,
          "property": method,
          "computed": false
        },
        "arguments": args,
        loc: loc()
      } ) ) );
    }

// Only for actually building.
Constructor
  = a ws id:SimpleId args:ArgGroupRequirePreposition { return {
      "type": "NewExpression",
      "callee": constructorFormat( id ),
      "arguments": args,
      loc: loc()
    }; }

// TODO: "Get X of Y, call it Z." "Get X of Y."

CallGetFunction
  = id:Identifier ws "of" args:ArgGroupNoPreposition { return {
    "type": "CallExpression",
    "callee": id,
    "arguments": args
  }; }

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
    return buildExpressionStatement( {
      "type": "ConditionalExpression",
      "test": c,
      "consequent": v,
      "alternate": av
    } );
  }

// --- LITERALS ---

Literal
  = v:(stringLiteral/numberLiteral) { return {
      "type": "Literal",
      value: v,
      // astring requires this. It's not part of the estree spec.
      raw: text()
    }; }

// Literals and Primitive types
stringLiteral
  // Line breaks being allowed is deliberate, as is lack of escape rules.
  = '"' s:([^"]*) '"' { return s.join(""); }
  / "'" s:([^']*) "'" { return s.join(""); }

numberLiteral
  = s:$([0-9]+("."[0-9]+)?) { return parseFloat( s ); }

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
  = v:Pronoun / ("the"i ws)? v:SimpleId {
    //return { "type": "Identifier", "name": text().replace( ' ', '_' ) };
    maybeRemember( v );
    return v;
  }

SimpleId
  // For some reason, this is matching characters like "\".
  =
  !(
    ( IfKW / WhileKW / "do"i / "otherwise"i / "and"i / "or"i / "to"i / "make"i /
      "have"i / "the"i / "get"i / "is"i / "doesn't" / "exist" / "exists" /
      MathCompareKeyword / "equals" / "equal" / "as" / "same" / "for"i
    )
    ( [^A-z_] / !. )
  )
  v:$([A-z_]+) {
    var name = nonConstructorFormat( v );
    return getAlias( name ) || buildIdentifier( name );
  }


Pronoun
  = ( "it"i / "he"i / "she"i / "him"i / "her"i / "that"i ) WordBreak
      { return useLast(); }

// TODO: Rewrite this.
// TODO: Also make a function for MemberExpression.
PropGet
  = outer:( // TODO: Don't allow simple pronouns here. "X's he's Y" doesn't make sense.
      outer:Identifier "'s" { return outer } /
      PossessivePronoun { return useLast(); }
    )
    ws inner:( PropGet / SimpleId )
  {
    var base = {
      "type": "MemberExpression",
      "object": outer,
      "property": inner,
      "computed": false,
      // loc: loc() // Unfortunately, this is completely inaccurate for now.
    };
    if ( inner.type === "Identifier" ) {
      return base;
    } else {
      for( var x = inner; x && x.object.type === "MemberExpression"; ) {
        x = x.object;
      }
      base.property = x.object;
      x.object = base;
      return inner;
    };
  }

PossessivePronoun
  = ( "its"i / "his"i / "her"i / "their"i ) WordBreak

Setable = Pronoun / PropGet / Identifier

AccessIdent // Unused
  // Requires ! followed by any valid later tokens.
  // Actually, more like !{ check all variables and stuff }
  = [A-z_ ]+ & { x = arguments; } { return arguments; }

// --- WHITESPACE, COMMENTS ---

// - Comments
InlineNote
  = "(Note"i ( ":" / " that" ) [^\)]+ ")"

NoteBlock
  = "Note"i "s"? ":" [^\n]* ( _ "*" [^\n]+ )* _

// - Whitespace
WordBreak
  = ![A-z_]

ws
  = ( [ \t\n\r] / InlineNote )+

_ "whitespace"
  = ( [ \t\n\r] / InlineNote )*
