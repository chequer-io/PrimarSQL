parser grammar DynamoSQLParser;

options {
    tokenVocab=DynamoSQLLexer;
}

// Top Level Description

root
    : sqlStatements? MINUSMINUS? EOF
    ;

sqlStatements
    : (sqlStatement MINUSMINUS? SEMI? | emptyStatement)*
    (sqlStatement (MINUSMINUS? SEMI)? | emptyStatement)
    ;

sqlStatement
    : ddlStatement | dmlStatement
    | administrationStatement
    ;

emptyStatement
    : SEMI
    ;

ddlStatement
    : createTable 
    | alterTable | dropIndex
    | dropTable | truncateTable
    ;

dmlStatement
    : selectStatement | insertStatement | updateStatement
    | deleteStatement
    ;

administrationStatement
    : showStatement
    ;

// Data Definition Language

//    Create statements

createTable
    : CREATE TABLE ifNotExists?
       tableName createDefinitions
       ( tableOption (','? tableOption)* )?                     #columnCreateTable
    ;

functionParameter
    : uid dataType
    ;

createDefinitions
    : '(' createDefinition (',' createDefinition)* ')'
    ;

createDefinition
    : uid columnDefinition                                          #columnDeclaration
    ;

columnDefinition
    : dataType columnConstraint*
    ;

columnConstraint
    : HASH KEY                                                      #hashKeyColumnConstraint
    | RANGE KEY                                                     #rangeKeyColumnConstraint
    ;

tableOption
    : THROUGHPUT '='? '(' decimalLiteral+ ',' decimalLiteral+ ')'   #tableOptionThroughput
    | BILLINGMODE '='? (PROVISIONED | PAY_PER_REQUEST)              #tableBillingMode
    ;

//    Alter statements

alterTable
    : ALTER TABLE tableName
      (alterSpecification (',' alterSpecification)*)?
    ;

// details

alterSpecification
    : tableOption (','? tableOption)*                               #alterByTableOption
    ;


//    Drop statements

dropIndex
    : DROP INDEX uid ON tableName
    ;

dropTable
    : DROP TABLE ifExists? tables
    ;

//    Other DDL statements

truncateTable
    : TRUNCATE TABLE? tableName
    ;


// Data Manipulation Language

//    Primary DML Statements

deleteStatement
    : singleDeleteStatement | multipleDeleteStatement
    ;

insertStatement
    : INSERT INTO tableName
      (PARTITION '(' partitions=uidList? ')' )?
      (
        ('(' columns=uidList ')')? insertStatementValue
        | SET
            setFirst=updatedElement
            (',' setElements+=updatedElement)*
      )
    ;

selectStatement
    : querySpecification                                            #simpleSelect
    | queryExpression                                               #parenthesisSelect
    ;

updateStatement
    : singleUpdateStatement | multipleUpdateStatement
    ;

// details

insertStatementValue
    : insertFormat=(VALUES | VALUE)
      '(' expressionsWithDefaults? ')'
        (',' '(' expressionsWithDefaults? ')')*
    ;

updatedElement
    : fullColumnName '=' (expression)
    ;

assignmentField
    : uid | LOCAL_ID
    ;

//    Detailed DML Statements

singleDeleteStatement
    : DELETE FROM tableName
      (PARTITION '(' uidList ')' )?
      (WHERE expression)?
      orderByClause? (LIMIT limitClauseAtom)?
    ;

multipleDeleteStatement
    : DELETE 
      (
        tableName ('.' '*')? ( ',' tableName ('.' '*')? )*
            FROM tableSources
        | FROM
            tableName ('.' '*')? ( ',' tableName ('.' '*')? )*
            USING tableSources
      )
      (WHERE expression)?
    ;

singleUpdateStatement
    : UPDATE tableName (AS? uid)?
      SET updatedElement (',' updatedElement)*
      (WHERE expression)? orderByClause? limitClause?
    ;

multipleUpdateStatement
    : UPDATE tableSources
      SET updatedElement (',' updatedElement)*
      (WHERE expression)?
    ;

// details

orderByClause
    : ORDER order=(ASC | DESC)
    ;

tableSources
    : tableSource (',' tableSource)*
    ;

tableSource
    : tableSourceItem                                               #tableSourceBase
    | '(' tableSourceItem           ')'                             #tableSourceNested
    ;

tableSourceItem
    : tableName
      (PARTITION '(' uidList ')' )? (AS? alias=uid)?                #atomTableItem
    | '(' tableSources ')'                                          #tableSourcesItem
    ;

//    Select Statement's Details

queryExpression
    : '(' querySpecification ')'
    | '(' queryExpression ')'
    ;

querySpecification
    : SELECT selectElements
      fromClause? orderByClause? limitClause?
    ;

// details

selectElements
    : (star='*' | selectElement ) (',' selectElement)*
    ;

selectElement
    : fullId '.' '*'                                                #selectStarElement
    | fullColumnName (AS? alias=uid)?                               #selectColumnElement
    ;

fromClause
    : FROM tableSources
      (WHERE whereExpr=expression)?
    ;

limitClause
    : LIMIT limit=limitClauseAtom
    ;

limitClauseAtom
    : decimalLiteral
    ;

// Administration Statements
//    show statements

showStatement
    : SHOW columnsFormat=(COLUMNS | FIELDS)
      tableFormat=(FROM | IN) tableName                             #showColumns
    | SHOW indexFormat=(INDEXES | KEYS)
      tableFormat=(FROM | IN) tableName                             #showIndexes
    | SHOW TABLES                                                   #showTables
    ;

// Common Clauses

//    DB Objects

fullId
    : uid dottedId?
    ;

tableName
    : fullId
    ;

fullColumnName
    : uid (dottedId dottedId? )?
    ;

indexColumnName
    : (uid | STRING_LITERAL) ('(' decimalLiteral ')')? sortType=(ASC | DESC)?
    ;

userName
    : STRING_USER_NAME | ID | STRING_LITERAL;

collationName
    : uid | STRING_LITERAL;

uuidSet
    : decimalLiteral '-' decimalLiteral '-' decimalLiteral
      '-' decimalLiteral '-' decimalLiteral
      (':' decimalLiteral '-' decimalLiteral)+
    ;

uid
    : simpleId
    | DOUBLE_QUOTE_ID
    | REVERSE_QUOTE_ID
    ;

simpleId
    : ID
    | privilegesBase
    | intervalTypeBase
    | dataTypeBase
    | keywordsCanBeId
    ;

dottedId
    : DOT_ID
    | '.' uid
    ;


//    Literals

decimalLiteral
    : DECIMAL_LITERAL | ZERO_DECIMAL | ONE_DECIMAL | TWO_DECIMAL
    ;

stringLiteral
    : STRING_LITERAL+
    ;

booleanLiteral
    : TRUE | FALSE;

hexadecimalLiteral
    : HEXADECIMAL_LITERAL;

nullLiteral
    : NULL_LITERAL | NULL_SPEC_LITERAL;

nullNotnull
    : NOT? nullLiteral
    ;

constant
    : stringLiteral                                                 #stringLiteralConstant
    | decimalLiteral                                                #positiveDecimalLiteralConstant
    | '-' decimalLiteral                                            #negativeDecimalLiteralConstant
    | hexadecimalLiteral                                            #hexadecimalLiteralConstant
    | booleanLiteral                                                #booleanLiteralConstant
    | REAL_LITERAL                                                  #realLiteralConstant
    | BIT_STRING                                                    #bitStringConstant
    | nullNotnull                                                   #nullLiteralConstant
    ;


//    Data Types

dataType
    : typeName=(
      VARCHAR | TEXT | MEDIUMTEXT | LONGTEXT | STRING
      | INT | INTEGER | BIGINT | BOOL | BOOLEAN | LIST
      | BINARY | NUMBER_LIST | STRING_LIST
      )
    ;

//    Common Lists

uidList
    : uid (',' uid)*
    ;

tables
    : tableName (',' tableName)*
    ;

indexColumnNames
    : '(' indexColumnName (',' indexColumnName)* ')'
    ;

expressions
    : expression (',' expression)*
    ;

expressionsWithDefaults
    : expressionOrDefault (',' expressionOrDefault)*
    ;

constants
    : constant (',' constant)*
    ;

simpleStrings
    : STRING_LITERAL (',' STRING_LITERAL)*
    ;

userVariables
    : LOCAL_ID (',' LOCAL_ID)*
    ;

//    Common Expressons

defaultValue
    : NULL_LITERAL
    ;

expressionOrDefault
    : expression | DEFAULT
    ;

ifExists
    : IF EXISTS;

ifNotExists
    : IF NOT EXISTS;

//    Expressions, predicates
// Simplified approach for expression
expression
    : notOperator=(NOT | '!') expression                            #notExpression
    | left=expression logicalOperator right=expression              #logicalExpression
    | predicate                                                     #predicateExpression
    ;

predicate
    : predicate NOT? IN '(' (selectStatement | expressions) ')'     #inPredicate
    | predicate IS nullNotnull                                      #isNullPredicate
    | left=predicate comparisonOperator right=predicate             #binaryComparasionPredicate
    | predicate NOT? BETWEEN predicate AND predicate                #betweenPredicate
    | expressionAtom                                                #expressionAtomPredicate
    ;

// Add in ASTVisitor nullNotnull in constant
expressionAtom
    : constant                                                      #constantExpressionAtom
    | fullColumnName                                                #fullColumnNameExpressionAtom
    | BINARY expressionAtom                                         #binaryExpressionAtom
    | EXISTS '(' selectStatement ')'                                #existsExpessionAtom
    | left=expressionAtom bitOperator right=expressionAtom          #bitExpressionAtom
    ;

comparisonOperator
    : '=' | '>' | '<' | '<' '=' | '>' '='
    | '<' '>' | '!' '=' // Alias <>
    ;

logicalOperator
    : AND | '&' '&' | OR | '|' '|'
    ;

bitOperator
    : '<' '<' | '>' '>' | '&' | '^' | '|'
    ;

//    Simple id sets
//     (that keyword, which can be id)

privilegesBase
    : TABLES
    ;

intervalTypeBase
    : QUARTER | MONTH | DAY | HOUR
    | MINUTE | WEEK | SECOND | MICROSECOND
    ;

dataTypeBase
    : DATE | TIME | TIMESTAMP | DATETIME | YEAR | ENUM | TEXT
    ;

keywordsCanBeId
    : COLUMNS | FIELDS | HASH | INDEXES | LIST
    | SERIAL | STRING
    | TRUNCATE | VALUE | DATE | TIME | TIMESTAMP | DATETIME | YEAR | NVARCHAR | NATIONAL | TEXT | ENUM 
    | QUARTER | MONTH | DAY | HOUR | MINUTE 
    | WEEK | SECOND | MICROSECOND | TABLES
    ;