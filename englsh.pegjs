// Lots copied from
// https://github.com/pegjs/pegjs/blob/master/examples/javascript.pegjs
// TODO: Notes, &&s, error handling, getting and setting return statements,
// ...
// Note for later: It technically is possible to modify earlier stuff, by
// storing the JSON array/object and then modifying it in JS directly.
// When updating the parser, remember to change the "module" stuff
// to "parser".

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
    var m = name.type === "MemberExpression";
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
      return {
         "type": "ExpressionStatement",
         "expression": {
            "type": "AssignmentExpression",
            "operator": "=",
            "left": name,
            "right": val
         }
      };
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

  // TODO: Aliases (in contexts). Example:
  // "When making an x, make the x's y z." "x" is alias for "this".
  var contextStack = [],
    // For pronouns
    lastUsed,
    _lastUsed;

  function pushContext() {
    contextStack.push( { vars: [], aliases: {} } );
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
    _lastUsed = val;
  }
  function solidifyRemember( val ) {
    lastUsed = val || _lastUsed;
  }
  function useLast() {
    return lastUsed;
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
  = FullStatement // / Note

Block
  = "do the following:" _ s:FullStatement+
  _"Finally"i ","? ws ss:PhraseGroup {
    return flatten( s.concat( ss ) );
  }

// Capital to period.
FullStatement
  = (("First"i/"Then"i/"Next"i) ","? ws)?
    (!"Finally"i)
    s:(
      FunctionStatement /
      PrototypeFunction /
      DefineConstructor /
      PhraseGroup
    ) _'.'_
    { return s }

// Set of phrases, ex. as consequent or fn body.
PhraseGroup
  = s:Statement ss:(AndThen Statement)* {
    //return buildList( s, ss, 1 )
    return flatten( buildList( s, ss, 1 ) );
  }

AndThen // At least of of: "," "and" "then"
  = "," ws ("and" ws)? ("then" ","? ws)? /
    ws "and" ws ("then" ","? ws)? /
    ws "then" ","? ws

// Fragment, single clause (and associated block if applicable).
Statement
  = Block /
    CreateStatement /
    LetStatement /
    IfStatement /
    WhileStatement /
    MathSetter /
    HaveOrder /
    DoAction

Condition // In conditions, "is" means "===", "and" means "&&", etc.
  = AndCheck / LogicCheck / Comparison / ValueTest

LogicCheck
  = /*AndCheck /
    OrCheck*/ 'oaoeueoa'

AndCheck // If X is more than Y and less than Z and equals W.
  = left:ValueTest ws 'and' ws right:Condition { return left; }

OrCheck
  = left:Condition ' and ' { return left; }

Comparison
  = // typeof Primitive
  left:Value (ws "is" ws a ws) type:PrimitiveType {
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
    }
  } / // Instanceof
  left:Value (ws "is" ws a ws) type:SimpleId {
    return {
      "type": "BinaryExpression",
      "operator": "instanceof",
      "left": left,
      "right": constructorFormat( type )
    }
  } /
  MathComparison

MathComparison
  = left:Value op:MathCompareOp right:Value {
    return {
      "type": "BinaryExpression",
      "operator": op,
      "left": left,
      "right": right
    };
  }

MathCompareOp
  = // TODO: For if x is more than y and less than z, remove "is" req.
    ( ws "is" ws MathGreaterKeyword ws "than or equal" (ws "to")?
        ws / _">="_ ) { return ">="; }
  / ( ws "is" ws MathGreaterKeyword ws "than" ws / _">"_ ) { return ">"; }
  / ( ws "is" ws MathLessKeyword    ws "than or equal" (ws "to")?
        ws / _"<="_ ) { return "<="; }
  / ( ws "is" ws MathLessKeyword    ws "than" ws / _"<"_ ) { return "<"; }
  / ( ws ("equals"/"is equal to"/"is") ws / _"="_ ) { return "==="; }

/*
MathCompareKeyword =
  MathGreaterKeyword { return ">" } /
  MathLessKeyword { return "<" }
*/
MathGreaterKeyword = "more" / "higher" / "greater" / "larger"
MathLessKeyword = "less" / "lower"

MathSetter
  = l:MathSetterBinaryOp { return {
      "type": "ExpressionStatement",
      "expression": {
        "type": "AssignmentExpression",
        "operator": l.op,
        "left": l.s,
        "right": l.v
       }
     }; }
  / l:MathSetterUnaryOp  { return {
      "type": "ExpressionStatement",
      "expression": {
        "type": "UpdateExpression",
        "operator": l.op,
        "argument": l.s,
        "prefix": false
       }
     }; }

Expression
  = AdditiveExpression

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

ValueTest
  = v:Value ws "exists" { return v; }
  / v:Value ws "doesn't exist" { return {
    "type": "UnaryExpression",
    "operator": "!",
    "argument": v,
    "prefix": true
  }; }

IfStatement
  = "if"i ws test:Condition
    (", then" ws/"," ws) cblock:PhraseGroup
    // The punctuation rules here should be stricter.
    alt:( (("."/";"/",") _ "otherwise"i ","? ws) PhraseGroup )? {
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

DoAction
  = ("do"i ws)?
    //(!"if"i)
    s:SimpleId arg:ArgGroup
    // ( AndThen LetStatement )?
    {
      var f = {
       "type": "ExpressionStatement",
       "expression": {
          "type": "CallExpression",
          "callee": s,
          "arguments": arg
        }
      };
      return f;
    }

LetStatement
  = l:(
    ( "let"i ws )  Setable
      (ws ("equal"/"be equal to"/"be") ws/_"="_) Value /
    ( "make"i ws ) Setable
      (ws ("equal"/"be equal to"/"equal to"/"be") ws/ws/_"="_) Value /
    ( "set"i ws )  Setable (ws ("to be"/"to equal"/"to"/"as") ws) Value /
    ( "have"i ws ) Setable (ws ("equal"/"be equal to"/"be") ws/"=") Value /
    (_) Setable (ws ("equals"/"is equal to"/"is") ws/_"="_) Value
    ) {
    return buildLetStatement( l[ 1 ], l[ 3 ] );
  } / l:(
    ( ("call"i/"name"i) ws ) Value ws Setable /
    ( ("call"i/"name"i) ws ) Value ( ws  [\"\'] ) Setable [\"\']
    ) {
    return buildLetStatement( l[ 3 ], l[ 1 ] );
  }

FunctionStatement
  = ("to do"i ws/"to"i ws) id:SimpleId args:ParamGroup (","ws/ws "is to"ws)
  !{ pushContext(); solidifyRemember(); } s:PhraseGroup !{ popContext(); }
  {
  	return {
       "type": "FunctionDeclaration",
       "id": id,
       "params": args,
       "body": {
          "type": "BlockStatement",
          //"body": flatten( s )
          "body": s
       }
    }
  }

ParamGroup
  = s:( ( ws ArgPreposition / "" ) ( SingleParam ) )* {
    return extractList( s, 1 );
  }

// For constructors. Can't have "When making a X Y".
ParamGroupRequirePreposition
  = s:( ( ws ArgPreposition ) ( SingleParam ) )* {
    return extractList( s, 1 );
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

ArgGroup // TODO: "X Y and Z", "of" statements.
  = s:( ( ws ArgPreposition / "" ) ( SingleArg ) )* {
    return extractList( s, 1 );
  }

ArgGroupRequirePreposition // For constructors. Can't have "Make a X Y".
  = s:( ( ws ArgPreposition ) ( SingleArg ) )* {
    return extractList( s, 1 );
  }

SingleArg
  = ws !("and" ws) s:Value { return s }

ArgPreposition
  = ( "by" / "to" / "with" / "of" / "on" / "in" ) & ws

CreateStatement
  = ("Make"i/"Build"i/"Create"i/"Set up"i) ws c:Constructor
  id:( ws "called" ws [\"\']? id:SimpleId [\"\']? { return id; } )?
  {
    var name = c.callee.name;
    return buildLetStatement(
      id || buildIdentifier( nonConstructorFormat( name ) ),
      c
    );
  }

DefineConstructor
  = "When"i ws ("making"/"creating"/"building"/"setting up") ws
  type:TypeEntity params:ParamGroupRequirePreposition "," ws
  !{
    var t = { "type": "ThisExpression" };
    pushContext();
    setAlias( nonConstructorFormat( type.name ), t );
    solidifyRemember( t );
  }
  s:PhraseGroup
  !{ popContext(); } {
  	return {
       "type": "FunctionDeclaration",
       "id": constructorFormat( type ),
       "params": params,
       "body": {
          "type": "BlockStatement",
          "body": s
       }
    }
  }

PrototypeFunction
  = type:(
      "For"i ws type:TypeEntity ws "to" {return type;} /
      "To have"i ws type:TypeEntity { return type; }
    )
  ws method:SimpleId args:ParamGroup "," ws
  !{
    var t = { "type": "ThisExpression" };
    pushContext();
    setAlias( nonConstructorFormat( type.name ), t );
    solidifyRemember();
  }
  s:PhraseGroup
  !{ popContext(); } {
    // TODO
    var c = constructorFormat( type );
    var q = {
      "type": "ExpressionStatement",
      "expression": {
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
        "right": {
          "type": "FunctionExpression",
          "id": method,
          "params": args,
          "body": {
            "type": "BlockStatement",
            "body": s
          }
        }
      }
    };
    return q;
  }

PrototypeValue // Is this really necessary?
  = type:TypeEntity "'s" ws prop:SimpleId

HaveOrder
  = "Have"i ws id:Value ws method:SimpleId args:ArgGroup {
    return {
      "type": "ExpressionStatement",
      "expression": {
        "type": "CallExpression",
        "callee": {
          "type": "MemberExpression",
          "object": id,
          "property": method,
          "computed": false
        },
        "arguments": args
      }
    };
  }

TypeEntity
  = a ws type:SimpleId { return type; }

Value
  = Expression /
    Literal /
    PropGet /
    Constructor /
    Identifier /
  	[a-z]+ { return  }

// Currently only used in Expressions themselves...
SimpleValue
  = Literal /
    PropGet /
    Constructor /
    Identifier

Literal
  = v:(stringLiteral/numberLiteral) { return {
      "type": "Literal",
      value: v,
      // astring requires this. It's not part of the estree spec.
      raw: text()
    }; }

// Only for actually building.
Constructor
  =
  // Problem: These don't have callee.name, so "Make an array" doesn't work.
  /*
  a ws arrayLiteral { return {
    "type": "ArrayExpression",
    "elements": []
  }; } /
  a ws o:objectLiteral { return {
    "type": "ObjectExpression",
    "properties": []
  }; } /
  */
  a ws id:SimpleId args:ArgGroupRequirePreposition { return {
    "type": "NewExpression",
    "callee": constructorFormat( id ),
    "arguments": args
  }; }

stringLiteral
  // Line breaks being allowed is deliberate, as is lack of escape rules.
  = '"' s:([^"]*) '"' { return s.join(""); }
  / "'" s:([^']*) "'" { return s.join(""); }

numberLiteral
  = s:$([0-9]+("."[0-9]+)?) { return parseFloat( s ); }

arrayLiteral
  = "group" / "list" / "array"

objectLiteral
  = "thing" / "object"

PrimitiveType = NumberType / StringType
NumberType = ( "number" / "amount" / "quantity" ) { return "number"; }
StringType = ( "string" / "sentence" / "phrase" / "word" / "text" )
  { return "string"; }

Identifier
  //= [A-z _]+ {
  = v:Pronoun / ("the"i ws)? v:SimpleId {
    //return { "type": "Identifier", "name": text().replace( ' ', '_' ) };
    maybeRemember( v );
    return v;
  }

SimpleId
  // For some reason, this is matching characters like "\".
  = v:$([A-z_]+) {
    return getAlias( v ) || buildIdentifier( nonConstructorFormat( v ) );
  }

PropGet
  = outer:(
      outer:Identifier "'s" { return outer } /
      PPronoun { return useLast(); }
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

Pronoun
  = ("it"i / "he"i / "she"i / "him"i / "her"i) ![A-z] { return useLast(); }

PPronoun
  = ( "its"i / "his"i / "her"i / "their"i ) ![A-z]

Setable = Pronoun / PropGet / Identifier

AccessIdent // Unused
  // Requires ! followed by any valid later tokens.
  // Actually, more like !{ check all variables and stuff }
  = [A-z_ ]+ & { x = arguments; } { return arguments; }

/*
Note
  = ("Note:" [^\n]+ / "Notes:" (.!("\n" _ [^*] ))+ ) { return [] }
*/

a
  = "a" ("n" "other"?)?

ws
  = ([ \t\n\r]/"(Note:" [^\)]+ ")")+

_ "whitespace"
  = [ \t\n\r]*
