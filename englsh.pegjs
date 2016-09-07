// Lots copied from
// https://github.com/pegjs/pegjs/blob/master/examples/javascript.pegjs
// TODO: error handling, ...
//
// Note for later: It technically is possible to modify earlier stuff, by
// storing the JSON array/object and then modifying it in JS directly.
// When updating the parser, remember to change the "module" stuff
// to "parser".

// I still have no plan for how to send functions as arguments.

// TO CONSIDER: Add fancy array functions, like reduce and map.

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

  function buildBinaryExpression(head, tail) {
    return buildTree(head, tail, function(result, element) {
      return {
        type:     "BinaryExpression",
        operator: element[1],
        left:     result,
        right:    element[3]
      };
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
        "argument": returnValue
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
          "kind": "var"
        };
      } else {
        return buildExpressionStatement( {
          "type": "AssignmentExpression",
          "operator": "=",
          "left": name,
          "right": val
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
      }
    };
  }

  function buildExpressionStatement( exp ) {
    return {
      "type": "ExpressionStatement",
      "expression": exp
    }
  }

  function buildIdentifier( name ) {
    return {
      type: "Identifier",
      name: name
    };
  }

  // There are a lot of groups needing flattening. Blocks have
  // lines/sentences which have SPhraseGroups which have phrase groups
  // which have phrases.
  // Could be activated in a {} inside the expression, though
  function flatten(array) {
    return [].concat.apply( [], array );
  }

  function constructorFormat( string ) {
    if ( string.name ) {
      string.name = constructorFormat( string.name );
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



  function logicBlock( type ) {
    return function( left, right ) {
      return {
        "type": "LogicalExpression",
        "operator": type,
        "left": left,
        "right": right
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
    contextStack.push( { vars: [], aliases: {}, expectReturn: options && options.expectReturn } );
  }
  function popContext() {
    contextStack.pop();
  }
  function addVar( name ) {
    contextStack[ contextStack.length - 1 ].vars.push( name );
  }
  function hasVar( name ) {
    return contextStack.some( s => {
      return s.vars.indexOf( name ) !== -1;
    } );
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


}

Program
  = Body

Body
  = _ body:SourceElements? {
      return {
        type: "Program",
        body: body ? body : []
      };
    }

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

SentencePrefix // TODO: Only allow each prefix where appropriate.
  = ( ( "First"i / "Then"i / "Next"i ) ","? ws )?
    ( !"Finally"i )

SentenceLevelStatement
  = FunctionStatement /
    PrototypeFunction /
    DefineConstructor /
    DefineGetFunction /
    DefineSimpleGetFunction /
    PhraseGroupGroup

EndFullSentence
  = _ "." _ NoteBlock*

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
      return {
        "type": "BinaryExpression",
        "operator": "===",
        "left": {
          "type": "UnaryExpression",
          "operator": "typeof",
          "argument": left,
          "prefix": true
        },
        "right": {
          "type": "Literal",
          "value": type,
          "raw": '"' + type + '"'
        }
      };
    }
  } // Instanceof
  / a ws type:( compositeLiteralType / SimpleId ) {
    return function ( left ) {
      return {
        "type": "BinaryExpression",
        "operator": "instanceof",
        "left": left,
        "right": constructorFormat( type )
      };
    };
  }
  // Remember to lookahead for ops, avoid the "x is more ...." > "x === more" problem.
  / right:Value {
    return function ( left ) {
      return {
        "type": "BinaryExpression",
        "operator": "===",
        "left": left,
        "right": right
      };
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
    return function ( left, right ) {
      return {
        "type": "BinaryExpression",
        "operator": op,
        "left": left,
        "right": right
      };
    }
  }

ConditionUnaryOp
  = ws "exists" {
      return function ( left ) {
        return left;
      }
    }
  / ws "doesn't exist" {
      return function ( left ) {
        return {
          "type": "UnaryExpression",
          "operator": "!",
          "argument": left,
          "prefix": true
        };
      };
    }


Expression
  = AdditiveExpression

// --- MATH ---

MathCompareOp
  = ws ( "is" ws )? k:MathCompareKeyword ws "than"
      e:( ws "or equal" ( ws "to" )? )? ws
      { return k + ( e ? '=' : '' ); }
  / _ o:$( [><]"="? ) _ { return o; }
  / ( ws ("equals"/"is equal to"/"is the same as"/"is") ws / _"="_ )
      { return "==="; }

MathCompareKeyword
  = ( "more" / "higher" / "greater" / "larger" ) { return ">" }
  / ( "less" / "lower" ) { return "<" }

// TODO: Move this somewhere else.
MathSetter
  = l:MathSetterBinaryOp { return buildExpressionStatement( {
      "type": "AssignmentExpression",
      "operator": l.op,
      "left": l.s,
      "right": l.v
     } ); }
  / l:MathSetterUnaryOp  { return buildExpressionStatement( {
      "type": "UpdateExpression",
      "operator": l.op,
      "argument": l.s,
      "prefix": false
     } ); }

MathSetterBinaryOp
  // TODO: Allow PostIfs.
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

// --- IF, WHILE ---

IfStatement
  = "if"i ws test:Condition
    (", then" ws/"," ws) cblock:PhraseGroup
    ret:( !{} { var r = returned; returned = false; return r; } )
    // TODO: The punctuation rules here should be stricter.
    alt:( (("."/";"/",") _ "otherwise"i ","? ws) PhraseGroup )?
  {
    if ( !ret ) {
      returned = false;
    }

    return {
      type:       "IfStatement",
      test:       test,
      consequent: {
        "type": "BlockStatement",
        "body": cblock
      },
      alternate:  alt ? {
        "type": "BlockStatement",
        "body": alt[ 1 ]
      } : null
    };
  }

WhileStatement // TODO: Reduce duplication with above
  // TODO: Allow inversion, "do x while y", for both if and while.
  = ("while"i/"so long as"i) ws test:Condition (", then" ws/"," ws)
    cblock:PhraseGroup
  {
    return {
      "type": "WhileStatement",
      "test": test,
      "body": {
         "type": "BlockStatement",
         "body": cblock
      }
    }
  }

// --- VARIABLE ASSIGNMENT ---

LetStatement
  = st:( CreateCompositeLiteral / CreateStatement / VarStatement ) p:PostIf? {
    return p ? p( st ) : st;
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
  = CreateKW a ws c:compositeLiteral id:CreateCalled? {
      return buildLetStatement(
        id || c.text,
        c.init
      );
    }

CreateStatement
  = CreateKW c:Constructor id:CreateCalled? {
      var name = c.callee.name;
      return buildLetStatement(
        id || buildIdentifier( nonConstructorFormat( name ) ),
        c
      );
    }

CreateKW
  = ("Make"i/"Build"i/"Create"i/"Set up"i) ws

CreateCalled
  = ws "called" ws [\"\']? id:SimpleId [\"\']? { return id; }

PostIf
  = ws "if" ws test:Condition {
    return function ( o ) {
      returned = false;
      return {
        type:       "IfStatement",
        test:       test,
        consequent: {
          "type": "BlockStatement",
          "body": [ o ]
        },
        alternate: null
      }
    }
  }

// --- DEFINING FUNCTIONS ---

FunctionStatement
  = ("to do"i ws/"to"i ws) id:SimpleId params:ParamGroup (","ws/ws "is to"ws)
  !{ startFunction(); } s:PhraseGroup !{ popContext(); }
  {
    return buildFunctionStatement( id, params, s );
  }

DefineConstructor
  = "When"i ws ("making"/"creating"/"building"/"setting up") ws
  type:TypeEntity params:ParamGroupRequirePreposition "," ws
  !{ startFunction( { thisAlias: type, rememberThis: true } ); }
  s:PhraseGroup
  !{ popContext(); } {
    return buildFunctionStatement( constructorFormat( type ), params, s );
  }

PrototypeFunction
  = type:(
      "For"i ws type:TypeEntity ws "to" {return type; } /
      "To have"i ws type:TypeEntity { return type; }
    )
  ws method:SimpleId params:ParamGroup "," ws
  !{ startFunction( { thisAlias: type } ); }
  s:PhraseGroup
  !{ popContext(); }
  {
    var c = constructorFormat( type );
    var q = buildExpressionStatement( {
      "type": "AssignmentExpression",
      "operator": "=",
      "left": {
        "type": "MemberExpression",
        "object": {
          "type": "MemberExpression",
          "object": c,
          "property": buildIdentifier( "prototype" ),
          "computed": false
        },
        "property": method,
        "computed": false
      },
      "right": buildFunctionStatement( method, params, s, true )
    } );
    return q;
  }

DefineGetFunction
  = "to get"i ws id:Identifier ws "of" params:ParamGroupNoPreposition "," ws
  !{ startFunction( { expectReturn: id.name } ); }
  s:PhraseGroup
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
  = ws ("a thing"/"something"/"someone")
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
  = ws "(" _ ("let's" ws)? ("call it"/"refer to it as") ws
      [\"\']? id:Identifier [\"\']? "\)"
  {
    return id;
  }
  / ws ParamNameCalled ws [\"\']? id:Identifier [\"\']? {
    return id;
  }
  / ws "(" _ ParamNameCalled ws [\"\']? id:Identifier [\"\']? _ ")" {
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

/*
PrototypeValue // Is this really necessary?
  = type:TypeEntity "'s" ws prop:SimpleId
*/

// --- CALLING FUNCTIONS ---

DoAction
= ("do"i ws)?
  s:SimpleId args:ArgGroup p:PostIf?
  {
    var f = buildExpressionStatement( {
      "type": "CallExpression",
      "callee": s,
      "arguments": args
    } );
    return p ? p( f ) : f;
  }

HaveOrder
  = "Have"i ws id:Value ws method:SimpleId args:ArgGroup {
    return buildExpressionStatement( {
      "type": "CallExpression",
      "callee": {
        "type": "MemberExpression",
        "object": id,
        "property": method,
        "computed": false
      },
      "arguments": args
    } );
  }

// Only for actually building.
Constructor
  = a ws id:SimpleId args:ArgGroupRequirePreposition { return {
      "type": "NewExpression",
      "callee": constructorFormat( id ),
      "arguments": args
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
  = t:arrayLiteral  ![A-z_] { return { type: 'array', text: t, init: {
      "type": "ArrayExpression",
      "elements": []
    } }; }
  / t:objectLiteral ![A-z_] { return { type: 'object', text: t, init: {
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
  = "a" ("n" "other"?)?

TypeEntity
  = a ws type:SimpleId { return type; }

PrimitiveType = NumberType / StringType
NumberType = ( "number" / "amount" / "quantity" ) { return "number"; }
StringType = ( "string" / "sentence" / "phrase" / "word" / "text" )
  { return "string"; }

// --- IDENTIFIERS, PROPERTIES ---

Identifier
  //= [A-z _]+ {
  = v:Pronoun / ("the"i ws)? v:SimpleId {
    //return { "type": "Identifier", "name": text().replace( ' ', '_' ) };
    maybeRemember( v );
    return v;
  }

SimpleId
  // For some reason, this is matching characters like "\".
  =
  !(
    ( "if"i / "do"i / "otherwise"i / "and"i / "or"i / "to"i / "make"i /
      "have"i / "the"i / "get"i / "is"i / "doesn't" / "exist" / "exists" /
      MathCompareKeyword / "equals" / "equal" / "as" / "same" )
    ( [^A-z_] )
  )
  v:$([A-z_]+) {
    var name = nonConstructorFormat( v );
    return getAlias( name ) || buildIdentifier( name );
  }


Pronoun
  = ("it"i / "he"i / "she"i / "him"i / "her"i / "that"i) ![A-z]
      { return useLast(); }

PropGet
  = outer:(
      outer:Identifier "'s" { return outer } /
      PossessivePronoun { return useLast(); }
    )
    _ inner:( PropGet / SimpleId )
  {
    var base = {
      "type": "MemberExpression",
      "object": outer,
      "property": inner,
      "computed": false
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
  = ( "its"i / "his"i / "her"i / "their"i ) ![A-z]

Setable = Pronoun / PropGet / Identifier

AccessIdent // Unused
  // Requires ! followed by any valid later tokens.
  // Actually, more like !{ check all variables and stuff }
  = [A-z_ ]+ & { x = arguments; } { return arguments; }

// --- WHITESPACE, COMMENTS ---

// - Comments
InlineNote
  = "(Note:"i [^\)]+ ")"

NoteBlock
  = "Note"i "s"? ":" [^\n]+ ( _ "*" [^\n]+ )* _

// - Whitespace
ws
  = ( [ \t\n\r] / InlineNote )+

_ "whitespace"
  = ( [ \t\n\r] / InlineNote )*
