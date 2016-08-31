// Lots copied from https://github.com/pegjs/pegjs/blob/master/examples/javascript.pegjs
// TODO: Notes, &&s, basic math (x minus y, etc), else, error handling,
// constructor prototype work, ...
// Note for later: It technically is possible to modify earlier stuff, by
// storing the JSON array/object and then modifying it in JS directly.
// When updating the parser, remember to change the "module" stuff to "parser".

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

  var existingVars = [],
    contextStack = [],
    // For pronouns
    lastUsed,
    _lastUsed;
  // ...Problem. I suspect function stuff doesn't run until after things
  // are processed...
  function pushContext() {
    contextStack.push( [] );
  }
  function popContext() {
    contextStack.pop();
  }
  function addVar( name ) {
    contextStack[ contextStack.length - 1 ].push( name );
  }
  function hasVar( name ) {
    return contextStack.some( s => { return s.indexOf( name ) !== -1; } );
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
  = body:SourceElements? {
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
  = "do the following:" _ s:FullStatement+ _"Finally"i ","? ws ss:PhraseGroup {
    return flatten( s.concat( ss ) );
  }

// Capital to period.
FullStatement
  = (("First"i/"Then"i/"Next"i) ","? ws)?
    (!"Finally"i)
    s:(FunctionStatement / PhraseGroup) _'.'_
    { return s }

// Set of phrases, ex. as consequent or fn body.
PhraseGroup
  = s:Statement ss:(AndThen Statement)* {
    //return buildList( s, ss, 1 )
    return flatten( buildList( s, ss, 1 ) );
  }

AndThen // At least of of: "," "and" "then"
  = "," ws ("and" ws)? ("then" ws)? / ws "and" ws ("then" ws)? / ws "then" ws

// Fragment, single clause (and associated block if applicable).
Statement
  = Block / LetStatement / IfStatement / WhileStatement / MathSetter / HaveOrder / DoAction

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
  left:Value (ws "is a" "n"? ws) type:PrimitiveType {
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
  left:Value (ws "is a" "n"? ws) type:SimpleId {
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
    ( ws "is" ws MathGreaterKeyword ws "than or equal" (ws "to")? ws / _">="_ ) { return ">="; }
  / ( ws "is" ws MathGreaterKeyword ws "than" ws / _">"_ ) { return ">"; }
  / ( ws "is" ws MathLessKeyword    ws "than or equal" (ws "to")? ws / _"<="_ ) { return "<="; }
  / ( ws "is" ws MathLessKeyword    ws "than" ws / _"<"_ ) { return "<"; }
  / ( ws ("equals"/"is equal to"/"is") ws / _"="_ ) { return "==="; }

//MathCompareKeyword = MathGreaterKeyword { return ">" } / MathLessKeyword { return "<" }
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

MathSetterBinaryOp
  // Maybe also allow "Make X Y more than before"? Would interfere with var.
  = ("Increment"i/"Increase"i) ws s:Setable ws "by" ws v:Value { return {s,v,op:"+="}; }
  / "Add"i ws v:Value ws "to" ws s:Setable { return {s,v,op:"+="}; }
  / ("Decrement"i/"Decrease"i) ws s:Setable ws "by" ws v:Value { return {s,v,op:"-="}; }
  / "Subtract"i ws v:Value ws "from" ws s:Setable { return {s,v,op:"-="}; }
  / "Multiply"i ws s:Setable ws "by" ws v:Value { return {s,v,op:"*="}; }
  / "Divide"i ws s:Setable ws "by" ws v:Value { return {s,v,op:"/="}; }

MathSetterUnaryOp
  = ("Increment"i/"Increase"i) ws s:Setable { return {s, op:"++"}}
  / ("Decrement"i/"Decrease"i) ws s:Setable { return {s, op:"--"}}

MathBinary
  = left:Value ws op:MathBinaryOp ws Value

MathBinaryOp
  = "plus" { return "+"; }
  / "minus" { return "-"; }
  / ("multiplied by"/"times") { return "*"; }
  / ("divided by"/"over") { return "/"; }
  // Concatenation. Should probably be handled differently, to
  // force toString: x followed by y > '' + x + y;
  / "followed by" { return "+"; }

ValueTest
  = v:Value ws "exists" { return v; }

IfStatement
  = "if"i ws test:Condition
    (", then" ws/"," ws) cblock:PhraseGroup
    // The punctuation rules here should be stricter.
    alt:( (("."/";"/",") _ "otherwise" ws) PhraseGroup )? {
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
  = ("while"i/"so long as"i) ws test:Condition (", then" ws/"," ws) cblock:PhraseGroup {
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
    s:SimpleId arg:ArgGroup { return {
       "type": "ExpressionStatement",
       "expression": {
          "type": "CallExpression",
          "callee": s,
          "arguments": arg
       }
    } }

LetStatement
  = l:(
    ( "let"i ws )  Setable (ws ("equal"/"be equal to"/"be") ws/_"="_) Value /
    ( "make"i ws ) Setable (ws ("equal"/"be equal to"/"equal to"/"be") ws/ws/_"="_) Value /
    ( "set"i ws )  Setable (ws ("to be"/"to equal"/"to"/"as") ws) Value /
    ( "have"i ws ) Setable (ws ("equal"/"be equal to"/"be") ws/"=") Value /
    (_) Setable (ws ("equals"/"is equal to"/"is") ws/_"="_) Value
    // Should also allow "Call Y X"
    ) {
    var m = l[ 1 ].type === "MemberExpression";
    var preDeclared = m || hasVar( l[ 1 ].name );
    solidifyRemember( l[ 1 ] );
    if ( !preDeclared ) {
      addVar( l[ 1 ].name );
      //return contextStack;
      return {
        "type": "VariableDeclaration",
        "declarations": [
          {
            "type": "VariableDeclarator",
            "id":   l[ 1 ],
            "init": l[ 3 ]
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
            "left": l[ 1 ],
            "right": l[ 3 ]
         }
      };
    }
  }

FunctionStatement
  = ("to do"i ws/"to"i ws) id:SimpleId args:ParamGroup (","ws/ws "is to"ws)
  !{ pushContext(); solidifyRemember(); } s:PhraseGroup !{ popContext(); }
  {
    var body = [];

    for ( var i = 0; i < args.length; i++ ) {
      body.push();
    }
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

SingleParam
  = ws ("a thing"/"something") {
      var s = { type: "Identifier", name:"thing"};
      maybeRemember( s );
      return s;
    }
  / ws s:TypeEntity { maybeRemember( s ); return s; }

ArgGroup // TODO: "X Y and Z", "of" statements.
  = s:( ( ws ArgPreposition / "" ) ( SingleArg ) )* {
    return extractList( s, 1 );
  }

SingleArg
  = ws !("and" ws) s:Value { return s }

ArgPreposition
  = "by" / "to"

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
  = "a" "n"? ws type:SimpleId { return type; }

Value
  = Literal /
    PropGet /
    Constructor /
    Identifier /
  	[a-z]+ { return  }

Literal
  = v:(stringL/numberL) { return {
      "type": "Literal",
      value: v,
      // astring requires this. It's not part of the estree spec.
      raw: text()
    }; }

Constructor
  = "a" "n"? ws id:SimpleId { return {
    "type": "NewExpression",
    "callee": constructorFormat( id ),
    "arguments": []
  };}

stringL
  // Line breaks being allowed is deliberate, as is lack of escape rules.
  = '"' s:([^"]*) '"' { return s.join(""); }
  / "'" s:([^']*) "'" { return s.join(""); }

numberL
  = s:$([0-9]+("."[0-9]+)?) { return parseFloat( s ); }

PrimitiveType = NumberType / StringType
NumberType = ( "number" / "amount" / "quantity" ) { return "number"; }
StringType = ( "string" / "sentence" / "phrase" / "word" / "text" ) { return "string"; }

Identifier
  //= [A-z _]+ {
  = v:Pronoun / ("the"i ws)? v:SimpleId {
    //return { "type": "Identifier", "name": text().replace( ' ', '_' ) };
    maybeRemember( v );
    return v;
  }

SimpleId
  = v:([A-z_]+) {
    return {
      "type": "Identifier",
      "name": v[ 0 ].toLowerCase() + v.slice(1).join("")
    };
  }

PropGet
  = outer:(outer:Identifier "'s" { return outer }/"its" { return lastUsed; })
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
  = ("it"i / "him"i / "her"i) { return useLast(); }

PPronoun
  = "its"i / "his"i / "her"i

Setable = Pronoun / PropGet / Identifier

AccessIdent // Unused
  // Requires ! followed by any valid later tokens.
  // Actually, more like !{ check all variables and stuff }
  = [A-z_ ]+ & { x = arguments; } { return arguments; }

/*
Note
  = ("Note:" [^\n]+ / "Notes:" (.!("\n" _ [^*] ))+ ) { return [] }
*/

ws
  = [ \t\n\r]+

_ "whitespace"
  = [ \t\n\r]*
