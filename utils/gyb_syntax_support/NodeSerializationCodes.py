from Node import error


SYNTAX_NODE_SERIALIZATION_CODES = {
    # 0 is 'Token'. Needs to be defined manually
    # 1 is 'Unknown'. Needs to be defined manually
    'UnknownDecl': 2,
    'TypealiasDecl': 3,
    'AssociatedtypeDecl': 4,
    'IfConfigDecl': 5,
    'PoundErrorDecl': 6,
    'PoundWarningDecl': 7,
    'PoundSourceLocation': 8,
    'ClassDecl': 9,
    'StructDecl': 10,
    'ProtocolDecl': 11,
    'ExtensionDecl': 12,
    'FunctionDecl': 13,
    'InitializerDecl': 14,
    'DeinitializerDecl': 15,
    'SubscriptDecl': 16,
    'ImportDecl': 17,
    'AccessorDecl': 18,
    'VariableDecl': 19,
    'EnumCaseDecl': 20,
    'EnumDecl': 21,
    'OperatorDecl': 22,
    'PrecedenceGroupDecl': 23,
    'UnknownExpr': 24,
    'InOutExpr': 25,
    'PoundColumnExpr': 26,
    'TryExpr': 27,
    'IdentifierExpr': 28,
    'SuperRefExpr': 29,
    'NilLiteralExpr': 30,
    'DiscardAssignmentExpr': 31,
    'AssignmentExpr': 32,
    'SequenceExpr': 33,
    'PoundLineExpr': 34,
    'PoundFileExpr': 35,
    'PoundFunctionExpr': 36,
    'PoundDsohandleExpr': 37,
    'SymbolicReferenceExpr': 38,
    'PrefixOperatorExpr': 39,
    'BinaryOperatorExpr': 40,
    'ArrowExpr': 41,
    'FloatLiteralExpr': 42,
    'TupleExpr': 43,
    'ArrayExpr': 44,
    'DictionaryExpr': 45,
    'ImplicitMemberExpr': 46,
    'IntegerLiteralExpr': 47,
    'StringLiteralExpr': 48,
    'BooleanLiteralExpr': 49,
    'TernaryExpr': 50,
    'MemberAccessExpr': 51,
    'DotSelfExpr': 52,
    'IsExpr': 53,
    'AsExpr': 54,
    'TypeExpr': 55,
    'ClosureExpr': 56,
    'UnresolvedPatternExpr': 57,
    'FunctionCallExpr': 58,
    'SubscriptExpr': 59,
    'OptionalChainingExpr': 60,
    'ForcedValueExpr': 61,
    'PostfixUnaryExpr': 62,
    'SpecializeExpr': 63,
    'KeyPathExpr': 65,
    'KeyPathBaseExpr': 66,
    'ObjcKeyPathExpr': 67,
    'ObjcSelectorExpr': 68,
    'EditorPlaceholderExpr': 69,
    'ObjectLiteralExpr': 70,
    'UnknownStmt': 71,
    'ContinueStmt': 72,
    'WhileStmt': 73,
    'DeferStmt': 74,
    'ExpressionStmt': 75,
    'RepeatWhileStmt': 76,
    'GuardStmt': 77,
    'ForInStmt': 78,
    'SwitchStmt': 79,
    'DoStmt': 80,
    'ReturnStmt': 81,
    'FallthroughStmt': 82,
    'BreakStmt': 83,
    'DeclarationStmt': 84,
    'ThrowStmt': 85,
    'IfStmt': 86,
    'Decl': 87,
    'Expr': 88,
    'Stmt': 89,
    'Type': 90,
    'Pattern': 91,
    'CodeBlockItem': 92,
    'CodeBlock': 93,
    'DeclNameArgument': 94,
    'DeclNameArguments': 95,
    # removed: 'FunctionCallArgument': 96,
    'TupleExprElement': 97,
    'ArrayElement': 98,
    'DictionaryElement': 99,
    'ClosureCaptureItem': 100,
    'ClosureCaptureSignature': 101,
    'ClosureParam': 102,
    'ClosureSignature': 103,
    'StringSegment': 104,
    'ExpressionSegment': 105,
    'ObjcNamePiece': 106,
    'TypeInitializerClause': 107,
    'ParameterClause': 108,
    'ReturnClause': 109,
    'FunctionSignature': 110,
    'IfConfigClause': 111,
    'PoundSourceLocationArgs': 112,
    'DeclModifier': 113,
    'InheritedType': 114,
    'TypeInheritanceClause': 115,
    'MemberDeclBlock': 116,
    'MemberDeclListItem': 117,
    'SourceFile': 118,
    'InitializerClause': 119,
    'FunctionParameter': 120,
    'AccessLevelModifier': 121,
    'AccessPathComponent': 122,
    'AccessorParameter': 123,
    'AccessorBlock': 124,
    'PatternBinding': 125,
    'EnumCaseElement': 126,
    'OperatorPrecedenceAndTypes': 127,
    'PrecedenceGroupRelation': 128,
    'PrecedenceGroupNameElement': 129,
    'PrecedenceGroupAssignment': 130,
    'PrecedenceGroupAssociativity': 131,
    'Attribute': 132,
    'LabeledSpecializeEntry': 133,
    'ImplementsAttributeArguments': 134,
    'ObjCSelectorPiece': 135,
    'WhereClause': 136,
    'ConditionElement': 137,
    'AvailabilityCondition': 138,
    'MatchingPatternCondition': 139,
    'OptionalBindingCondition': 140,
    'ElseIfContinuation': 141,
    'ElseBlock': 142,
    'SwitchCase': 143,
    'SwitchDefaultLabel': 144,
    'CaseItem': 145,
    'SwitchCaseLabel': 146,
    'CatchClause': 147,
    'GenericWhereClause': 148,
    'SameTypeRequirement': 149,
    'GenericParameter': 150,
    'GenericParameterClause': 151,
    'ConformanceRequirement': 152,
    'CompositionTypeElement': 153,
    'TupleTypeElement': 154,
    'GenericArgument': 155,
    'GenericArgumentClause': 156,
    'TypeAnnotation': 157,
    'TuplePatternElement': 158,
    'AvailabilityArgument': 159,
    'AvailabilityLabeledArgument': 160,
    'AvailabilityVersionRestriction': 161,
    'VersionTuple': 162,
    'CodeBlockItemList': 163,
    # removed: 'FunctionCallArgumentList': 164,
    'TupleExprElementList': 165,
    'ArrayElementList': 166,
    'DictionaryElementList': 167,
    'StringLiteralSegments': 168,
    'DeclNameArgumentList': 169,
    'ExprList': 170,
    'ClosureCaptureItemList': 171,
    'ClosureParamList': 172,
    'ObjcName': 173,
    'FunctionParameterList': 174,
    'IfConfigClauseList': 175,
    'InheritedTypeList': 176,
    'MemberDeclList': 177,
    'ModifierList': 178,
    'AccessPath': 179,
    'AccessorList': 180,
    'PatternBindingList': 181,
    'EnumCaseElementList': 182,
    'PrecedenceGroupAttributeList': 183,
    'PrecedenceGroupNameList': 184,
    'TokenList': 185,
    'NonEmptyTokenList': 186,
    'AttributeList': 187,
    'SpecializeAttributeSpecList': 188,
    'ObjCSelector': 189,
    'SwitchCaseList': 190,
    'CatchClauseList': 191,
    'CaseItemList': 192,
    'ConditionElementList': 193,
    'GenericRequirementList': 194,
    'GenericParameterList': 195,
    'CompositionTypeElementList': 196,
    'TupleTypeElementList': 197,
    'GenericArgumentList': 198,
    'TuplePatternElementList': 199,
    'AvailabilitySpecList': 200,
    'UnknownPattern': 201,
    'EnumCasePattern': 202,
    'IsTypePattern': 203,
    'OptionalPattern': 204,
    'IdentifierPattern': 205,
    'AsTypePattern': 206,
    'TuplePattern': 207,
    'WildcardPattern': 208,
    'ExpressionPattern': 209,
    'ValueBindingPattern': 210,
    'UnknownType': 211,
    'SimpleTypeIdentifier': 212,
    'MemberTypeIdentifier': 213,
    'ClassRestrictionType': 214,
    'ArrayType': 215,
    'DictionaryType': 216,
    'MetatypeType': 217,
    'OptionalType': 218,
    'ImplicitlyUnwrappedOptionalType': 219,
    'CompositionType': 220,
    'TupleType': 221,
    'FunctionType': 222,
    'AttributedType': 223,
    'YieldStmt': 224,
    'YieldList': 225,
    'IdentifierList': 226,
    'NamedAttributeStringArgument': 227,
    'DeclName': 228,
    'PoundAssertStmt': 229,
    'SomeType': 230,
    'CustomAttribute': 231,
    'GenericRequirement': 232,
    'DifferentiableAttributeArguments': 233,
    'DifferentiationParamsClause': 234,
    'DifferentiationParams': 235,
    'DifferentiationParamList': 236,
    'DifferentiationParam': 237,
    'DifferentiableAttributeFuncSpecifier': 238,
    'FunctionDeclName': 239,
    'PoundFilePathExpr': 240,
    'DerivativeRegistrationAttributeArguments': 241,
    'QualifiedDeclName': 242,
    'MultipleTrailingClosureClause': 243,
    'MultipleTrailingClosureElementList': 244,
    'MultipleTrailingClosureElement': 245,
}


def verify_syntax_node_serialization_codes(nodes, serialization_codes):
    # Verify that all nodes have serialization codes
    for node in nodes:
        if not node.is_base() and node.syntax_kind not in serialization_codes:
            error('Node %s has no serialization code' % node.syntax_kind)

    # Verify that no serialization code is used twice
    used_codes = set()
    for serialization_code in serialization_codes.values():
        if serialization_code in used_codes:
            error("Serialization code %d used twice" % serialization_code)
        used_codes.add(serialization_code)


def get_serialization_code(syntax_kind):
    return SYNTAX_NODE_SERIALIZATION_CODES[syntax_kind]
