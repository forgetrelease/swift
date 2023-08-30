//===--- ASTDumper.cpp - Swift Language AST Dumper ------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
//  This file implements dumping for the Swift ASTs.
//
//===----------------------------------------------------------------------===//

#include "swift/AST/ASTContext.h"
#include "swift/AST/ASTPrinter.h"
#include "swift/AST/ASTVisitor.h"
#include "swift/AST/Attr.h"
#include "swift/AST/ClangModuleLoader.h"
#include "swift/AST/ForeignAsyncConvention.h"
#include "swift/AST/ForeignErrorConvention.h"
#include "swift/AST/GenericEnvironment.h"
#include "swift/AST/Initializer.h"
#include "swift/AST/PackConformance.h"
#include "swift/AST/ParameterList.h"
#include "swift/AST/ProtocolConformance.h"
#include "swift/AST/SourceFile.h"
#include "swift/AST/TypeVisitor.h"
#include "swift/Basic/Defer.h"
#include "swift/Basic/QuotedString.h"
#include "swift/Basic/STLExtras.h"
#include "clang/AST/Type.h"
#include "llvm/ADT/APFloat.h"
#include "llvm/ADT/Optional.h"
#include "llvm/ADT/SmallString.h"
#include "llvm/ADT/StringExtras.h"
#include "llvm/Support/ErrorHandling.h"
#include "llvm/Support/FileSystem.h"
#include "llvm/Support/Process.h"
#include "llvm/Support/SaveAndRestore.h"
#include "llvm/Support/raw_ostream.h"

using namespace swift;

struct TerminalColor {
  llvm::raw_ostream::Colors Color;
  bool Bold;
};

#define DEF_COLOR(NAME, COLOR, BOLD) \
static const TerminalColor NAME##Color = { llvm::raw_ostream::COLOR, BOLD };

DEF_COLOR(Func, YELLOW, false)
DEF_COLOR(Range, YELLOW, false)
DEF_COLOR(AccessLevel, YELLOW, false)
DEF_COLOR(ASTNode, YELLOW, true)
DEF_COLOR(Parameter, YELLOW, false)
DEF_COLOR(Extension, MAGENTA, false)
DEF_COLOR(Pattern, RED, true)
DEF_COLOR(Override, RED, false)
DEF_COLOR(Stmt, RED, true)
DEF_COLOR(Captures, RED, false)
DEF_COLOR(Arguments, RED, false)
DEF_COLOR(TypeRepr, GREEN, false)
DEF_COLOR(LiteralValue, GREEN, false)
DEF_COLOR(Decl, GREEN, true)
DEF_COLOR(Parenthesis, BLUE, false)
DEF_COLOR(Type, BLUE, false)
DEF_COLOR(Discriminator, BLUE, false)
DEF_COLOR(InterfaceType, GREEN, false)
DEF_COLOR(Identifier, GREEN, false)
DEF_COLOR(Expr, MAGENTA, true)
DEF_COLOR(ExprModifier, CYAN, false)
DEF_COLOR(DeclModifier, CYAN, false)
DEF_COLOR(ArgModifier, CYAN, false)
DEF_COLOR(ClosureModifier, CYAN, false)
DEF_COLOR(FieldLabel, CYAN, false)
DEF_COLOR(Location, CYAN, false)

#undef DEF_COLOR

namespace {
  /// RAII object that prints with the given color, if color is supported on the
  /// given stream.
  class PrintWithColorRAII {
    raw_ostream &OS;
    bool ShowColors;

  public:
    PrintWithColorRAII(raw_ostream &os, TerminalColor color)
    : OS(os), ShowColors(false)
    {
      ShowColors = os.has_colors();

      if (ShowColors)
        OS.changeColor(color.Color, color.Bold);
    }

    ~PrintWithColorRAII() {
      if (ShowColors) {
        OS.resetColor();
      }
    }

    raw_ostream &getOS() const { return OS; }

    template<typename T>
    friend raw_ostream &operator<<(PrintWithColorRAII &&printer,
                                   const T &value){
      printer.OS << value;
      return printer.OS;
    }

  };
} // end anonymous namespace

static void printGenericParameters(raw_ostream &OS, GenericParamList *Params) {
  if (!Params)
    return;
  OS << ' ';
  Params->print(OS);
}

static void printSourceRange(raw_ostream &OS, const SourceRange R,
                             const ASTContext &Ctx) {
  if (!R.isValid())
    return;

  PrintWithColorRAII(OS, RangeColor) << " range=";
  R.print(PrintWithColorRAII(OS, RangeColor).getOS(), Ctx.SourceMgr,
          /*PrintText=*/false);
}

static StringRef getDumpString(SILFunctionType::Representation value) {
  switch (value) {
  case SILFunctionType::Representation::Thick: return "thick";
  case SILFunctionType::Representation::Block: return "block";
  case SILFunctionType::Representation::CFunctionPointer: return "c";
  case SILFunctionType::Representation::CXXMethod:
    return "cxx_method";
  case SILFunctionType::Representation::Thin: return "thin";
  case SILFunctionType::Representation::Method: return "method";
  case SILFunctionType::Representation::ObjCMethod: return "objc_method";
  case SILFunctionType::Representation::WitnessMethod: return "witness_method";
  case SILFunctionType::Representation::Closure: return "closure";
  }

  llvm_unreachable("Unhandled SILFunctionTypeRepresentation in switch.");
}

static StringRef getDumpString(ReadImplKind kind) {
  switch (kind) {
  case ReadImplKind::Stored:
    return "stored";
  case ReadImplKind::Inherited:
    return "inherited";
  case ReadImplKind::Get:
    return "getter";
  case ReadImplKind::Address:
    return "addressor";
  case ReadImplKind::Read:
    return "read_coroutine";
  }
  llvm_unreachable("bad kind");
}

static StringRef getDumpString(WriteImplKind kind) {
  switch (kind) {
  case WriteImplKind::Immutable:
    return "immutable";
  case WriteImplKind::Stored:
    return "stored";
  case WriteImplKind::StoredWithObservers:
    return "stored_with_observers";
  case WriteImplKind::InheritedWithObservers:
    return "inherited_with_observers";
  case WriteImplKind::Set:
    return "setter";
  case WriteImplKind::MutableAddress:
    return "mutable_addressor";
  case WriteImplKind::Modify:
    return "modify_coroutine";
  }
  llvm_unreachable("bad kind");
}

static StringRef getDumpString(ReadWriteImplKind kind) {
  switch (kind) {
  case ReadWriteImplKind::Immutable:
    return "immutable";
  case ReadWriteImplKind::Stored:
    return "stored";
  case ReadWriteImplKind::MutableAddress:
    return "mutable_addressor";
  case ReadWriteImplKind::MaterializeToTemporary:
    return "materialize_to_temporary";
  case ReadWriteImplKind::Modify:
    return "modify_coroutine";
  case ReadWriteImplKind::StoredWithDidSet:
    return "stored_with_didset";
  case ReadWriteImplKind::InheritedWithDidSet:
    return "inherited_with_didset";
  }
  llvm_unreachable("bad kind");
}

static StringRef getDumpString(ImportKind value) {
  switch (value) {
  case ImportKind::Module: return "module";
  case ImportKind::Type: return "type";
  case ImportKind::Struct: return "struct";
  case ImportKind::Class: return "class";
  case ImportKind::Enum: return "enum";
  case ImportKind::Protocol: return "protocol";
  case ImportKind::Var: return "var";
  case ImportKind::Func: return "func";
  }
  
  llvm_unreachable("Unhandled ImportKind in switch.");
}

static StringRef getDumpString(ForeignErrorConvention::Kind value) {
  switch (value) {
  case ForeignErrorConvention::ZeroResult: return "ZeroResult";
  case ForeignErrorConvention::NonZeroResult: return "NonZeroResult";
  case ForeignErrorConvention::ZeroPreservedResult: return "ZeroPreservedResult";
  case ForeignErrorConvention::NilResult: return "NilResult";
  case ForeignErrorConvention::NonNilError: return "NonNilError";
  }

  llvm_unreachable("Unhandled ForeignErrorConvention in switch.");
}
static StringRef getDumpString(DefaultArgumentKind value) {
  switch (value) {
    case DefaultArgumentKind::None: return "none";
#define MAGIC_IDENTIFIER(NAME, STRING, SYNTAX_KIND) \
    case DefaultArgumentKind::NAME: return STRING;
#include "swift/AST/MagicIdentifierKinds.def"
    case DefaultArgumentKind::Inherited: return "inherited";
    case DefaultArgumentKind::NilLiteral: return "nil";
    case DefaultArgumentKind::EmptyArray: return "[]";
    case DefaultArgumentKind::EmptyDictionary: return "[:]";
    case DefaultArgumentKind::Normal: return "normal";
    case DefaultArgumentKind::StoredProperty: return "stored property";
  }

  llvm_unreachable("Unhandled DefaultArgumentKind in switch.");
}
static StringRef getDumpString(ObjCSelectorExpr::ObjCSelectorKind value) {
  switch (value) {
    case ObjCSelectorExpr::Method: return "method";
    case ObjCSelectorExpr::Getter: return "getter";
    case ObjCSelectorExpr::Setter: return "setter";
  }

  llvm_unreachable("Unhandled ObjCSelectorExpr in switch.");
}
static StringRef getDumpString(AccessSemantics value) {
  switch (value) {
    case AccessSemantics::Ordinary: return "ordinary";
    case AccessSemantics::DirectToStorage: return "direct_to_storage";
    case AccessSemantics::DirectToImplementation: return "direct_to_impl";
    case AccessSemantics::DistributedThunk: return "distributed_thunk";
  }

  llvm_unreachable("Unhandled AccessSemantics in switch.");
}
static StringRef getDumpString(MetatypeRepresentation value) {
  switch (value) {
    case MetatypeRepresentation::Thin: return "thin";
    case MetatypeRepresentation::Thick: return "thick";
    case MetatypeRepresentation::ObjC: return "@objc";
  }

  llvm_unreachable("Unhandled MetatypeRepresentation in switch.");
}
static StringRef getDumpString(StringLiteralExpr::Encoding value) {
  switch (value) {
    case StringLiteralExpr::UTF8: return "utf8";
    case StringLiteralExpr::OneUnicodeScalar: return "unicodeScalar";
  }

  llvm_unreachable("Unhandled StringLiteral in switch.");
}
static StringRef getDumpString(CtorInitializerKind value) {
  switch (value) {
    case CtorInitializerKind::Designated: return "designated";
    case CtorInitializerKind::Convenience: return "convenience";
    case CtorInitializerKind::ConvenienceFactory: return "convenience_factory";
    case CtorInitializerKind::Factory: return "factory";
  }

  llvm_unreachable("Unhandled CtorInitializerKind in switch.");
}
static StringRef getDumpString(Associativity value) {
  switch (value) {
    case Associativity::None: return "none";
    case Associativity::Left: return "left";
    case Associativity::Right: return "right";
  }

  llvm_unreachable("Unhandled Associativity in switch.");
}
static StringRef getDumpString(CheckedCastKind kind) {
  return getCheckedCastKindName(kind);
}
static StringRef getDumpString(bool value) {
  return value ? "true" : "false";
}
static StringRef getDumpString(AccessLevel level) {
  return getAccessLevelSpelling(level);
}
static StringRef getDumpString(LifetimeAnnotation lifetime) {
  switch (lifetime) {
  case LifetimeAnnotation::EagerMove:
    return "_eagerMove";
  case LifetimeAnnotation::Lexical:
    return "_lexical";
  case LifetimeAnnotation::None:
    return "";
  }
  
  llvm_unreachable("Unhandled LifetimeAnnotation in switch.");
}
static StringRef getDumpString(AccessorKind kind) {
  return getAccessorKindString(kind);
}
static StringRef getDumpString(MagicIdentifierLiteralExpr::Kind kind) {
  return MagicIdentifierLiteralExpr::getKindString(kind);
}
static StringRef getDumpString(ObjectLiteralExpr::LiteralKind kind) {
  return ObjectLiteralExpr::getLiteralKindPlainName(kind);
}
static StringRef getDumpString(FunctionRefKind kind) {
  return getFunctionRefKindStr(kind);
}
static StringRef getDumpString(ParamSpecifier specifier) {
  return ParamDecl::getSpecifierSpelling(specifier);
}
static StringRef getDumpString(ValueOwnership ownership) {
  switch (ownership) {
  case ValueOwnership::Default:
      return "";
  case ValueOwnership::Owned:
      return "owned";
  case ValueOwnership::Shared:
      return "shared";
  case ValueOwnership::InOut:
      return "inout";
  }

  llvm_unreachable("Unhandled ValueOwnership in switch.");
}

static void printArgument(raw_ostream &OS, const Argument &arg,
                          unsigned indentLevel,
                          std::function<void(Expr *)> printRec) {
  OS.indent(indentLevel);
  PrintWithColorRAII(OS, ParenthesisColor) << '(';
  PrintWithColorRAII(OS, ExprColor) << "argument";

  auto label = arg.getLabel();
  if (!label.empty()) {
    PrintWithColorRAII(OS, ArgumentsColor) << " label=";
    PrintWithColorRAII(OS, ArgumentsColor) << label.str();
  }
  if (arg.isInOut())
    PrintWithColorRAII(OS, ArgModifierColor) << " inout";

  printRec(arg.getExpr());
  PrintWithColorRAII(OS, ParenthesisColor) << ')';
}

static void printArgumentList(raw_ostream &OS,
                              const ArgumentList *argList,
                              unsigned &indentLevel,
                              std::function<void(Expr *)> printRec,
                              bool indent = true) {
  if (indent)
    indentLevel += 2;

  OS.indent(indentLevel);
  PrintWithColorRAII(OS, ParenthesisColor) << '(';
  PrintWithColorRAII(OS, ExprColor) << "argument_list";

  if (argList->isImplicit())
    PrintWithColorRAII(OS, ArgModifierColor) << " implicit";

  if (argList->hasAnyArgumentLabels()) {
    PrintWithColorRAII(OS, ArgumentsColor) << " labels=";
    for (auto arg : *argList) {
      auto label = arg.getLabel();
      PrintWithColorRAII(OS, ArgumentsColor)
      << (label.empty() ? "_" : label.str()) << ":";
    }
  }

  indentLevel += 2;
  for (auto arg : *argList) {
    OS << '\n';
    printArgument(OS, arg, indentLevel, printRec);
  }
  indentLevel -= 2;

  PrintWithColorRAII(OS, ParenthesisColor) << ')';

  if (indent)
    indentLevel -= 2;
}

//===----------------------------------------------------------------------===//
//  Decl printing.
//===----------------------------------------------------------------------===//

// Print a name.
static void printName(raw_ostream &os, DeclName name) {
  if (!name)
    os << "<anonymous>";
  else
    os << name;
}

static void dumpSubstitutionMapRec(
    SubstitutionMap map, llvm::raw_ostream &out,
    SubstitutionMap::DumpStyle style, unsigned indent,
    llvm::SmallPtrSetImpl<const ProtocolConformance *> &visited);

static Type defaultGetTypeOfExpr(Expr *E) { return E->getType(); }
static Type defaultGetTypeOfKeyPathComponent(KeyPathExpr *E, unsigned index) {
  return E->getComponents()[index].getComponentType();
}

namespace {
  class PrintBase {
  public:
    raw_ostream &OS;
    unsigned Indent;
    llvm::function_ref<Type(Expr *)> GetTypeOfExpr;
    llvm::function_ref<Type(TypeRepr *)> GetTypeOfTypeRepr;
    llvm::function_ref<Type(KeyPathExpr *E, unsigned index)>
        GetTypeOfKeyPathComponent;

    explicit PrintBase(raw_ostream &os, unsigned indent = 0,
                       llvm::function_ref<Type(Expr *)> getTypeOfExpr = defaultGetTypeOfExpr,
                       llvm::function_ref<Type(TypeRepr *)> getTypeOfTypeRepr = nullptr,
                       llvm::function_ref<Type(KeyPathExpr *E, unsigned index)>
                           getTypeOfKeyPathComponent = defaultGetTypeOfKeyPathComponent)
      : OS(os), Indent(indent), GetTypeOfExpr(getTypeOfExpr),
        GetTypeOfTypeRepr(getTypeOfTypeRepr),
        GetTypeOfKeyPathComponent(getTypeOfKeyPathComponent) { }

    void printRec(Decl *D, StringRef label = "");
    void printRec(Expr *E, StringRef label = "");
    void printRec(Stmt *S, const ASTContext *Ctx, StringRef label = "");
    void printRec(TypeRepr *T, StringRef label = "");
    void printRec(const Pattern *P, StringRef label = "");
    void printRec(Type ty, StringRef label = "");

    template <typename NodeTy>
    void printRecLabeled(NodeTy *Node, StringRef label) {
      OS << '\n';
      Indent += 2;
      printHead(label, ASTNodeColor);
      printRec(Node);
      printFoot();
      Indent -= 2;
    }

    raw_ostream &printHead(StringRef Name, TerminalColor Color,
                           StringRef Label = "") {
      OS.indent(Indent);
      PrintWithColorRAII(OS, ParenthesisColor) << '(';
      if (!Label.empty()) {
        PrintWithColorRAII(OS, FieldLabelColor) << Label;
        OS << "=";
      }

      PrintWithColorRAII(OS, Color) << Name;
      return OS;
    }

    raw_ostream &printFoot() {
      PrintWithColorRAII(OS, ParenthesisColor) << ')';
      return OS;
    }
  };

  class PrintPattern : public PatternVisitor<PrintPattern, void, StringRef>,
                       public PrintBase {
  public:
    using PrintBase::PrintBase;

    raw_ostream &printCommon(Pattern *P, const char *Name, StringRef Label) {
     printHead(Name, PatternColor, Label);

      if (P->isImplicit())
        PrintWithColorRAII(OS, ExprModifierColor) << " implicit";

      if (P->hasType()) {
        PrintWithColorRAII(OS, TypeColor) << " type='";
        P->getType().print(PrintWithColorRAII(OS, TypeColor).getOS());
        PrintWithColorRAII(OS, TypeColor) << "'";
      }
      return OS;
    }

    void visitParenPattern(ParenPattern *P, StringRef label) {
      printCommon(P, "pattern_paren", label);
      printRec(P->getSubPattern());
      printFoot();
    }
    void visitTuplePattern(TuplePattern *P, StringRef label) {
      printCommon(P, "pattern_tuple", label);

      OS << " names=";
      interleave(P->getElements(),
                 [&](const TuplePatternElt &elt) {
                   auto name = elt.getLabel();
                   OS << (name.empty() ? "''" : name.str());
                 },
                 [&] { OS << ","; });

      for (auto &elt : P->getElements()) {
        printRec(elt.getPattern());
      }
      printFoot();
    }
    void visitNamedPattern(NamedPattern *P, StringRef label) {
      printCommon(P, "pattern_named", label);
      PrintWithColorRAII(OS, IdentifierColor) << " '" << P->getNameStr() << "'";
      printFoot();
    }
    void visitAnyPattern(AnyPattern *P, StringRef label) {
      if (P->isAsyncLet()) {
        printCommon(P, "async_let ", label);
      }
      printCommon(P, "pattern_any", label);
      printFoot();
    }
    void visitTypedPattern(TypedPattern *P, StringRef label) {
      printCommon(P, "pattern_typed", label);
      printRec(P->getSubPattern());
      if (auto *repr = P->getTypeRepr()) {
        printRec(repr);
      }
      printFoot();
    }

    void visitIsPattern(IsPattern *P, StringRef label) {
      printCommon(P, "pattern_is", label)
        << ' ' << getDumpString(P->getCastKind()) << ' ';
      P->getCastType().print(OS);
      if (auto sub = P->getSubPattern()) {
        printRec(sub);
      }
      printFoot();
    }
    void visitExprPattern(ExprPattern *P, StringRef label) {
      printCommon(P, "pattern_expr", label);
      if (auto m = P->getCachedMatchExpr())
        printRec(m);
      else
        printRec(P->getSubExpr());
      printFoot();
    }
    void visitBindingPattern(BindingPattern *P, StringRef label) {
      printCommon(P, P->isLet() ? "pattern_let" : "pattern_var", label);
      printRec(P->getSubPattern());
      printFoot();
    }
    void visitEnumElementPattern(EnumElementPattern *P, StringRef label) {
      printCommon(P, "pattern_enum_element", label);
      OS << ' ';
      P->getParentType().print(PrintWithColorRAII(OS, TypeColor).getOS());
      PrintWithColorRAII(OS, IdentifierColor) << '.' << P->getName();
      if (P->hasSubPattern()) {
        printRec(P->getSubPattern());
      }
      printFoot();
    }
    void visitOptionalSomePattern(OptionalSomePattern *P, StringRef label) {
      printCommon(P, "pattern_optional_some", label);
      printRec(P->getSubPattern());
      printFoot();
    }
    void visitBoolPattern(BoolPattern *P, StringRef label) {
      printCommon(P, "pattern_bool", label);
      OS << ' ' << getDumpString(P->getValue());
      printFoot();
    }

  };

  /// PrintDecl - Visitor implementation of Decl::print.
  class PrintDecl : public DeclVisitor<PrintDecl, void, StringRef>,
                    public PrintBase {
  public:
    using PrintBase::PrintBase;

  private:
    void printWhereRequirements(
        PointerUnion<const AssociatedTypeDecl *, const GenericContext *> Owner)
        const {
      const auto printWhere = [&](const TrailingWhereClause *Where) {
        if (Where) {
          OS << " where requirements: ";
          Where->print(OS, /*printWhereKeyword*/ false);
        }
      };

      if (const auto GC = Owner.dyn_cast<const GenericContext *>()) {
        printWhere(GC->getTrailingWhereClause());
      } else {
        const auto ATD = Owner.get<const AssociatedTypeDecl *>();
        printWhere(ATD->getTrailingWhereClause());
      }
    }

    // Print a field with a value.
    template<typename T>
    raw_ostream &printField(StringRef name, const T &value) {
      OS << " ";
      PrintWithColorRAII(OS, FieldLabelColor) << name;
      OS << "=" << value;
      return OS;
    }

    void printCommon(Decl *D, const char *Name, StringRef Label,
                     TerminalColor Color = DeclColor) {
     printHead(Name, Color, Label);

      if (D->isImplicit())
        PrintWithColorRAII(OS, DeclModifierColor) << " implicit";

      if (D->isHoisted())
        PrintWithColorRAII(OS, DeclModifierColor) << " hoisted";

      printSourceRange(OS, D->getSourceRange(), D->getASTContext());

      if (D->TrailingSemiLoc.isValid())
        PrintWithColorRAII(OS, DeclModifierColor) << " trailing_semi";
    }

    void printInherited(InheritedTypes Inherited) {
      if (Inherited.empty())
        return;
      OS << " inherits: ";
      interleave(Inherited.getEntries(),
                 [&](InheritedEntry Super) { Super.getType().print(OS); },
                 [&] { OS << ", "; });
    }

  public:
    void visitImportDecl(ImportDecl *ID, StringRef label) {
      printCommon(ID, "import_decl", label);

      if (ID->isExported())
        OS << " exported";

      if (ID->getImportKind() != ImportKind::Module)
        OS << " kind=" << getDumpString(ID->getImportKind());

      OS << " '";
      // Check if module aliasing was used for the given imported module; for
      // example, if '-module-alias Foo=Bar' was passed and this module has
      // 'import Foo', its corresponding real module name 'Bar' should be printed.
      ImportPath::Builder scratch;
      ID->getRealImportPath(scratch).print(OS);
      OS << "')";
    }

    void visitExtensionDecl(ExtensionDecl *ED, StringRef label) {
      printCommon(ED, "extension_decl", label, ExtensionColor);
      OS << ' ';
      if (ED->hasBeenBound())
        ED->getExtendedType().print(OS);
      else
        ED->getExtendedTypeRepr()->print(OS);
      printCommonPost(ED);
    }

    void printDeclName(const ValueDecl *D) {
      if (D->getName()) {
        PrintWithColorRAII(OS, IdentifierColor)
          << '\"' << D->getName() << '\"';
      } else {
        PrintWithColorRAII(OS, IdentifierColor)
          << "'anonname=" << (const void*)D << '\'';
      }
    }

    void visitTypeAliasDecl(TypeAliasDecl *TAD, StringRef label) {
      printCommon(TAD, "typealias", label);
      PrintWithColorRAII(OS, TypeColor) << " type=";
      if (auto underlying = TAD->getCachedUnderlyingType()) {
        PrintWithColorRAII(OS, TypeColor)
          << "'" << underlying.getString() << "'";
      } else {
        PrintWithColorRAII(OS, TypeColor) << "<<<unresolved>>>";
      }
      printWhereRequirements(TAD);
      printFoot();
    }

    void visitOpaqueTypeDecl(OpaqueTypeDecl *OTD, StringRef label) {
      printCommon(OTD, "opaque_type", label);
      OS << " naming_decl=";
      printDeclName(OTD->getNamingDecl());
      PrintWithColorRAII(OS, TypeColor) << " opaque_interface="
        << OTD->getDeclaredInterfaceType().getString();
      OS << " in "
         << OTD->getOpaqueInterfaceGenericSignature()->getAsString();
      if (auto underlyingSubs = OTD->getUniqueUnderlyingTypeSubstitutions()) {
        OS << " underlying:\n";
        SmallPtrSet<const ProtocolConformance *, 4> Dumped;
        dumpSubstitutionMapRec(*underlyingSubs, OS,
                               SubstitutionMap::DumpStyle::Full,
                               Indent + 2, Dumped);
      }
      printFoot();
    }

    void visitGenericTypeParamDecl(GenericTypeParamDecl *decl, StringRef label) {
      printCommon(decl, "generic_type_param", label);
      OS << " depth=" << decl->getDepth() << " index=" << decl->getIndex();
      printFoot();
    }

    void visitAssociatedTypeDecl(AssociatedTypeDecl *decl, StringRef label) {
      printCommon(decl, "associated_type_decl", label);
      if (auto defaultDef = decl->getDefaultDefinitionType()) {
        OS << " default=";
        defaultDef.print(OS);
      }
      printWhereRequirements(decl);
      if (decl->overriddenDeclsComputed()) {
        OS << " overridden=";
        interleave(decl->getOverriddenDecls(),
                   [&](AssociatedTypeDecl *overridden) {
                     OS << overridden->getProtocol()->getName();
                   }, [&]() {
                     OS << ", ";
                   });
      }

      printFoot();
    }

    void visitProtocolDecl(ProtocolDecl *PD, StringRef label) {
      printCommon(PD, "protocol", label);

      OS << " requirement signature=";
      if (PD->isRequirementSignatureComputed()) {
        auto requirements = PD->getRequirementSignatureAsGenericSignature();
        OS << requirements->getAsString();
      } else {
        OS << "<null>";
      }
      printCommonPost(PD);
    }

    void printCommon(ValueDecl *VD, const char *Name, StringRef Label,
                     TerminalColor Color = DeclColor) {
      printCommon((Decl*)VD, Name, Label, Color);

      OS << ' ';
      printDeclName(VD);
      if (auto *AFD = dyn_cast<AbstractFunctionDecl>(VD))
        printGenericParameters(OS, AFD->getParsedGenericParams());
      if (auto *GTD = dyn_cast<GenericTypeDecl>(VD))
        printGenericParameters(OS, GTD->getParsedGenericParams());
      if (auto *MD = dyn_cast<MacroDecl>(VD))
        printGenericParameters(OS, MD->getParsedGenericParams());

      if (VD->hasInterfaceType()) {
        PrintWithColorRAII(OS, InterfaceTypeColor) << " interface type='";
        VD->getInterfaceType()->print(
            PrintWithColorRAII(OS, InterfaceTypeColor).getOS());
        PrintWithColorRAII(OS, InterfaceTypeColor) << "'";
      }

      if (VD->hasAccess()) {
        PrintWithColorRAII(OS, AccessLevelColor) << " access="
          << getDumpString(VD->getFormalAccess());
      }

      if (VD->overriddenDeclsComputed()) {
        auto overridden = VD->getOverriddenDecls();
        if (!overridden.empty()) {
          PrintWithColorRAII(OS, OverrideColor) << " override=";
          interleave(overridden,
                     [&](ValueDecl *overridden) {
                       overridden->dumpRef(
                                PrintWithColorRAII(OS, OverrideColor).getOS());
                     }, [&]() {
                       OS << ", ";
                     });
        }
      }

      auto VarD = dyn_cast<VarDecl>(VD);
      const auto &attrs = VD->getAttrs();
      if (attrs.hasAttribute<FinalAttr>() && !(VarD && VarD->isLet()))
        OS << " final";
      if (attrs.hasAttribute<ObjCAttr>())
        OS << " @objc";
      if (attrs.hasAttribute<DynamicAttr>())
        OS << " dynamic";
      if (auto *attr = attrs.getAttribute<DynamicReplacementAttr>()) {
        OS << " @_dynamicReplacement(for: \"";
        OS << attr->getReplacedFunctionName();
        OS << "\")";
      }
      auto lifetimeString = getDumpString(VD->getLifetimeAnnotation());
      if (!lifetimeString.empty())
        OS << " " << lifetimeString;
    }

    void printCommon(NominalTypeDecl *NTD, const char *Name, StringRef Label,
                     TerminalColor Color = DeclColor) {
      printCommon((ValueDecl *)NTD, Name, Label, Color);

      if (NTD->hasInterfaceType()) {
        if (NTD->isResilient())
          OS << " resilient";
        else
          OS << " non-resilient";
      }
    }

    void printCommonPost(const IterableDeclContext *IDC) {
      switch (IDC->getIterableContextKind()) {
      case IterableDeclContextKind::NominalTypeDecl: {
        const auto NTD = cast<NominalTypeDecl>(IDC);
        printInherited(NTD->getInherited());
        printWhereRequirements(NTD);
        break;
      }
      case IterableDeclContextKind::ExtensionDecl:
        const auto ED = cast<ExtensionDecl>(IDC);
        printInherited(ED->getInherited());
        printWhereRequirements(ED);
        break;
      }

      for (Decl *D : IDC->getMembers()) {
        printRec(D);
      }
      printFoot();
    }

    void visitSourceFile(const SourceFile &SF) {
     printHead("source_file", ASTNodeColor);
      PrintWithColorRAII(OS, LocationColor) << " \"" << SF.getFilename() << '\"';

      if (auto items = SF.getCachedTopLevelItems()) {
        for (auto item : *items) {
          if (item.isImplicit())
            continue;

          if (auto decl = item.dyn_cast<Decl *>()) {
            printRec(decl);
          } else if (auto stmt = item.dyn_cast<Stmt *>()) {
            printRec(stmt, &SF.getASTContext());
          } else {
            auto expr = item.get<Expr *>();
            printRec(expr);
          }
        }
      }
      printFoot();
    }

    void visitVarDecl(VarDecl *VD, StringRef label) {
      printCommon(VD, "var_decl", label);
      if (VD->isDistributed())
        PrintWithColorRAII(OS, DeclModifierColor) << " distributed";
      if (VD->isLet())
        PrintWithColorRAII(OS, DeclModifierColor) << " let";
      if (VD->getAttrs().hasAttribute<LazyAttr>())
        PrintWithColorRAII(OS, DeclModifierColor) << " lazy";
      printStorageImpl(VD);
      printAccessors(VD);
      if (VD->getAttrs().hasAttribute<KnownToBeLocalAttr>()) {
        OS << " known-to-be-local";
      }
      printFoot();
    }

    void printStorageImpl(AbstractStorageDecl *D) {
      if (D->isStatic())
        PrintWithColorRAII(OS, DeclModifierColor) << " type";

      if (D->hasInterfaceType()) {
        auto impl = D->getImplInfo();
        PrintWithColorRAII(OS, DeclModifierColor)
          << " readImpl="
          << getDumpString(impl.getReadImpl());
        if (!impl.supportsMutation()) {
          PrintWithColorRAII(OS, DeclModifierColor)
            << " immutable";
        } else {
          PrintWithColorRAII(OS, DeclModifierColor)
            << " writeImpl="
            << getDumpString(impl.getWriteImpl());
          PrintWithColorRAII(OS, DeclModifierColor)
            << " readWriteImpl="
            << getDumpString(impl.getReadWriteImpl());
        }
      }
    }

    void printAccessors(AbstractStorageDecl *D) {
      for (auto accessor : D->getAllAccessors()) {
        printRec(accessor);
      }
    }

    void visitParamDecl(ParamDecl *PD, StringRef label) {
      printHead("parameter", ParameterColor, label) << ' ';
      if (PD->getAttrs().hasAttribute<KnownToBeLocalAttr>()) {
        OS << "known-to-be-local ";
      }
      printDeclName(PD);
      if (!PD->getArgumentName().empty())
        PrintWithColorRAII(OS, IdentifierColor)
          << " apiName=" << PD->getArgumentName();

      if (PD->hasInterfaceType()) {
        PrintWithColorRAII(OS, InterfaceTypeColor) << " interface type='";
        PD->getInterfaceType().print(
            PrintWithColorRAII(OS, InterfaceTypeColor).getOS());
        PrintWithColorRAII(OS, InterfaceTypeColor) << "'";
      }

      if (auto specifier = PD->getCachedSpecifier()) {
        if (*specifier != ParamDecl::Specifier::Default) {
          OS << ' ' << ParamDecl::getSpecifierSpelling(*specifier);
        }
      }

      if (PD->hasInterfaceType())
        if (PD->isVariadic())
          OS << " variadic";

      if (PD->isAutoClosure())
        OS << " autoclosure";

      if (PD->getAttrs().hasAttribute<NonEphemeralAttr>())
        OS << " nonEphemeral";

      auto lifetimeString =
          getDumpString(PD->getLifetimeAnnotationFromAttributes());
      if (!lifetimeString.empty())
        OS << " " << lifetimeString;

      if (PD->isNoImplicitCopy())
        OS << " noImplicitCopy";

      if (PD->getDefaultArgumentKind() != DefaultArgumentKind::None) {
        printField("default_arg",
                   getDumpString(PD->getDefaultArgumentKind()));
      }

      if (PD->hasDefaultExpr() &&
          !PD->getDefaultArgumentCaptureInfo().isTrivial()) {
        OS << " ";
        PD->getDefaultArgumentCaptureInfo().print(
          PrintWithColorRAII(OS, CapturesColor).getOS());
      }

      if (auto init = PD->getStructuralDefaultExpr()) {
        printRecLabeled(init, "expression");
      }

      printFoot();
    }

    void visitEnumCaseDecl(EnumCaseDecl *ECD, StringRef label) {
      printCommon(ECD, "enum_case_decl", label);
      for (EnumElementDecl *D : ECD->getElements()) {
        printRec(D);
      }
      printFoot();
    }

    void visitEnumDecl(EnumDecl *ED, StringRef label) {
      printCommon(ED, "enum_decl", label);
      printCommonPost(ED);
    }

    void visitEnumElementDecl(EnumElementDecl *EED, StringRef label) {
      printCommon(EED, "enum_element_decl", label);
      if (auto *paramList = EED->getParameterList()) {
        Indent += 2;
        OS << "\n";
        printParameterList(paramList);
        Indent -= 2;
      }
      printFoot();
    }

    void visitStructDecl(StructDecl *SD, StringRef label) {
      printCommon(SD, "struct_decl", label);
      printCommonPost(SD);
    }

    void visitClassDecl(ClassDecl *CD, StringRef label) {
      printCommon(CD, "class_decl", label);
      if (CD->isExplicitActor()) {
        OS << " actor";
      } else if (CD->isExplicitDistributedActor()) {
        OS << " distributed actor";
      }
      if (CD->getAttrs().hasAttribute<StaticInitializeObjCMetadataAttr>())
        OS << " @_staticInitializeObjCMetadata";
      printCommonPost(CD);
    }

    void visitBuiltinTupleDecl(BuiltinTupleDecl *BTD, StringRef label) {
      printCommon(BTD, "builtin_tuple_decl", label);
      printCommonPost(BTD);
    }

    void visitPatternBindingDecl(PatternBindingDecl *PBD, StringRef label) {
      printCommon(PBD, "pattern_binding_decl", label);

      for (auto idx : range(PBD->getNumPatternEntries())) {
        printRec(PBD->getPattern(idx));
        if (PBD->getOriginalInit(idx)) {
          OS << '\n';
          OS.indent(Indent + 2);
          OS << "Original init:";
          printRec(PBD->getOriginalInit(idx));
        }
        if (PBD->getInit(idx)) {
          OS << '\n';
          OS.indent(Indent + 2);
          OS << "Processed init:";
          printRec(PBD->getInit(idx));
        }
      }
      printFoot();
    }

    void visitSubscriptDecl(SubscriptDecl *SD, StringRef label) {
      printCommon(SD, "subscript_decl", label);
      printStorageImpl(SD);
      printAccessors(SD);
      printFoot();
    }

    void printCommonAFD(AbstractFunctionDecl *D, const char *Type, StringRef Label) {
      printCommon(D, Type, Label, FuncColor);
      if (!D->getCaptureInfo().isTrivial()) {
        OS << " ";
        D->getCaptureInfo().print(OS);
      }

      if (D->getAttrs().hasAttribute<NonisolatedAttr>()) {
        PrintWithColorRAII(OS, ExprModifierColor) << " nonisolated";
      }
      if (D->isDistributed()) {
        PrintWithColorRAII(OS, ExprModifierColor) << " distributed";
      }
      if (D->isDistributedThunk()) {
        PrintWithColorRAII(OS, ExprModifierColor) << " distributed-thunk";
      }

      if (auto fac = D->getForeignAsyncConvention()) {
        OS << " foreign_async=";
        if (auto type = fac->completionHandlerType())
          type.print(OS);
        OS << ",completion_handler_param="
           << fac->completionHandlerParamIndex();
        if (auto errorParamIndex = fac->completionHandlerErrorParamIndex())
          OS << ",error_param=" << *errorParamIndex;
      }

      if (auto fec = D->getForeignErrorConvention()) {
        OS << " foreign_error=";
        OS << getDumpString(fec->getKind());
        bool wantResultType = (
          fec->getKind() == ForeignErrorConvention::ZeroResult ||
          fec->getKind() == ForeignErrorConvention::NonZeroResult);

        OS << ((fec->isErrorOwned() == ForeignErrorConvention::IsOwned)
                ? ",owned"
                : ",unowned");
        OS << ",param=" << llvm::utostr(fec->getErrorParameterIndex());
        OS << ",paramtype=" << fec->getErrorParameterType().getString();
        if (wantResultType)
          OS << ",resulttype=" << fec->getResultType().getString();
      }
    }

    void printParameter(const ParamDecl *P) {
      OS << '\n';
      visitParamDecl(const_cast<ParamDecl *>(P), "");
    }

    void printParameterList(const ParameterList *params, const ASTContext *ctx = nullptr) {
      printHead("parameter_list", ParameterColor);

      if (!ctx && params->size() != 0 && params->get(0))
        ctx = &params->get(0)->getASTContext();

      if (ctx) {
        printSourceRange(OS, params->getSourceRange(), *ctx);
      }

      Indent += 2;
      for (auto P : *params) {
        printParameter(P);
      }
      Indent -= 2;

      printFoot();
    }

    void printAbstractFunctionDecl(AbstractFunctionDecl *D) {
      Indent += 2;
      if (auto *P = D->getImplicitSelfDecl()) {
        printParameter(P);
      }

      OS << '\n';
      printParameterList(D->getParameters(), &D->getASTContext());
      Indent -= 2;

      if (auto FD = dyn_cast<FuncDecl>(D)) {
        if (FD->getResultTypeRepr()) {
          OS << '\n';
          Indent += 2;
          printHead("result", DeclColor);
          printRec(FD->getResultTypeRepr());
          printFoot();
          if (auto opaque = FD->getOpaqueResultTypeDecl()) {
            OS << '\n';
            printHead("opaque_result_decl", DeclColor) << '\n';
            printRec(opaque);
            printFoot();
          }
          Indent -= 2;
        }
      }

      if (D->hasSingleExpressionBody()) {
        // There won't be an expression if this is an initializer that was
        // originally spelled "init?(...) { nil }", because "nil" is modeled
        // via FailStmt in this context.
        if (auto *Body = D->getSingleExpressionBody()) {
          printRec(Body);

          return;
        }
      }

      if (auto Body = D->getBody(/*canSynthesize=*/false)) {
        printRec(Body, &D->getASTContext());
      }
    }

    void printCommonFD(FuncDecl *FD, const char *type, StringRef Label) {
      printCommonAFD(FD, type, Label);
      if (FD->isStatic())
        OS << " type";
    }

    void visitFuncDecl(FuncDecl *FD, StringRef label) {
      printCommonFD(FD, "func_decl", label);
      printAbstractFunctionDecl(FD);
      printFoot();
    }

    void visitAccessorDecl(AccessorDecl *AD, StringRef label) {
      printCommonFD(AD, "accessor_decl", label);
      OS << " " << getDumpString(AD->getAccessorKind());
      OS << " for=" << AD->getStorage()->getName();
      printAbstractFunctionDecl(AD);
      printFoot();
    }

    void visitConstructorDecl(ConstructorDecl *CD, StringRef label) {
      printCommonAFD(CD, "constructor_decl", label);
      if (CD->isRequired())
        PrintWithColorRAII(OS, DeclModifierColor) << " required";
      PrintWithColorRAII(OS, DeclModifierColor) << " "
        << getDumpString(CD->getInitKind());
      if (CD->isFailable())
        PrintWithColorRAII(OS, DeclModifierColor) << " failable="
          << (CD->isImplicitlyUnwrappedOptional()
              ? "ImplicitlyUnwrappedOptional"
              : "Optional");
      printAbstractFunctionDecl(CD);
      printFoot();
    }

    void visitDestructorDecl(DestructorDecl *DD, StringRef label) {
      printCommonAFD(DD, "destructor_decl", label);
      printAbstractFunctionDecl(DD);
      printFoot();
    }

    void visitTopLevelCodeDecl(TopLevelCodeDecl *TLCD, StringRef label) {
      printCommon(TLCD, "top_level_code_decl", label);
      if (TLCD->getBody()) {
        printRec(TLCD->getBody(), &static_cast<Decl *>(TLCD)->getASTContext());
      }
      printFoot();
    }
    
    void printASTNodes(const ArrayRef<ASTNode> &Elements, const ASTContext &Ctx, StringRef Name) {
      printHead(Name, ASTNodeColor);
      for (auto Elt : Elements) {
        if (auto *SubExpr = Elt.dyn_cast<Expr*>())
          printRec(SubExpr);
        else if (auto *SubStmt = Elt.dyn_cast<Stmt*>())
          printRec(SubStmt, &Ctx);
        else
          printRec(Elt.get<Decl*>());
      }
      printFoot();
    }

    void visitIfConfigDecl(IfConfigDecl *ICD, StringRef label) {
      printCommon(ICD, "if_config_decl", label);
      Indent += 2;
      for (auto &Clause : ICD->getClauses()) {
        OS << '\n';
        OS.indent(Indent);
        PrintWithColorRAII(OS, StmtColor) << (Clause.Cond ? "#if:" : "#else:");
        if (Clause.isActive)
          PrintWithColorRAII(OS, DeclModifierColor) << " active";
        if (Clause.Cond) {
          printRec(Clause.Cond);
        }

        OS << '\n';
        Indent += 2;
        printASTNodes(Clause.Elements, ICD->getASTContext(), "elements");
        Indent -= 2;
      }

      Indent -= 2;
      printFoot();
    }

    void visitPoundDiagnosticDecl(PoundDiagnosticDecl *PDD, StringRef label) {
      printCommon(PDD, "pound_diagnostic_decl", label);
      auto kind = PDD->isError() ? "error" : "warning";
      OS << " kind=" << kind;
      printRec(PDD->getMessage());
      printFoot();
    }

    void visitPrecedenceGroupDecl(PrecedenceGroupDecl *PGD, StringRef label) {
      printCommon(PGD, "precedence_group_decl ", label);
      printName(OS, PGD->getName());
      OS << " associativity=" << getDumpString(PGD->getAssociativity());
      OS << " assignment=" << getDumpString(PGD->isAssignment());

      auto printRelations =
          [&](StringRef label, ArrayRef<PrecedenceGroupDecl::Relation> rels) {
        if (rels.empty()) return;
        OS << '\n';
        printHead(label, FieldLabelColor);
        for (auto &rel : rels)
          OS << ' ' << rel.Name;
        printFoot();
      };
      printRelations("higherThan", PGD->getHigherThan());
      printRelations("lowerThan", PGD->getLowerThan());

      printFoot();
    }

    void visitInfixOperatorDecl(InfixOperatorDecl *IOD, StringRef label) {
      printCommon(IOD, "infix_operator_decl ", label);
      printName(OS, IOD->getName());
      if (!IOD->getPrecedenceGroupName().empty())
        OS << " precedence_group_name=" << IOD->getPrecedenceGroupName();
      printFoot();
    }

    void visitPrefixOperatorDecl(PrefixOperatorDecl *POD, StringRef label) {
      printCommon(POD, "prefix_operator_decl ", label);
      printName(OS, POD->getName());
      printFoot();
    }

    void visitPostfixOperatorDecl(PostfixOperatorDecl *POD, StringRef label) {
      printCommon(POD, "postfix_operator_decl ", label);
      printName(OS, POD->getName());
      printFoot();
    }

    void visitModuleDecl(ModuleDecl *MD, StringRef label) {
      printCommon(MD, "module", label);

      if (MD->isNonSwiftModule())
        OS << " non_swift";
      
      printFoot();
    }

    void visitMissingDecl(MissingDecl *missing, StringRef label) {
      printCommon(missing, "missing_decl", label);
      printFoot();
    }

    void visitMissingMemberDecl(MissingMemberDecl *MMD, StringRef label) {
      printCommon(MMD, "missing_member_decl ", label);
      PrintWithColorRAII(OS, IdentifierColor)
          << '\"' << MMD->getName() << '\"';
      printFoot();
    }

    void visitMacroDecl(MacroDecl *MD, StringRef label) {
      printCommon(MD, "macro_decl", label);
      // TODO: Fill this in?
      printFoot();
    }

    void visitMacroExpansionDecl(MacroExpansionDecl *MED, StringRef label) {
      printCommon(MED, "macro_expansion_decl ", label);
      OS << MED->getMacroName();
      OS << '\n';
      printArgumentList(OS, MED->getArgs(), Indent,
                        [&](Expr *E) { printRec(E); });
      printFoot();
    }
  };
} // end anonymous namespace

void ParameterList::dump() const {
  dump(llvm::errs(), 0);
}

void ParameterList::dump(raw_ostream &OS, unsigned Indent) const {
  PrintDecl(OS, Indent).printParameterList(this);
  llvm::errs() << '\n';
}

void Decl::dump() const {
  dump(llvm::errs(), 0);
}

void Decl::dump(const char *filename) const {
  std::error_code ec;
  llvm::raw_fd_ostream stream(filename, ec, llvm::sys::fs::FA_Read |
                              llvm::sys::fs::FA_Write);
  // In assert builds, we blow up. Otherwise, we just return.
  assert(!ec && "Failed to open file for dumping?!");
  if (ec)
    return;
  dump(stream, 0);
}

void Decl::dump(raw_ostream &OS, unsigned Indent) const {
  PrintDecl(OS, Indent).visit(const_cast<Decl *>(this), "");
  OS << '\n';
}

/// Print the given declaration context (with its parents).
void swift::printContext(raw_ostream &os, DeclContext *dc) {
  if (auto parent = dc->getParent()) {
    printContext(os, parent);
    os << '.';
  }

  switch (dc->getContextKind()) {
  case DeclContextKind::Package:
    printName(os, cast<PackageUnit>(dc)->getName());
    break;

  case DeclContextKind::Module:
    printName(os, cast<ModuleDecl>(dc)->getRealName());
    break;

  case DeclContextKind::FileUnit:
    // FIXME: print the file's basename?
    os << "(file)";
    break;

  case DeclContextKind::SerializedLocal:
    os << "local context";
    break;

  case DeclContextKind::AbstractClosureExpr: {
    auto *ACE = cast<AbstractClosureExpr>(dc);
    if (isa<ClosureExpr>(ACE)) {
      PrintWithColorRAII(os, DiscriminatorColor)
        << "explicit closure discriminator=";
    }
    if (isa<AutoClosureExpr>(ACE)) {
      PrintWithColorRAII(os, DiscriminatorColor)
        << "autoclosure discriminator=";
    }

    // If we aren't printing to standard error or the debugger output stream,
    // this client expects to see the computed discriminator. Compute it now.
    if (&os != &llvm::errs() && &os != &llvm::dbgs())
      (void)ACE->getDiscriminator();

    PrintWithColorRAII(os, DiscriminatorColor) << ACE->getRawDiscriminator();
    break;
  }

  case DeclContextKind::GenericTypeDecl:
    printName(os, cast<GenericTypeDecl>(dc)->getName());
    break;

  case DeclContextKind::ExtensionDecl:
    if (auto extendedNominal = cast<ExtensionDecl>(dc)->getExtendedNominal()) {
      printName(os, extendedNominal->getName());
    }
    os << " extension";
    break;

  case DeclContextKind::Initializer:
    switch (cast<Initializer>(dc)->getInitializerKind()) {
    case InitializerKind::PatternBinding:
      os << "pattern binding initializer";
      break;
    case InitializerKind::DefaultArgument:
      os << "default argument initializer";
      break;
    case InitializerKind::PropertyWrapper:
      os << "property wrapper initializer";
      break;
    }
    break;

  case DeclContextKind::TopLevelCodeDecl:
    os << "top-level code";
    break;

  case DeclContextKind::AbstractFunctionDecl:
    printName(os, cast<AbstractFunctionDecl>(dc)->getName());
    break;

  case DeclContextKind::SubscriptDecl:
    printName(os, cast<SubscriptDecl>(dc)->getName());
    break;

  case DeclContextKind::EnumElementDecl:
    printName(os, cast<EnumElementDecl>(dc)->getName());
    break;

  case DeclContextKind::MacroDecl:
    printName(os, cast<MacroDecl>(dc)->getName());
    break;
  }
}

std::string ValueDecl::printRef() const {
  std::string result;
  llvm::raw_string_ostream os(result);
  dumpRef(os);
  return os.str();
}

void ValueDecl::dumpRef(raw_ostream &os) const {
  if (!isa<ModuleDecl>(this)) {
    // Print the context.
    printContext(os, getDeclContext());
    os << ".";
    // Print name.
    getName().printPretty(os);
  } else {
    auto moduleName = cast<ModuleDecl>(this)->getRealName();
    os << moduleName;
  }

  if (getAttrs().hasAttribute<KnownToBeLocalAttr>()) {
    os << " known-to-be-local";
  }

  // Print location.
  auto &srcMgr = getASTContext().SourceMgr;
  if (getLoc().isValid()) {
    os << '@';
    getLoc().print(os, srcMgr);
  }
}

void LLVM_ATTRIBUTE_USED ValueDecl::dumpRef() const {
  dumpRef(llvm::errs());
  llvm::errs() << "\n";
}

void SourceFile::dump() const {
  dump(llvm::errs());
}

void SourceFile::dump(llvm::raw_ostream &OS, bool parseIfNeeded) const {
  // If we're allowed to parse the SourceFile, do so now. We need to force the
  // parsing request as by default the dumping logic tries not to kick any
  // requests.
  if (parseIfNeeded)
    (void)getTopLevelItems();

  PrintDecl(OS).visitSourceFile(*this);
  llvm::errs() << '\n';
}

void Pattern::dump() const {
  dump(llvm::errs());
}

void Pattern::dump(raw_ostream &OS, unsigned Indent) const {
  PrintPattern(OS, Indent).visit(const_cast<Pattern*>(this), "");
  OS << '\n';
}

//===----------------------------------------------------------------------===//
// Printing for Stmt and all subclasses.
//===----------------------------------------------------------------------===//

namespace {
/// PrintStmt - Visitor implementation of Stmt::dump.
class PrintStmt : public StmtVisitor<PrintStmt, void, StringRef>,
                  public PrintBase {
public:
  using PrintBase::PrintBase;
  const ASTContext *Ctx;

  PrintStmt(raw_ostream &os, const ASTContext *ctx, unsigned indent = 0,
            llvm::function_ref<Type(Expr *)> getTypeOfExpr = defaultGetTypeOfExpr,
            llvm::function_ref<Type(TypeRepr *)> getTypeOfTypeRepr = nullptr,
            llvm::function_ref<Type(KeyPathExpr *E, unsigned index)>
                getTypeOfKeyPathComponent = defaultGetTypeOfKeyPathComponent)
    : PrintBase(os, indent, getTypeOfExpr, getTypeOfTypeRepr,
                getTypeOfKeyPathComponent), Ctx(ctx) { }

  using PrintBase::printRec;

  void printRec(Stmt *S, StringRef Label = "") {
    PrintBase::printRec(S, Ctx, Label);
  }

  void printRec(StmtConditionElement C, StringRef Label = "") {
    switch (C.getKind()) {
    case StmtConditionElement::CK_Boolean:
      return printRec(C.getBoolean());
    case StmtConditionElement::CK_PatternBinding:
      Indent += 2;
      printHead("pattern", PatternColor, Label);
      printRec(C.getPattern());
      printRec(C.getInitializer());
      printFoot();
      Indent -= 2;
      break;
    case StmtConditionElement::CK_Availability:
      Indent += 2;
      printHead("#available", PatternColor, Label);
      for (auto *Query : C.getAvailability()->getQueries()) {
        OS << '\n';
        switch (Query->getKind()) {
        case AvailabilitySpecKind::PlatformVersionConstraint:
          cast<PlatformVersionConstraintAvailabilitySpec>(Query)->print(OS, Indent + 2);
          break;
        case AvailabilitySpecKind::LanguageVersionConstraint:
        case AvailabilitySpecKind::PackageDescriptionVersionConstraint:
          cast<PlatformVersionConstraintAvailabilitySpec>(Query)->print(OS, Indent + 2);
          break;
        case AvailabilitySpecKind::OtherPlatform:
          cast<OtherPlatformAvailabilitySpec>(Query)->print(OS, Indent + 2);
          break;
        }
      }
      printFoot();
      Indent -= 2;
      break;
    case StmtConditionElement::CK_HasSymbol:
      Indent += 2;
      printHead("#_hasSymbol", PatternColor, Label);
      if (Ctx)
        printSourceRange(OS, C.getSourceRange(), *Ctx);
      printRec(C.getHasSymbolInfo()->getSymbolExpr());
      printFoot();
      Indent -= 2;
      break;
    }
  }

  raw_ostream &printCommon(Stmt *S, const char *Name, StringRef Label) {
    printHead(Name, StmtColor, Label);

    if (S->isImplicit())
      OS << " implicit";

    if (Ctx)
      printSourceRange(OS, S->getSourceRange(), *Ctx);

    if (S->TrailingSemiLoc.isValid())
      OS << " trailing_semi";

    return OS;
  }

  void visitBraceStmt(BraceStmt *S, StringRef label) {
    printCommon(S, "brace_stmt", label);
    printASTNodes(S->getElements());
    printFoot();
  }

  void printASTNodes(const ArrayRef<ASTNode> &Elements) {
    for (auto Elt : Elements) {
      if (auto *SubExpr = Elt.dyn_cast<Expr*>())
        printRec(SubExpr);
      else if (auto *SubStmt = Elt.dyn_cast<Stmt*>())
        printRec(SubStmt);
      else
        printRec(Elt.get<Decl*>());
    }
  }

  void visitReturnStmt(ReturnStmt *S, StringRef label) {
    printCommon(S, "return_stmt", label);
    if (S->hasResult()) {
      printRec(S->getResult());
    }
    printFoot();
  }

  void visitYieldStmt(YieldStmt *S, StringRef label) {
    printCommon(S, "yield_stmt", label);
    for (auto yield : S->getYields()) {
      printRec(yield);
    }
    printFoot();
  }

  void visitThenStmt(ThenStmt *S, StringRef label) {
    printCommon(S, "then_stmt", label);
    printRec(S->getResult());
    printFoot();
  }

  void visitDeferStmt(DeferStmt *S, StringRef label) {
    printCommon(S, "defer_stmt", label);
    printRec(S->getTempDecl());
    printRec(S->getCallExpr());
    printFoot();
  }

  void visitIfStmt(IfStmt *S, StringRef label) {
    printCommon(S, "if_stmt", label);
    for (auto elt : S->getCond()) {
      printRec(elt);
    }
    printRec(S->getThenStmt());
    if (S->getElseStmt()) {
      printRec(S->getElseStmt());
    }
    printFoot();
  }

  void visitGuardStmt(GuardStmt *S, StringRef label) {
    printCommon(S, "guard_stmt", label);
    for (auto elt : S->getCond())
      printRec(elt);
    printRec(S->getBody());
    printFoot();
  }

  void visitDoStmt(DoStmt *S, StringRef label) {
    printCommon(S, "do_stmt", label);
    printRec(S->getBody());
    printFoot();
  }

  void visitWhileStmt(WhileStmt *S, StringRef label) {
    printCommon(S, "while_stmt", label);
    for (auto elt : S->getCond())
      printRec(elt);
    OS << '\n';
    printRec(S->getBody());
    printFoot();
  }

  void visitRepeatWhileStmt(RepeatWhileStmt *S, StringRef label) {
    printCommon(S, "repeat_while_stmt", label);
    printRec(S->getBody());
    printRec(S->getCond());
    printFoot();
  }
  void visitForEachStmt(ForEachStmt *S, StringRef label) {
    printCommon(S, "for_each_stmt", label);
    printRec(S->getPattern());
    if (S->getWhere()) {
      OS << '\n';
      Indent += 2;
      printHead("where", ASTNodeColor);
      printRec(S->getWhere());
      printFoot();
      Indent -= 2;
    }
    printRec(S->getParsedSequence());
    if (S->getIteratorVar()) {
      printRec(S->getIteratorVar());
    }
    if (S->getNextCall()) {
      printRec(S->getNextCall());
    }
    if (S->getConvertElementExpr()) {
      printRec(S->getConvertElementExpr());
    }
    if (S->getElementExpr()) {
      printRec(S->getElementExpr());
    }
    printRec(S->getBody());
    printFoot();
  }
  void visitBreakStmt(BreakStmt *S, StringRef label) {
    printCommon(S, "break_stmt", label);
    printFoot();
  }
  void visitContinueStmt(ContinueStmt *S, StringRef label) {
    printCommon(S, "continue_stmt", label);
    printFoot();
  }
  void visitFallthroughStmt(FallthroughStmt *S, StringRef label) {
    printCommon(S, "fallthrough_stmt", label);
    printFoot();
  }
  void visitSwitchStmt(SwitchStmt *S, StringRef label) {
    printCommon(S, "switch_stmt", label);
    printRec(S->getSubjectExpr());
    for (auto N : S->getRawCases()) {
      if (N.is<Stmt*>())
        printRec(N.get<Stmt*>());
      else
        printRec(N.get<Decl*>());
    }
    printFoot();
  }
  void visitCaseStmt(CaseStmt *S, StringRef label) {
    printCommon(S, "case_stmt", label);
    if (S->hasUnknownAttr())
      OS << " @unknown";

    Indent += 2;
    if (S->hasCaseBodyVariables()) {
      OS << '\n';
      printHead("case_body_variables", StmtColor);
      for (auto *vd : S->getCaseBodyVariables()) {
        printRec(vd);
      }
      printFoot();
    }

    for (const auto &LabelItem : S->getCaseLabelItems()) {
      OS << '\n';
      printHead("case_label_item", StmtColor);
      if (LabelItem.isDefault())
        OS << " default";
      if (auto *CasePattern = LabelItem.getPattern()) {
        printRec(CasePattern);
      }
      if (auto *Guard = LabelItem.getGuardExpr()) {
        printRec(const_cast<Expr *>(Guard));
      }
      printFoot();
    }
    Indent -= 2;

    printRec(S->getBody());
    printFoot();
  }
  void visitFailStmt(FailStmt *S, StringRef label) {
    printCommon(S, "fail_stmt", label);
    printFoot();
  }

  void visitThrowStmt(ThrowStmt *S, StringRef label) {
    printCommon(S, "throw_stmt", label);
    printRec(S->getSubExpr());
    printFoot();
  }

  void visitDiscardStmt(DiscardStmt *S, StringRef label) {
    printCommon(S, "discard_stmt", label);
    printRec(S->getSubExpr());
    printFoot();
  }

  void visitPoundAssertStmt(PoundAssertStmt *S, StringRef label) {
    printCommon(S, "pound_assert", label);
    OS << " message=" << QuotedString(S->getMessage());
    printRec(S->getCondition());
    printFoot();
  }

  void visitDoCatchStmt(DoCatchStmt *S, StringRef label) {
    printCommon(S, "do_catch_stmt", label);
    printRec(S->getBody());
    OS << '\n';
    Indent += 2;
    visitCatches(S->getCatches());
    Indent -= 2;
    printFoot();
  }
  void visitCatches(ArrayRef<CaseStmt *> clauses) {
    for (auto clause : clauses) {
      OS << '\n';
      visitCaseStmt(clause, "");
    }
  }
};

} // end anonymous namespace

void Stmt::dump() const {
  dump(llvm::errs());
  llvm::errs() << '\n';
}

void Stmt::dump(raw_ostream &OS, const ASTContext *Ctx, unsigned Indent) const {
  PrintStmt(OS, Ctx, Indent).visit(const_cast<Stmt*>(this), "");
}

//===----------------------------------------------------------------------===//
// Printing for Expr and all subclasses.
//===----------------------------------------------------------------------===//

namespace {
/// PrintExpr - Visitor implementation of Expr::dump.
class PrintExpr : public ExprVisitor<PrintExpr, void, StringRef>,
                  public PrintBase {
public:
  using PrintBase::PrintBase;

  /// FIXME: This should use ExprWalker to print children.

  using PrintBase::printRec;

  void printRec(ProtocolConformanceRef conf) {
    OS << '\n';
    conf.dump(OS, Indent + 2);
  }

  void printDeclRef(ConcreteDeclRef declRef) {
    declRef.dump(PrintWithColorRAII(OS, DeclColor).getOS());
  }

  raw_ostream &printCommon(Expr *E, const char *C, StringRef label) {
    PrintOptions PO;
    PO.PrintTypesForDebugging = true;

    printHead(C, ExprColor, label);

    if (E->isImplicit())
      PrintWithColorRAII(OS, ExprModifierColor) << " implicit";
    PrintWithColorRAII(OS, TypeColor) << " type='";
    PrintWithColorRAII(OS, TypeColor) << GetTypeOfExpr(E).getString(PO) << '\'';

    // If we have a source range and an ASTContext, print the source range.
    if (auto Ty = GetTypeOfExpr(E)) {
      auto &Ctx = Ty->getASTContext();
      auto L = E->getLoc();
      if (L.isValid()) {
        PrintWithColorRAII(OS, LocationColor) << " location=";
        L.print(PrintWithColorRAII(OS, LocationColor).getOS(), Ctx.SourceMgr);
      }

      printSourceRange(OS, E->getSourceRange(), Ctx);
    }

    if (E->TrailingSemiLoc.isValid())
      OS << " trailing_semi";

    return OS;
  }
  
  void printSemanticExpr(Expr * semanticExpr) {
    if (semanticExpr == nullptr) {
      return;
    }
    
    printRecLabeled(semanticExpr, "semantic_expr");
  }

  void visitErrorExpr(ErrorExpr *E, StringRef label) {
    printCommon(E, "error_expr", label);
    printFoot();
  }

  void visitCodeCompletionExpr(CodeCompletionExpr *E, StringRef label) {
    printCommon(E, "code_completion_expr", label);
    if (E->getBase()) {
      printRec(E->getBase());
    }
    printFoot();
  }

  void visitNilLiteralExpr(NilLiteralExpr *E, StringRef label) {
    printCommon(E, "nil_literal_expr", label);
    PrintWithColorRAII(OS, LiteralValueColor) << " initializer=";
    E->getInitializer().dump(PrintWithColorRAII(OS, LiteralValueColor).getOS());
    printFoot();
  }

  void visitIntegerLiteralExpr(IntegerLiteralExpr *E, StringRef label) {
    printCommon(E, "integer_literal_expr", label);
    if (E->isNegative())
      PrintWithColorRAII(OS, LiteralValueColor) << " negative";
    PrintWithColorRAII(OS, LiteralValueColor) << " value=";
    Type T = GetTypeOfExpr(E);
    if (T.isNull() || !T->is<BuiltinIntegerType>())
      PrintWithColorRAII(OS, LiteralValueColor) << E->getDigitsText();
    else
      PrintWithColorRAII(OS, LiteralValueColor) << E->getValue();
    PrintWithColorRAII(OS, LiteralValueColor) << " builtin_initializer=";
    E->getBuiltinInitializer().dump(
        PrintWithColorRAII(OS, LiteralValueColor).getOS());
    PrintWithColorRAII(OS, LiteralValueColor) << " initializer=";
    E->getInitializer().dump(PrintWithColorRAII(OS, LiteralValueColor).getOS());
    printFoot();
  }
  void visitFloatLiteralExpr(FloatLiteralExpr *E, StringRef label) {
    printCommon(E, "float_literal_expr", label);
    if (E->isNegative())
      PrintWithColorRAII(OS, LiteralValueColor) << " negative";
    PrintWithColorRAII(OS, LiteralValueColor)
      << " value=" << E->getDigitsText();
    PrintWithColorRAII(OS, LiteralValueColor) << " builtin_initializer=";
    E->getBuiltinInitializer().dump(
        PrintWithColorRAII(OS, LiteralValueColor).getOS());
    PrintWithColorRAII(OS, LiteralValueColor) << " initializer=";
    E->getInitializer().dump(PrintWithColorRAII(OS, LiteralValueColor).getOS());
    if (!E->getBuiltinType().isNull()) {
      PrintWithColorRAII(OS, TypeColor) << " builtin_type='";
      E->getBuiltinType().print(PrintWithColorRAII(OS, TypeColor).getOS());
      PrintWithColorRAII(OS, TypeColor) << "'";
    }
    printFoot();
  }

  void visitBooleanLiteralExpr(BooleanLiteralExpr *E, StringRef label) {
    printCommon(E, "boolean_literal_expr", label);
    PrintWithColorRAII(OS, LiteralValueColor)
      << " value=" << getDumpString(E->getValue())
      << " builtin_initializer=";
    E->getBuiltinInitializer().dump(
      PrintWithColorRAII(OS, LiteralValueColor).getOS());
    PrintWithColorRAII(OS, LiteralValueColor) << " initializer=";
    E->getInitializer().dump(PrintWithColorRAII(OS, LiteralValueColor).getOS());
    printFoot();
  }

  void visitStringLiteralExpr(StringLiteralExpr *E, StringRef label) {
    printCommon(E, "string_literal_expr", label);
    PrintWithColorRAII(OS, LiteralValueColor) << " encoding="
      << getDumpString(E->getEncoding())
      << " value=" << QuotedString(E->getValue())
      << " builtin_initializer=";
    E->getBuiltinInitializer().dump(
      PrintWithColorRAII(OS, LiteralValueColor).getOS());
    PrintWithColorRAII(OS, LiteralValueColor) << " initializer=";
    E->getInitializer().dump(PrintWithColorRAII(OS, LiteralValueColor).getOS());
    printFoot();
  }
  void visitInterpolatedStringLiteralExpr(InterpolatedStringLiteralExpr *E, StringRef label) {
    printCommon(E, "interpolated_string_literal_expr", label);

    // Print the trailing quote location
    if (auto Ty = GetTypeOfExpr(E)) {
      auto &Ctx = Ty->getASTContext();
      auto TQL = E->getTrailingQuoteLoc();
      if (TQL.isValid()) {
        PrintWithColorRAII(OS, LocationColor) << " trailing_quote_loc=";
        TQL.print(PrintWithColorRAII(OS, LocationColor).getOS(),
                  Ctx.SourceMgr);
      }
    }
    PrintWithColorRAII(OS, LiteralValueColor)
      << " literal_capacity="
      << E->getLiteralCapacity() << " interpolation_count="
      << E->getInterpolationCount();
    PrintWithColorRAII(OS, LiteralValueColor) << " builder_init=";
    E->getBuilderInit().dump(PrintWithColorRAII(OS, LiteralValueColor).getOS());
    PrintWithColorRAII(OS, LiteralValueColor) << " result_init=";
    E->getInitializer().dump(PrintWithColorRAII(OS, LiteralValueColor).getOS());
    printRec(E->getAppendingExpr());
    printFoot();
  }
  void visitMagicIdentifierLiteralExpr(MagicIdentifierLiteralExpr *E, StringRef label) {
    printCommon(E, "magic_identifier_literal_expr", label)
      << " kind=" << getDumpString(E->getKind());

    if (E->isString()) {
      OS << " encoding=" << getDumpString(E->getStringEncoding());
    }
    OS << " builtin_initializer=";
    E->getBuiltinInitializer().dump(OS);
    OS << " initializer=";
    E->getInitializer().dump(OS);
    printFoot();
  }
  void visitRegexLiteralExpr(RegexLiteralExpr *E, StringRef label) {
    printCommon(E, "regex_literal_expr", label);
    PrintWithColorRAII(OS, LiteralValueColor)
        << " text=" << QuotedString(E->getRegexText())
        << " initializer=";
    E->getInitializer().dump(PrintWithColorRAII(OS, LiteralValueColor).getOS());
    printFoot();
  }

  void visitObjectLiteralExpr(ObjectLiteralExpr *E, StringRef label) {
    printCommon(E, "object_literal", label)
      << " kind='" << getDumpString(E->getLiteralKind()) << "'";
    PrintWithColorRAII(OS, LiteralValueColor) << " initializer=";
    E->getInitializer().dump(PrintWithColorRAII(OS, LiteralValueColor).getOS());
    OS << "\n";
    printArgumentList(E->getArgs());
    printFoot();
  }

  void visitDiscardAssignmentExpr(DiscardAssignmentExpr *E, StringRef label) {
    printCommon(E, "discard_assignment_expr", label);
    printFoot();
  }

  void visitDeclRefExpr(DeclRefExpr *E, StringRef label) {
    printCommon(E, "declref_expr", label);
    PrintWithColorRAII(OS, DeclColor) << " decl=";
    printDeclRef(E->getDeclRef());
    if (E->getAccessSemantics() != AccessSemantics::Ordinary)
      PrintWithColorRAII(OS, AccessLevelColor)
        << " " << getDumpString(E->getAccessSemantics());
    PrintWithColorRAII(OS, ExprModifierColor)
      << " function_ref=" << getDumpString(E->getFunctionRefKind());
    printFoot();
  }
  void visitSuperRefExpr(SuperRefExpr *E, StringRef label) {
    printCommon(E, "super_ref_expr", label);
    printFoot();
  }

  void visitTypeExpr(TypeExpr *E, StringRef label) {
    printCommon(E, "type_expr", label);
    PrintWithColorRAII(OS, TypeReprColor) << " typerepr='";
    if (E->getTypeRepr())
      E->getTypeRepr()->print(PrintWithColorRAII(OS, TypeReprColor).getOS());
    else
      PrintWithColorRAII(OS, TypeReprColor) << "<<NULL>>";
    PrintWithColorRAII(OS, TypeReprColor) << "'";
    printFoot();
  }

  void visitOtherConstructorDeclRefExpr(OtherConstructorDeclRefExpr *E, StringRef label) {
    printCommon(E, "other_constructor_ref_expr", label);
    PrintWithColorRAII(OS, DeclColor) << " decl=";
    printDeclRef(E->getDeclRef());
    printFoot();
  }
  void visitOverloadedDeclRefExpr(OverloadedDeclRefExpr *E, StringRef label) {
    printCommon(E, "overloaded_decl_ref_expr", label);
    PrintWithColorRAII(OS, IdentifierColor) << " name="
      << E->getDecls()[0]->getBaseName();
    PrintWithColorRAII(OS, ExprModifierColor)
      << " number_of_decls=" << E->getDecls().size()
      << " function_ref=" << getDumpString(E->getFunctionRefKind());
    if (!E->isForOperator()) {
      PrintWithColorRAII(OS, ExprModifierColor) << " decls=[\n";
      interleave(
          E->getDecls(),
          [&](ValueDecl *D) {
            OS.indent(Indent + 2);
            D->dumpRef(PrintWithColorRAII(OS, DeclModifierColor).getOS());
          },
          [&] { PrintWithColorRAII(OS, DeclModifierColor) << ",\n"; });
      PrintWithColorRAII(OS, ExprModifierColor) << "]";
    }
    printFoot();
  }
  void visitUnresolvedDeclRefExpr(UnresolvedDeclRefExpr *E, StringRef label) {
    printCommon(E, "unresolved_decl_ref_expr", label);
    PrintWithColorRAII(OS, IdentifierColor) << " name=" << E->getName();
    PrintWithColorRAII(OS, ExprModifierColor)
      << " function_ref=" << getDumpString(E->getFunctionRefKind());
    printFoot();
  }
  void visitUnresolvedSpecializeExpr(UnresolvedSpecializeExpr *E, StringRef label) {
    printCommon(E, "unresolved_specialize_expr", label);
    printRec(E->getSubExpr());
    for (TypeLoc T : E->getUnresolvedParams()) {
      printRec(T.getTypeRepr());
    }
    printFoot();
  }

  void visitMemberRefExpr(MemberRefExpr *E, StringRef label) {
    printCommon(E, "member_ref_expr", label);
    PrintWithColorRAII(OS, DeclColor) << " decl=";
    printDeclRef(E->getMember());
    if (E->getAccessSemantics() != AccessSemantics::Ordinary)
      PrintWithColorRAII(OS, AccessLevelColor)
        << " " << getDumpString(E->getAccessSemantics());
    if (E->isSuper())
      OS << " super";

    printRec(E->getBase());
    printFoot();
  }
  void visitDynamicMemberRefExpr(DynamicMemberRefExpr *E, StringRef label) {
    printCommon(E, "dynamic_member_ref_expr", label);
    PrintWithColorRAII(OS, DeclColor) << " decl=";
    E->getMember().dump(OS);
    printRec(E->getBase());
    printFoot();
  }
  void visitUnresolvedMemberExpr(UnresolvedMemberExpr *E, StringRef label) {
    printCommon(E, "unresolved_member_expr", label)
      << " name='" << E->getName() << "'";
    PrintWithColorRAII(OS, ExprModifierColor)
      << " function_ref=" << getDumpString(E->getFunctionRefKind());
    printFoot();
  }
  void visitDotSelfExpr(DotSelfExpr *E, StringRef label) {
    printCommon(E, "dot_self_expr", label);
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitParenExpr(ParenExpr *E, StringRef label) {
    printCommon(E, "paren_expr", label);
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitAwaitExpr(AwaitExpr *E, StringRef label) {
    printCommon(E, "await_expr", label);
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitConsumeExpr(ConsumeExpr *E, StringRef label) {
    printCommon(E, "consume_expr", label);
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitCopyExpr(CopyExpr *E, StringRef label) {
    printCommon(E, "copy_expr", label);
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitBorrowExpr(BorrowExpr *E, StringRef label) {
    printCommon(E, "borrow_expr", label);
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitUnresolvedMemberChainResultExpr(UnresolvedMemberChainResultExpr *E, StringRef label){
    printCommon(E, "unresolved_member_chain_expr", label);
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitTupleExpr(TupleExpr *E, StringRef label) {
    printCommon(E, "tuple_expr", label);

    if (E->hasElementNames()) {
      PrintWithColorRAII(OS, IdentifierColor) << " names=";

      interleave(E->getElementNames(),
                 [&](Identifier name) {
                   PrintWithColorRAII(OS, IdentifierColor)
                     << (name.empty()?"''":name.str());
                 },
                 [&] { PrintWithColorRAII(OS, IdentifierColor) << ","; });
    }

    for (unsigned i = 0, e = E->getNumElements(); i != e; ++i) {
      if (E->getElement(i))
        printRec(E->getElement(i));
      else {
        OS << '\n';
        printHead("<tuple element default value>", ExprColor);
        printFoot();
      }
    }
    printFoot();
  }
  void visitArrayExpr(ArrayExpr *E, StringRef label) {
    printCommon(E, "array_expr", label);
    PrintWithColorRAII(OS, LiteralValueColor) << " initializer=";
    E->getInitializer().dump(PrintWithColorRAII(OS, LiteralValueColor).getOS());
    for (auto elt : E->getElements()) {
      printRec(elt);
    }
    printFoot();
  }
  void visitDictionaryExpr(DictionaryExpr *E, StringRef label) {
    printCommon(E, "dictionary_expr", label);
    PrintWithColorRAII(OS, LiteralValueColor) << " initializer=";
    E->getInitializer().dump(PrintWithColorRAII(OS, LiteralValueColor).getOS());
    for (auto elt : E->getElements()) {
      printRec(elt);
    }
    printFoot();
  }
  void visitSubscriptExpr(SubscriptExpr *E, StringRef label) {
    printCommon(E, "subscript_expr", label);
    if (E->getAccessSemantics() != AccessSemantics::Ordinary)
      PrintWithColorRAII(OS, AccessLevelColor)
        << " " << getDumpString(E->getAccessSemantics());
    if (E->isSuper())
      OS << " super";
    if (E->hasDecl()) {
      PrintWithColorRAII(OS, DeclColor) << " decl=";
      printDeclRef(E->getDecl());
    }
    printRec(E->getBase());
    OS << '\n';
    printArgumentList(E->getArgs());
    printFoot();
  }
  void visitKeyPathApplicationExpr(KeyPathApplicationExpr *E, StringRef label) {
    printCommon(E, "keypath_application_expr", label);
    printRec(E->getBase());
    printRec(E->getKeyPath());
    printFoot();
  }
  void visitDynamicSubscriptExpr(DynamicSubscriptExpr *E, StringRef label) {
    printCommon(E, "dynamic_subscript_expr", label);
    PrintWithColorRAII(OS, DeclColor) << " decl=";
    printDeclRef(E->getMember());
    printRec(E->getBase());
    OS << '\n';
    printArgumentList(E->getArgs());
    printFoot();
  }
  void visitUnresolvedDotExpr(UnresolvedDotExpr *E, StringRef label) {
    printCommon(E, "unresolved_dot_expr", label)
      << " field '" << E->getName() << "'";
    PrintWithColorRAII(OS, ExprModifierColor)
      << " function_ref=" << getDumpString(E->getFunctionRefKind());
    if (E->getBase()) {
      printRec(E->getBase());
    }
    printFoot();
  }
  void visitTupleElementExpr(TupleElementExpr *E, StringRef label) {
    printCommon(E, "tuple_element_expr", label) << " field #" << E->getFieldNumber();
    printRec(E->getBase());
    printFoot();
  }
  void visitDestructureTupleExpr(DestructureTupleExpr *E, StringRef label) {
    printCommon(E, "destructure_tuple_expr", label);

    OS << "\n";
    Indent += 2;
    printHead("destructured", ASTNodeColor);
    for (auto *elt : E->getDestructuredElements()) {
      printRec(elt);
    }
    printFoot();
    Indent -= 2;

    printRec(E->getSubExpr());
    printRec(E->getResultExpr());
    printFoot();
  }
  void visitUnresolvedTypeConversionExpr(UnresolvedTypeConversionExpr *E, StringRef label) {
    printCommon(E, "unresolvedtype_conversion_expr", label);
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitFunctionConversionExpr(FunctionConversionExpr *E, StringRef label) {
    printCommon(E, "function_conversion_expr", label);
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitCovariantFunctionConversionExpr(CovariantFunctionConversionExpr *E, StringRef label){
    printCommon(E, "covariant_function_conversion_expr", label);
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitCovariantReturnConversionExpr(CovariantReturnConversionExpr *E, StringRef label){
    printCommon(E, "covariant_return_conversion_expr", label);
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitUnderlyingToOpaqueExpr(UnderlyingToOpaqueExpr *E, StringRef label){
    printCommon(E, "underlying_to_opaque_expr", label);
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitErasureExpr(ErasureExpr *E, StringRef label) {
    printCommon(E, "erasure_expr", label);
    for (auto conf : E->getConformances()) {
      printRec(conf);
    }
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitAnyHashableErasureExpr(AnyHashableErasureExpr *E, StringRef label) {
    printCommon(E, "any_hashable_erasure_expr", label);
    printRec(E->getConformance());
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitConditionalBridgeFromObjCExpr(ConditionalBridgeFromObjCExpr *E, StringRef label) {
    printCommon(E, "conditional_bridge_from_objc_expr", label) << " conversion=";
    printDeclRef(E->getConversion());
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitBridgeFromObjCExpr(BridgeFromObjCExpr *E, StringRef label) {
    printCommon(E, "bridge_from_objc_expr", label);
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitBridgeToObjCExpr(BridgeToObjCExpr *E, StringRef label) {
    printCommon(E, "bridge_to_objc_expr", label);
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitLoadExpr(LoadExpr *E, StringRef label) {
    printCommon(E, "load_expr", label);
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitABISafeConversionExpr(ABISafeConversionExpr *E, StringRef label) {
    printCommon(E, "abi_safe_conversion_expr", label);
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitMetatypeConversionExpr(MetatypeConversionExpr *E, StringRef label) {
    printCommon(E, "metatype_conversion_expr", label);
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitCollectionUpcastConversionExpr(CollectionUpcastConversionExpr *E, StringRef label) {
    printCommon(E, "collection_upcast_expr", label);
    printRec(E->getSubExpr());
    if (auto keyConversion = E->getKeyConversion()) {
      printRecLabeled(keyConversion.Conversion, "key_conversion");
    }
    if (auto valueConversion = E->getValueConversion()) {
      printRecLabeled(valueConversion.Conversion, "value_conversion");
    }
    printFoot();
  }
  void visitDerivedToBaseExpr(DerivedToBaseExpr *E, StringRef label) {
    printCommon(E, "derived_to_base_expr", label);
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitArchetypeToSuperExpr(ArchetypeToSuperExpr *E, StringRef label) {
    printCommon(E, "archetype_to_super_expr", label);
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitInjectIntoOptionalExpr(InjectIntoOptionalExpr *E, StringRef label) {
    printCommon(E, "inject_into_optional", label);
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitClassMetatypeToObjectExpr(ClassMetatypeToObjectExpr *E, StringRef label) {
    printCommon(E, "class_metatype_to_object", label);
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitExistentialMetatypeToObjectExpr(ExistentialMetatypeToObjectExpr *E, StringRef label) {
    printCommon(E, "existential_metatype_to_object", label);
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitProtocolMetatypeToObjectExpr(ProtocolMetatypeToObjectExpr *E, StringRef label) {
    printCommon(E, "protocol_metatype_to_object", label);
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitInOutToPointerExpr(InOutToPointerExpr *E, StringRef label) {
    printCommon(E, "inout_to_pointer", label)
      << (E->isNonAccessing() ? " nonaccessing" : "");
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitArrayToPointerExpr(ArrayToPointerExpr *E, StringRef label) {
    printCommon(E, "array_to_pointer", label)
      << (E->isNonAccessing() ? " nonaccessing" : "");
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitStringToPointerExpr(StringToPointerExpr *E, StringRef label) {
    printCommon(E, "string_to_pointer", label);
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitPointerToPointerExpr(PointerToPointerExpr *E, StringRef label) {
    printCommon(E, "pointer_to_pointer", label);
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitForeignObjectConversionExpr(ForeignObjectConversionExpr *E, StringRef label) {
    printCommon(E, "foreign_object_conversion", label);
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitUnevaluatedInstanceExpr(UnevaluatedInstanceExpr *E, StringRef label) {
    printCommon(E, "unevaluated_instance", label);
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitDifferentiableFunctionExpr(DifferentiableFunctionExpr *E, StringRef label) {
    printCommon(E, "differentiable_function", label);
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitLinearFunctionExpr(LinearFunctionExpr *E, StringRef label) {
    printCommon(E, "linear_function", label);
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitDifferentiableFunctionExtractOriginalExpr(
      DifferentiableFunctionExtractOriginalExpr *E, StringRef label) {
    printCommon(E, "differentiable_function_extract_original", label);
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitLinearFunctionExtractOriginalExpr(
      LinearFunctionExtractOriginalExpr *E, StringRef label) {
    printCommon(E, "linear_function_extract_original", label);
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitLinearToDifferentiableFunctionExpr(
      LinearToDifferentiableFunctionExpr *E, StringRef label) {
    printCommon(E, "linear_to_differentiable_function", label);
    printRec(E->getSubExpr());
    printFoot();
  }

  void visitInOutExpr(InOutExpr *E, StringRef label) {
    printCommon(E, "inout_expr", label);
    printRec(E->getSubExpr());
    printFoot();
  }

  void visitVarargExpansionExpr(VarargExpansionExpr *E, StringRef label) {
    printCommon(E, "vararg_expansion_expr", label);
    printRec(E->getSubExpr());
    printFoot();
  }

  void visitPackExpansionExpr(PackExpansionExpr *E, StringRef label) {
    printCommon(E, "pack_expansion_expr", label);
    printRec(E->getPatternExpr());
    printFoot();
  }

  void visitPackElementExpr(PackElementExpr *E, StringRef label) {
    printCommon(E, "pack_element_expr", label);
    printRec(E->getPackRefExpr());
    printFoot();
  }

  void visitMaterializePackExpr(MaterializePackExpr *E, StringRef label) {
    printCommon(E, "materialize_pack_expr", label);
    printRec(E->getFromExpr());
    printFoot();
  }

  void visitForceTryExpr(ForceTryExpr *E, StringRef label) {
    printCommon(E, "force_try_expr", label);
    printRec(E->getSubExpr());
    printFoot();
  }

  void visitOptionalTryExpr(OptionalTryExpr *E, StringRef label) {
    printCommon(E, "optional_try_expr", label);
    printRec(E->getSubExpr());
    printFoot();
  }

  void visitTryExpr(TryExpr *E, StringRef label) {
    printCommon(E, "try_expr", label);
    printRec(E->getSubExpr());
    printFoot();
  }

  void visitSequenceExpr(SequenceExpr *E, StringRef label) {
    printCommon(E, "sequence_expr", label);
    for (unsigned i = 0, e = E->getNumElements(); i != e; ++i) {
      printRec(E->getElement(i));
    }
    printFoot();
  }

  void visitCaptureListExpr(CaptureListExpr *E, StringRef label) {
    printCommon(E, "capture_list", label);
    for (auto capture : E->getCaptureList()) {
      printRec(capture.PBD);
    }
    printRec(E->getClosureBody());
    printFoot();
  }

  llvm::raw_ostream &printClosure(AbstractClosureExpr *E, char const *name,
                                  StringRef label) {
    printCommon(E, name, label);

    // If we aren't printing to standard error or the debugger output stream,
    // this client expects to see the computed discriminator. Compute it now.
    if (&OS != &llvm::errs() && &OS != &llvm::dbgs())
      (void)E->getDiscriminator();

    PrintWithColorRAII(OS, DiscriminatorColor)
      << " discriminator=" << E->getRawDiscriminator();

    switch (auto isolation = E->getActorIsolation()) {
    case ClosureActorIsolation::Independent:
      break;

    case ClosureActorIsolation::ActorInstance:
      PrintWithColorRAII(OS, CapturesColor) << " actor-isolated="
        << isolation.getActorInstance()->printRef();
      break;

    case ClosureActorIsolation::GlobalActor:
      PrintWithColorRAII(OS, CapturesColor) << " global-actor-isolated="
        << isolation.getGlobalActor().getString();
      break;
    }

    if (!E->getCaptureInfo().isTrivial()) {
      OS << " ";
      E->getCaptureInfo().print(PrintWithColorRAII(OS, CapturesColor).getOS());
    }
    // Printing a function type doesn't indicate whether it's escaping because it doesn't 
    // matter in 99% of contexts. AbstractClosureExpr nodes are one of the only exceptions.
    if (auto Ty = GetTypeOfExpr(E)) {
      if (auto fType = Ty->getAs<AnyFunctionType>()) {
        if (!fType->getExtInfo().isNoEscape())
          PrintWithColorRAII(OS, ClosureModifierColor) << " escaping";
        if (fType->getExtInfo().isSendable())
          PrintWithColorRAII(OS, ClosureModifierColor) << " concurrent";
      }
    }

    return OS;
  }

  void visitClosureExpr(ClosureExpr *E, StringRef label) {
    printClosure(E, "closure_expr", label);
    if (E->hasSingleExpressionBody())
      PrintWithColorRAII(OS, ClosureModifierColor) << " single-expression";
    if (E->allowsImplicitSelfCapture())
      PrintWithColorRAII(OS, ClosureModifierColor) << " implicit-self";
    if (E->inheritsActorContext())
      PrintWithColorRAII(OS, ClosureModifierColor) << " inherits-actor-context";

    if (E->getParameters()) {
      OS << '\n';
      PrintDecl(OS, Indent+2).printParameterList(E->getParameters(), &E->getASTContext());
    }

    printRec(E->getBody(), &E->getASTContext());
    printFoot();
  }
  void visitAutoClosureExpr(AutoClosureExpr *E, StringRef label) {
    printClosure(E, "autoclosure_expr", label);

    if (E->getParameters()) {
      OS << '\n';
      PrintDecl(OS, Indent+2).printParameterList(E->getParameters(), &E->getASTContext());
    }

    printRec(E->getSingleExpressionBody());
    printFoot();
  }

  void visitDynamicTypeExpr(DynamicTypeExpr *E, StringRef label) {
    printCommon(E, "metatype_expr", label);
    printRec(E->getBase());
    printFoot();
  }

  void visitOpaqueValueExpr(OpaqueValueExpr *E, StringRef label) {
    printCommon(E, "opaque_value_expr", label) << " @ " << (void*)E;
    printFoot();
  }

  void visitPropertyWrapperValuePlaceholderExpr(
      PropertyWrapperValuePlaceholderExpr *E, StringRef label) {
    printCommon(E, "property_wrapper_value_placeholder_expr", label);
    printRec(E->getOpaqueValuePlaceholder());
    if (auto *value = E->getOriginalWrappedValue()) {
      printRec(value);
    }
    printFoot();
  }

  void visitAppliedPropertyWrapperExpr(AppliedPropertyWrapperExpr *E, StringRef label) {
    printCommon(E, "applied_property_wrapper_expr", label);
    printRec(E->getValue());
    printFoot();
  }

  void visitDefaultArgumentExpr(DefaultArgumentExpr *E, StringRef label) {
    printCommon(E, "default_argument_expr", label);
    OS << " default_args_owner=";
    E->getDefaultArgsOwner().dump(OS);
    OS << " param=" << E->getParamIndex();
    printFoot();
  }

  void printArgumentList(const ArgumentList *argList, bool indent = true) {
    ::printArgumentList(OS, argList, Indent, [&](Expr *E) { printRec(E); },
                        indent);
  }

  void printApplyExpr(ApplyExpr *E, const char *NodeName, StringRef label) {
    printCommon(E, NodeName, label);
    if (E->isThrowsSet()) {
      PrintWithColorRAII(OS, ExprModifierColor)
        << (E->throws() ? " throws" : " nothrow");
    }
    PrintWithColorRAII(OS, ExprModifierColor)
        << " isolationCrossing=";
    auto isolationCrossing = E->getIsolationCrossing();
    if (isolationCrossing.has_value()) {
      PrintWithColorRAII(OS, ExprModifierColor)
          << "{caller='";
      simple_display(PrintWithColorRAII(OS, ExprModifierColor).getOS(),
                     isolationCrossing.value().getCallerIsolation());
      PrintWithColorRAII(OS, ExprModifierColor)
          << "', callee='";
      simple_display(PrintWithColorRAII(OS, ExprModifierColor).getOS(),
                     isolationCrossing.value().getCalleeIsolation());

      PrintWithColorRAII(OS, ExprModifierColor)
          << "'}";
    } else {
      PrintWithColorRAII(OS, ExprModifierColor)
          << "none";
    }
    printRec(E->getFn());
    OS << '\n';
    printArgumentList(E->getArgs());
    printFoot();
  }

  void visitCallExpr(CallExpr *E, StringRef label) {
    printApplyExpr(E, "call_expr", label);
  }
  void visitPrefixUnaryExpr(PrefixUnaryExpr *E, StringRef label) {
    printApplyExpr(E, "prefix_unary_expr", label);
  }
  void visitPostfixUnaryExpr(PostfixUnaryExpr *E, StringRef label) {
    printApplyExpr(E, "postfix_unary_expr", label);
  }
  void visitBinaryExpr(BinaryExpr *E, StringRef label) {
    printApplyExpr(E, "binary_expr", label);
  }
  void visitDotSyntaxCallExpr(DotSyntaxCallExpr *E, StringRef label) {
    printApplyExpr(E, "dot_syntax_call_expr", label);
  }
  void visitConstructorRefCallExpr(ConstructorRefCallExpr *E, StringRef label) {
    printApplyExpr(E, "constructor_ref_call_expr", label);
  }
  void visitDotSyntaxBaseIgnoredExpr(DotSyntaxBaseIgnoredExpr *E, StringRef label) {
    printCommon(E, "dot_syntax_base_ignored", label);
    printRec(E->getLHS());
    printRec(E->getRHS());
    printFoot();
  }

  void printExplicitCastExpr(ExplicitCastExpr *E, const char *name, StringRef label) {
    printCommon(E, name, label);
    if (auto checkedCast = dyn_cast<CheckedCastExpr>(E))
      OS << ' ' << getDumpString(checkedCast->getCastKind());
    OS << " writtenType='";
    if (GetTypeOfTypeRepr)
      GetTypeOfTypeRepr(E->getCastTypeRepr()).print(OS);
    else
      E->getCastType().print(OS);
    OS << "'";
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitForcedCheckedCastExpr(ForcedCheckedCastExpr *E, StringRef label) {
    printExplicitCastExpr(E, "forced_checked_cast_expr", label);
  }
  void visitConditionalCheckedCastExpr(ConditionalCheckedCastExpr *E, StringRef label) {
    printExplicitCastExpr(E, "conditional_checked_cast_expr", label);
  }
  void visitIsExpr(IsExpr *E, StringRef label) {
    printExplicitCastExpr(E, "is_subtype_expr", label);
  }
  void visitCoerceExpr(CoerceExpr *E, StringRef label) {
    printExplicitCastExpr(E, "coerce_expr", label);
  }
  void visitArrowExpr(ArrowExpr *E, StringRef label) {
    printCommon(E, "arrow", label);
    if (E->getAsyncLoc().isValid())
      OS << " async";
    if (E->getThrowsLoc().isValid())
      OS << " throws";
    printRec(E->getArgsExpr());
    printRec(E->getResultExpr());
    printFoot();
  }
  void visitRebindSelfInConstructorExpr(RebindSelfInConstructorExpr *E, StringRef label) {
    printCommon(E, "rebind_self_in_constructor_expr", label);
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitTernaryExpr(TernaryExpr *E, StringRef label) {
    printCommon(E, "ternary_expr", label);
    printRec(E->getCondExpr());
    printRec(E->getThenExpr());
    printRec(E->getElseExpr());
    printFoot();
  }
  void visitAssignExpr(AssignExpr *E, StringRef label) {
    printCommon(E, "assign_expr", label);
    printRec(E->getDest());
    printRec(E->getSrc());
    printFoot();
  }
  void visitEnumIsCaseExpr(EnumIsCaseExpr *E, StringRef label) {
    printCommon(E, "enum_is_case_expr", label) << ' ' <<
      E->getEnumElement()->getBaseIdentifier();
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitUnresolvedPatternExpr(UnresolvedPatternExpr *E, StringRef label) {
    printCommon(E, "unresolved_pattern_expr", label);
    printRec(E->getSubPattern());
    printFoot();
  }
  void visitBindOptionalExpr(BindOptionalExpr *E, StringRef label) {
    printCommon(E, "bind_optional_expr", label) << " depth=" << E->getDepth();
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitOptionalEvaluationExpr(OptionalEvaluationExpr *E, StringRef label) {
    printCommon(E, "optional_evaluation_expr", label);
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitForceValueExpr(ForceValueExpr *E, StringRef label) {
    printCommon(E, "force_value_expr", label);
    if (E->isForceOfImplicitlyUnwrappedOptional())
      PrintWithColorRAII(OS, ExprModifierColor) << " implicit_iuo_unwrap";

    printRec(E->getSubExpr());
    printFoot();
  }
  void visitOpenExistentialExpr(OpenExistentialExpr *E, StringRef label) {
    printCommon(E, "open_existential_expr", label);
    printRec(E->getOpaqueValue());
    printRec(E->getExistentialValue());
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitMakeTemporarilyEscapableExpr(MakeTemporarilyEscapableExpr *E, StringRef label) {
    printCommon(E, "make_temporarily_escapable_expr", label);
    printRec(E->getOpaqueValue());
    printRec(E->getNonescapingClosureValue());
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitEditorPlaceholderExpr(EditorPlaceholderExpr *E, StringRef label) {
    printCommon(E, "editor_placeholder_expr", label) << ' ';

    // Print the trailing angle bracket location
    if (auto Ty = GetTypeOfExpr(E)) {
      auto &Ctx = Ty->getASTContext();
      auto TABL = E->getTrailingAngleBracketLoc();
      if (TABL.isValid()) {
        PrintWithColorRAII(OS, LocationColor) << "trailing_angle_bracket_loc=";
        TABL.print(PrintWithColorRAII(OS, LocationColor).getOS(),
                   Ctx.SourceMgr);
      }
    }
    auto *TyR = E->getPlaceholderTypeRepr();
    auto *ExpTyR = E->getTypeForExpansion();
    if (TyR)
      printRec(TyR);
    if (ExpTyR && ExpTyR != TyR) {
      printRec(ExpTyR);
    }
    printSemanticExpr(E->getSemanticExpr());
    printFoot();
  }
  void visitLazyInitializerExpr(LazyInitializerExpr *E, StringRef label) {
    printCommon(E, "lazy_initializer_expr", label);
    printRec(E->getSubExpr());
    printFoot();
  }
  void visitObjCSelectorExpr(ObjCSelectorExpr *E, StringRef label) {
    printCommon(E, "objc_selector_expr", label);
    OS << " kind=" << getDumpString(E->getSelectorKind());
    PrintWithColorRAII(OS, DeclColor) << " decl=";
    printDeclRef(E->getMethod());
    printRec(E->getSubExpr());
    printFoot();
  }

  void visitKeyPathExpr(KeyPathExpr *E, StringRef label) {
    printCommon(E, "keypath_expr", label);
    if (E->isObjC())
      OS << " objc";

    OS << '\n';
    Indent += 2;
    printHead("components", ExprColor);
    for (unsigned i : indices(E->getComponents())) {
      auto &component = E->getComponents()[i];
      OS << '\n';
      switch (component.getKind()) {
      case KeyPathExpr::Component::Kind::Invalid:
        printHead("invalid", ASTNodeColor);
        break;

      case KeyPathExpr::Component::Kind::OptionalChain:
        printHead("optional_chain", ASTNodeColor);
        break;
        
      case KeyPathExpr::Component::Kind::OptionalForce:
        printHead("optional_force", ASTNodeColor);
        break;
        
      case KeyPathExpr::Component::Kind::OptionalWrap:
        printHead("optional_wrap", ASTNodeColor);
        break;
        
      case KeyPathExpr::Component::Kind::Property:
        printHead("property", ASTNodeColor);
        PrintWithColorRAII(OS, DeclColor) << " decl=";
        printDeclRef(component.getDeclRef());
        break;
      
      case KeyPathExpr::Component::Kind::Subscript:
        printHead("subscript", ASTNodeColor);
        PrintWithColorRAII(OS, DeclColor) << " decl='";
        printDeclRef(component.getDeclRef());
        PrintWithColorRAII(OS, DeclColor) << "'";
        break;
      
      case KeyPathExpr::Component::Kind::UnresolvedProperty:
        printHead("unresolved_property", ASTNodeColor);
        PrintWithColorRAII(OS, IdentifierColor)
          << " decl_name='" << component.getUnresolvedDeclName() << "'";
        break;
        
      case KeyPathExpr::Component::Kind::UnresolvedSubscript:
        printHead("unresolved_subscript", ASTNodeColor);
        break;
      case KeyPathExpr::Component::Kind::Identity:
        printHead("identity", ASTNodeColor);
        break;

      case KeyPathExpr::Component::Kind::TupleElement:
        printHead("tuple_element", ASTNodeColor) << ' ';
        PrintWithColorRAII(OS, DiscriminatorColor)
          << "#" << component.getTupleIndex();
        break;
      case KeyPathExpr::Component::Kind::DictionaryKey:
        printHead("dict_key", ASTNodeColor);
        PrintWithColorRAII(OS, IdentifierColor)
          << " key='" << component.getUnresolvedDeclName() << "'";
        break;
      case KeyPathExpr::Component::Kind::CodeCompletion:
        printHead("completion", ASTNodeColor);
        break;
      }
      PrintWithColorRAII(OS, TypeColor)
        << " type='" << GetTypeOfKeyPathComponent(E, i) << "'";
      if (auto *args = component.getSubscriptArgs()) {
        OS << '\n';
        printArgumentList(args);
      }
      printFoot();
    }

    printFoot();
    Indent -= 2;

    if (auto stringLiteral = E->getObjCStringLiteralExpr()) {
      printRecLabeled(stringLiteral, "objc_string_literal");
    }
    if (!E->isObjC()) {
      if (auto root = E->getParsedRoot()) {
        printRecLabeled(root, "parsed_root");
      }
      if (auto path = E->getParsedPath()) {
        printRecLabeled(path, "parsed_path");
      }
    }
    printFoot();
  }

  void visitKeyPathDotExpr(KeyPathDotExpr *E, StringRef label) {
    printCommon(E, "key_path_dot_expr", label);
    printFoot();
  }

  void visitSingleValueStmtExpr(SingleValueStmtExpr *E, StringRef label) {
    printCommon(E, "single_value_stmt_expr", label);
    printRec(E->getStmt(), &E->getDeclContext()->getASTContext());
    printFoot();
  }

  void visitOneWayExpr(OneWayExpr *E, StringRef label) {
    printCommon(E, "one_way_expr", label);
    printRec(E->getSubExpr());
    printFoot();
  }

  void visitTapExpr(TapExpr *E, StringRef label) {
    printCommon(E, "tap_expr", label);
    PrintWithColorRAII(OS, DeclColor) << " var=";
    printDeclRef(E->getVar());
    printRec(E->getSubExpr());
    printRec(E->getBody(), &E->getVar()->getDeclContext()->getASTContext());
    printFoot();
  }

  void visitTypeJoinExpr(TypeJoinExpr *E, StringRef label) {
    printCommon(E, "type_join_expr", label);

    if (auto *var = E->getVar()) {
      printRecLabeled(var, "var");
    }

    if (auto *SVE = E->getSingleValueStmtExpr()) {
      printRecLabeled(SVE, "single_value_stmt_expr");
    }

    for (auto *member : E->getElements()) {
      printRec(member);
    }

    printFoot();
  }

  void visitMacroExpansionExpr(MacroExpansionExpr *E, StringRef label) {
    printCommon(E, "macro_expansion_expr", label);
    PrintWithColorRAII(OS, IdentifierColor) << " name=" << E->getMacroName();
    PrintWithColorRAII(OS, DiscriminatorColor)
      << " discriminator=" << E->getRawDiscriminator();
    if (E->getArgs()) {
      OS << '\n';
      printArgumentList(E->getArgs());
    }
    if (auto rewritten = E->getRewritten()) {
      printRecLabeled(rewritten, "rewritten");
    }
    printFoot();
  }
};

} // end anonymous namespace

void Expr::dump() const {
  dump(llvm::errs());
  llvm::errs() << "\n";
}

void Expr::dump(raw_ostream &OS, llvm::function_ref<Type(Expr *)> getTypeOfExpr,
                llvm::function_ref<Type(TypeRepr *)> getTypeOfTypeRepr,
                llvm::function_ref<Type(KeyPathExpr *E, unsigned index)>
                    getTypeOfKeyPathComponent,
                unsigned Indent) const {
  PrintExpr(OS, Indent, getTypeOfExpr, getTypeOfTypeRepr,
            getTypeOfKeyPathComponent)
      .visit(const_cast<Expr *>(this), "");
}

void Expr::dump(raw_ostream &OS, unsigned Indent) const {
  dump(OS, defaultGetTypeOfExpr, /*getTypeOfTypeRepr*/ nullptr,
       defaultGetTypeOfKeyPathComponent, Indent);
}

void Expr::print(ASTPrinter &Printer, const PrintOptions &Opts) const {
  // FIXME: Fully use the ASTPrinter.
  llvm::SmallString<128> Str;
  llvm::raw_svector_ostream OS(Str);
  dump(OS);
  Printer << OS.str();
}

void ArgumentList::dump() const {
  dump(llvm::errs(), 0);
}

void ArgumentList::dump(raw_ostream &OS, unsigned Indent) const {
  auto getTypeOfExpr = [](Expr *E) -> Type { return E->getType(); };
  auto getTypeOfKeyPathComponent = [](KeyPathExpr *E, unsigned index) -> Type {
    return E->getComponents()[index].getComponentType();
  };
  PrintExpr printer(OS, Indent, getTypeOfExpr, /*getTypeOfTypeRepr*/ nullptr,
                    getTypeOfKeyPathComponent);
  printer.printArgumentList(this, /*indent*/ false);
  llvm::errs() << '\n';
}

//===----------------------------------------------------------------------===//
// Printing for TypeRepr and all subclasses.
//===----------------------------------------------------------------------===//

namespace {
class PrintTypeRepr : public TypeReprVisitor<PrintTypeRepr, void, StringRef>,
                      public PrintBase {
public:
  using PrintBase::PrintBase;

  raw_ostream &printCommon(const char *Name, StringRef Label) {
    return printHead(Name, TypeReprColor, Label);
  }

  void visitErrorTypeRepr(ErrorTypeRepr *T, StringRef label) {
    printCommon("type_error", label);
  }

  void visitAttributedTypeRepr(AttributedTypeRepr *T, StringRef label) {
    printCommon("type_attributed", label) << " attrs=";
    T->printAttrs(OS);
    printRec(T->getTypeRepr());
  }

  void visitIdentTypeRepr(IdentTypeRepr *T, StringRef label) {
    printCommon("type_ident", label);

    PrintWithColorRAII(OS, IdentifierColor)
        << " id='" << T->getNameRef() << '\'';
    OS << " bind=";
    if (T->isBound())
      T->getBoundDecl()->dumpRef(OS);
    else
      OS << "none";
    printFoot();
    if (auto *GenIdT = dyn_cast<GenericIdentTypeRepr>(T)) {
      for (auto genArg : GenIdT->getGenericArgs()) {
        printRec(genArg);
      }
    }
  }

  void visitMemberTypeRepr(MemberTypeRepr *T, StringRef label) {
    printCommon("type_member", label);

    printRec(T->getBaseComponent());
    for (auto *comp : T->getMemberComponents()) {
      printRec(comp);
    }
    printFoot();
  }

  void visitFunctionTypeRepr(FunctionTypeRepr *T, StringRef label) {
    printCommon("type_function", label);
    if (T->isAsync())
      OS << " async";
    if (T->isThrowing())
      OS << " throws";
    printRec(T->getArgsTypeRepr());
    printRec(T->getResultTypeRepr());
    printFoot();
  }

  void visitArrayTypeRepr(ArrayTypeRepr *T, StringRef label) {
    printCommon("type_array", label);
    printRec(T->getBase());
    printFoot();
  }

  void visitDictionaryTypeRepr(DictionaryTypeRepr *T, StringRef label) {
    printCommon("type_dictionary", label);
    printRec(T->getKey());
    printRec(T->getValue());
    printFoot();
  }

  void visitVarargTypeRepr(VarargTypeRepr *T, StringRef label) {
    printCommon("vararg", label);
    printRec(T->getElementType());
    printFoot();
  }

  void visitPackTypeRepr(PackTypeRepr *T, StringRef label) {
    printCommon("pack", label);
    for (auto elt : T->getElements())
      printRec(elt);
    printFoot();
  }

  void visitPackExpansionTypeRepr(PackExpansionTypeRepr *T, StringRef label) {
    printCommon("pack_expansion", label);
    printRec(T->getPatternType());
    printFoot();
  }

  void visitPackElementTypeRepr(PackElementTypeRepr *T, StringRef label) {
    printCommon("pack_element", label);
    printRec(T->getPackType());
    printFoot();
  }

  void visitTupleTypeRepr(TupleTypeRepr *T, StringRef label) {
    printCommon("type_tuple", label);

    if (T->hasElementNames()) {
      OS << " names=";
      for (unsigned i = 0, end = T->getNumElements(); i != end; ++i) {
        if (i) OS << ",";
        auto name = T->getElementName(i);
        if (T->isNamedParameter(i))
          OS << (name.empty() ? "_" : "_ " + name.str());
        else
          OS << (name.empty() ? "''" : name.str());
      }
    }

    for (auto elem : T->getElements()) {
      printRec(elem.Type);
    }
    printFoot();
  }

  void visitCompositionTypeRepr(CompositionTypeRepr *T, StringRef label) {
    printCommon("type_composite", label);
    for (auto elem : T->getTypes()) {
      printRec(elem);
    }
    printFoot();
  }

  void visitMetatypeTypeRepr(MetatypeTypeRepr *T, StringRef label) {
    printCommon("type_metatype", label);
    printRec(T->getBase());
    printFoot();
  }

  void visitProtocolTypeRepr(ProtocolTypeRepr *T, StringRef label) {
    printCommon("type_protocol", label);
    printRec(T->getBase());
    printFoot();
  }

  void visitOwnershipTypeRepr(OwnershipTypeRepr *T, StringRef label) {
    printCommon("type_ownership", label)
        << ' ' << getDumpString(T->getSpecifier());
    printRec(T->getBase());
    printFoot();
  }
  
  void visitIsolatedTypeRepr(IsolatedTypeRepr *T, StringRef label) {
    printCommon("isolated", label);
    printRec(T->getBase());
    printFoot();
  }

  void visitCompileTimeConstTypeRepr(CompileTimeConstTypeRepr *T, StringRef label) {
    printCommon("_const", label);
    printRec(T->getBase());
    printFoot();
  }

  void visitOptionalTypeRepr(OptionalTypeRepr *T, StringRef label) {
    printCommon("type_optional", label);
    printRec(T->getBase());
    printFoot();
  }

  void visitImplicitlyUnwrappedOptionalTypeRepr(
      ImplicitlyUnwrappedOptionalTypeRepr *T, StringRef label) {
    printCommon("type_implicitly_unwrapped_optional", label);
    printRec(T->getBase());
    printFoot();
  }

  void visitOpaqueReturnTypeRepr(OpaqueReturnTypeRepr *T, StringRef label) {
    printCommon("type_opaque_return", label);
    printRec(T->getConstraint());
    printFoot();
  }

  void visitNamedOpaqueReturnTypeRepr(NamedOpaqueReturnTypeRepr *T, StringRef label) {
    printCommon("type_named_opaque_return", label);
    printRec(T->getBase());
    printFoot();
  }

  void visitExistentialTypeRepr(ExistentialTypeRepr *T, StringRef label) {
    printCommon("type_existential", label);
    printRec(T->getConstraint());
    printFoot();
  }

  void visitPlaceholderTypeRepr(PlaceholderTypeRepr *T, StringRef label) {
    printCommon("type_placeholder", label);
    printFoot();
  }

  void visitFixedTypeRepr(FixedTypeRepr *T, StringRef label) {
    printCommon("type_fixed", label);
    auto Ty = T->getType();
    if (Ty) {
      auto &srcMgr =  Ty->getASTContext().SourceMgr;
      if (T->getLoc().isValid()) {
        OS << " location=@";
        T->getLoc().print(OS, srcMgr);
      } else {
        OS << " location=<invalid>";
      }
    }
    OS << " type="; Ty.dump(OS);
    printFoot();
  }

  void visitSelfTypeRepr(SelfTypeRepr *T, StringRef label) {
    printCommon("type_self", label);
    auto Ty = T->getType();
    if (Ty) {
      auto &srcMgr =  Ty->getASTContext().SourceMgr;
      if (T->getLoc().isValid()) {
        OS << " location=@";
        T->getLoc().print(OS, srcMgr);
      } else {
        OS << " location=<invalid>";
      }
    }
    OS << " type="; Ty.dump(OS);
    printFoot();
  }

  void visitSILBoxTypeRepr(SILBoxTypeRepr *T, StringRef label) {
    printCommon("sil_box", label);
    Indent += 2;

    ArrayRef<SILBoxTypeReprField> Fields = T->getFields();
    for (unsigned i = 0, end = Fields.size(); i != end; ++i) {
      OS << '\n';
      printCommon("sil_box_field", label);
      if (Fields[i].isMutable()) {
        OS << " mutable";
      }
      printRec(Fields[i].getFieldType());
      printFoot();
    }

    for (auto genArg : T->getGenericArguments()) {
      printRec(genArg);
    }

    printFoot();
    Indent -= 2;
  }
};

void PrintBase::printRec(Decl *D, StringRef label) {
  OS << '\n';
  if (!D)
    OS.indent(Indent + 2) << "(<null decl>)";
  else
    PrintDecl(OS, Indent + 2, GetTypeOfExpr, GetTypeOfTypeRepr,
              GetTypeOfKeyPathComponent).visit(D, label);
}
void PrintBase::printRec(Expr *E, StringRef label) {
  OS << '\n';
  if (!E)
    OS.indent(Indent + 2) << "(<null expr>)";
  else
    PrintExpr(OS, Indent + 2, GetTypeOfExpr, GetTypeOfTypeRepr,
              GetTypeOfKeyPathComponent).visit(E, label);
}
void PrintBase::printRec(Stmt *S, const ASTContext *Ctx, StringRef label) {
  OS << '\n';
  if (!S)
    OS.indent(Indent + 2) << "(<null stmt>)";
  else
    PrintStmt(OS, Ctx, Indent + 2, GetTypeOfExpr, GetTypeOfTypeRepr,
              GetTypeOfKeyPathComponent).visit(S, label);
}
void PrintBase::printRec(TypeRepr *T, StringRef label) {
  OS << '\n';
  if (!T)
    OS.indent(Indent + 2) << "(<null typerepr>)";
  else
    PrintTypeRepr(OS, Indent + 2, GetTypeOfExpr, GetTypeOfTypeRepr,
                  GetTypeOfKeyPathComponent).visit(T, label);
}
void PrintBase::printRec(const Pattern *P, StringRef label) {
  OS << '\n';
  if (!P)
    OS.indent(Indent + 2) << "(<null pattern>)";
  else
    PrintPattern(OS, Indent + 2, GetTypeOfExpr, GetTypeOfTypeRepr,
                 GetTypeOfKeyPathComponent).visit(const_cast<Pattern *>(P),
                                                  label);
}


} // end anonymous namespace

void TypeRepr::dump() const {
  dump(llvm::errs());
  llvm::errs() << '\n';
}
void TypeRepr::dump(raw_ostream &os, unsigned indent) const {
  PrintTypeRepr(os, indent).visit(const_cast<TypeRepr*>(this), "");
}

// Recursive helpers to avoid infinite recursion for recursive protocol
// conformances.
static void dumpProtocolConformanceRec(
    const ProtocolConformance *conformance, llvm::raw_ostream &out,
    unsigned indent,
    llvm::SmallPtrSetImpl<const ProtocolConformance *> &visited);

static void dumpPackConformanceRec(
    const PackConformance *conformance, llvm::raw_ostream &out,
    unsigned indent,
    llvm::SmallPtrSetImpl<const ProtocolConformance *> &visited);

static void dumpProtocolConformanceRefRec(
    const ProtocolConformanceRef conformance, llvm::raw_ostream &out,
    unsigned indent,
    llvm::SmallPtrSetImpl<const ProtocolConformance *> &visited) {
  if (conformance.isInvalid()) {
    out.indent(indent) << "(invalid_conformance)";
  } else if (conformance.isConcrete()) {
    dumpProtocolConformanceRec(conformance.getConcrete(), out, indent, visited);
  } else if (conformance.isPack()) {
    dumpPackConformanceRec(conformance.getPack(), out, indent, visited);
  } else {
    assert(conformance.isAbstract());

    out.indent(indent) << "(abstract_conformance protocol="
                       << conformance.getAbstract()->getName();
    PrintWithColorRAII(out, ParenthesisColor) << ')';
  }
}

static void dumpProtocolConformanceRec(
    const ProtocolConformance *conformance, llvm::raw_ostream &out,
    unsigned indent,
    llvm::SmallPtrSetImpl<const ProtocolConformance *> &visited) {
  // A recursive conformance shouldn't have its contents printed, or there's
  // infinite recursion. (This also avoids printing things that occur multiple
  // times in a conformance hierarchy.)
  auto shouldPrintDetails = visited.insert(conformance).second;

  auto printCommon = [&](StringRef kind) {
    out.indent(indent);
    PrintWithColorRAII(out, ParenthesisColor) << '(';
    out << kind << "_conformance type=" << conformance->getType()
        << " protocol=" << conformance->getProtocol()->getName();

    if (!shouldPrintDetails)
      out << " (details printed above)";
  };

  switch (conformance->getKind()) {
  case ProtocolConformanceKind::Normal: {
    auto normal = cast<NormalProtocolConformance>(conformance);

    printCommon("normal");
    if (!shouldPrintDetails)
      break;

    // Maybe print information about the conforming context?
    if (normal->isLazilyLoaded()) {
      out << " lazy";
    } else {
      normal->forEachTypeWitness(
          [&](const AssociatedTypeDecl *req, Type ty,
              const TypeDecl *) -> bool {
            out << '\n';
            out.indent(indent + 2);
            PrintWithColorRAII(out, ParenthesisColor) << '(';
            out << "assoc_type req=" << req->getName() << " type=";
            PrintWithColorRAII(out, TypeColor) << Type(ty->getDesugaredType());
            PrintWithColorRAII(out, ParenthesisColor) << ')';
            return false;
          });
      normal->forEachValueWitness([&](const ValueDecl *req,
                                      Witness witness) {
        out << '\n';
        out.indent(indent + 2);
        PrintWithColorRAII(out, ParenthesisColor) << '(';
        out << "value req=" << req->getName() << " witness=";
        if (!witness) {
          out << "(none)";
        } else if (witness.getDecl() == req) {
          out << "(dynamic)";
        } else {
          witness.getDecl()->dumpRef(out);
        }
        PrintWithColorRAII(out, ParenthesisColor) << ')';
      });

      for (auto sigConf : normal->getSignatureConformances()) {
        out << '\n';
        dumpProtocolConformanceRefRec(sigConf, out, indent + 2, visited);
      }
    }

    if (auto condReqs = normal->getConditionalRequirementsIfAvailable()) {
      for (auto requirement : *condReqs) {
        out << '\n';
        out.indent(indent + 2);
        requirement.dump(out);
      }
    } else {
      out << '\n';
      out.indent(indent + 2);
      out << "(conditional requirements unable to be computed)";
    }
    break;
  }

  case ProtocolConformanceKind::Self: {
    printCommon("self");
    break;
  }

  case ProtocolConformanceKind::Inherited: {
    auto conf = cast<InheritedProtocolConformance>(conformance);
    printCommon("inherited");
    if (!shouldPrintDetails)
      break;

    out << '\n';
    dumpProtocolConformanceRec(conf->getInheritedConformance(), out, indent + 2,
                               visited);
    break;
  }

  case ProtocolConformanceKind::Specialized: {
    auto conf = cast<SpecializedProtocolConformance>(conformance);
    printCommon("specialized");
    if (!shouldPrintDetails)
      break;

    out << '\n';
    dumpSubstitutionMapRec(conf->getSubstitutionMap(), out,
                           SubstitutionMap::DumpStyle::Full, indent + 2,
                           visited);
    out << '\n';
    if (auto condReqs = conf->getConditionalRequirementsIfAvailableOrCached(
            /*computeIfPossible=*/false)) {
      for (auto subReq : *condReqs) {
        out.indent(indent + 2);
        subReq.dump(out);
        out << '\n';
      }
    } else {
      out.indent(indent + 2);
      out << "(conditional requirements unable to be computed)\n";
    }
    dumpProtocolConformanceRec(conf->getGenericConformance(), out, indent + 2,
                               visited);
    break;
  }

  case ProtocolConformanceKind::Builtin: {
    printCommon("builtin");
  }
  }

  PrintWithColorRAII(out, ParenthesisColor) << ')';
}

static void dumpPackConformanceRec(
    const PackConformance *conformance, llvm::raw_ostream &out,
    unsigned indent,
    llvm::SmallPtrSetImpl<const ProtocolConformance *> &visited) {
  out.indent(indent);
  PrintWithColorRAII(out, ParenthesisColor) << '(';
  out << "pack_conformance type=" << Type(conformance->getType())
      << " protocol=" << conformance->getProtocol()->getName();

  auto conformances = conformance->getPatternConformances();
  if (!conformances.empty()) {
    out << "\n";

    for (auto conformanceRef : conformances) {
      dumpProtocolConformanceRefRec(conformanceRef, out, indent, visited);
    }
  }

  PrintWithColorRAII(out, ParenthesisColor) << ')';
}

static void dumpSubstitutionMapRec(
    SubstitutionMap map, llvm::raw_ostream &out,
    SubstitutionMap::DumpStyle style, unsigned indent,
    llvm::SmallPtrSetImpl<const ProtocolConformance *> &visited) {
  auto genericSig = map.getGenericSignature();
  out.indent(indent);

  auto printParen = [&](char p) {
    PrintWithColorRAII(out, ParenthesisColor) << p;
  };
  printParen('(');
  SWIFT_DEFER { printParen(')'); };
  out << "substitution_map generic_signature=";
  if (genericSig.isNull()) {
    out << "<nullptr>";
    return;
  }

  genericSig->print(out);
  auto genericParams = genericSig.getGenericParams();
  auto replacementTypes =
      static_cast<const SubstitutionMap &>(map).getReplacementTypesBuffer();
  for (unsigned i : indices(genericParams)) {
    if (style == SubstitutionMap::DumpStyle::Minimal) {
      out << " ";
    } else {
      out << "\n";
      out.indent(indent + 2);
    }
    printParen('(');
    out << "substitution ";
    genericParams[i]->print(out);
    out << " -> ";
    if (replacementTypes[i]) {
      PrintOptions opts;
      opts.PrintForSIL = true;
      opts.PrintTypesForDebugging = true;
      replacementTypes[i]->print(out, opts);
    }
    else
      out << "<<unresolved concrete type>>";
    printParen(')');
  }
  // A minimal dump doesn't need the details about the conformances, a lot of
  // that info can be inferred from the signature.
  if (style == SubstitutionMap::DumpStyle::Minimal)
    return;

  auto conformances = map.getConformances();
  for (const auto &req : genericSig.getRequirements()) {
    if (req.getKind() != RequirementKind::Conformance)
      continue;

    out << "\n";
    out.indent(indent + 2);
    printParen('(');
    out << "conformance type=";
    req.getFirstType()->print(out);
    out << "\n";
    dumpProtocolConformanceRefRec(conformances.front(), out, indent + 4,
                                  visited);

    printParen(')');
    conformances = conformances.slice(1);
  }
}

void ProtocolConformanceRef::dump() const {
  dump(llvm::errs());
  llvm::errs() << '\n';
}

void ProtocolConformanceRef::dump(llvm::raw_ostream &out, unsigned indent,
                                  bool details) const {
  llvm::SmallPtrSet<const ProtocolConformance *, 8> visited;
  if (!details && isConcrete())
    visited.insert(getConcrete());

  dumpProtocolConformanceRefRec(*this, out, indent, visited);
}

void ProtocolConformanceRef::print(llvm::raw_ostream &out) const {
  llvm::SmallPtrSet<const ProtocolConformance *, 8> visited;
  dumpProtocolConformanceRefRec(*this, out, 0, visited);
}

void ProtocolConformance::dump() const {
  auto &out = llvm::errs();
  dump(out);
  out << '\n';
}

void ProtocolConformance::dump(llvm::raw_ostream &out, unsigned indent) const {
  llvm::SmallPtrSet<const ProtocolConformance *, 8> visited;
  dumpProtocolConformanceRec(this, out, indent, visited);
}

void PackConformance::dump(llvm::raw_ostream &out, unsigned indent) const {
  llvm::SmallPtrSet<const ProtocolConformance *, 8> visited;
  dumpPackConformanceRec(this, out, indent, visited);
}

void SubstitutionMap::dump(llvm::raw_ostream &out, DumpStyle style,
                           unsigned indent) const {
  llvm::SmallPtrSet<const ProtocolConformance *, 8> visited;
  dumpSubstitutionMapRec(*this, out, style, indent, visited);
}

void SubstitutionMap::dump() const {
  dump(llvm::errs());
  llvm::errs() << "\n";
}

//===----------------------------------------------------------------------===//
// Dumping for Types.
//===----------------------------------------------------------------------===//

namespace {
  class PrintType : public TypeVisitor<PrintType, void, StringRef>,
                    public PrintBase {
    raw_ostream &printCommon(StringRef label, StringRef name) {
      return printHead(name, TypeColor, label);
    }

    // Print a single flag.
    raw_ostream &printFlag(StringRef name) {
      PrintWithColorRAII(OS, FieldLabelColor) << " " << name;
      return OS;
    }

    // Print a single flag if it is set.
    raw_ostream &printFlag(bool isSet, StringRef name) {
      if (isSet)
        printFlag(name);

      return OS;
    }

    // Print a field with a value.
    template<typename T>
    raw_ostream &printField(StringRef name, const T &value) {
      OS << " ";
      PrintWithColorRAII(OS, FieldLabelColor) << name;
      OS << "=" << value;
      return OS;
    }

    void dumpParameterFlags(ParameterTypeFlags paramFlags) {
      printFlag(paramFlags.isVariadic(), "vararg");
      printFlag(paramFlags.isAutoClosure(), "autoclosure");
      printFlag(paramFlags.isNonEphemeral(), "nonEphemeral");
      printFlag(paramFlags.isCompileTimeConst(), "compileTimeConst");
      printFlag(getDumpString(paramFlags.getValueOwnership()));
    }

  public:
    using PrintBase::PrintBase;

#define TRIVIAL_TYPE_PRINTER(Class,Name)                        \
    void visit##Class##Type(Class##Type *T, StringRef label) {  \
      printCommon(label, #Name "_type") << ")";              \
    }

    void visitErrorType(ErrorType *T, StringRef label) {
      printCommon(label, "error_type");
      if (auto originalType = T->getOriginalType())
        printRec(originalType, "original_type");
      printFoot();
    }

    TRIVIAL_TYPE_PRINTER(Unresolved, unresolved)

    void visitPlaceholderType(PlaceholderType *T, StringRef label) {
      printCommon(label, "placeholder_type");
      auto originator = T->getOriginator();
      if (auto *typeVar = originator.dyn_cast<TypeVariableType *>()) {
        printRec(typeVar, "type_variable");
      } else if (auto *VD = originator.dyn_cast<VarDecl *>()) {
        VD->dumpRef(PrintWithColorRAII(OS, DeclColor).getOS());
      } else if (auto *EE = originator.dyn_cast<ErrorExpr *>()) {
        printFlag("error_expr");
      } else if (auto *DMT = originator.dyn_cast<DependentMemberType *>()) {
        printRec(DMT, "dependent_member_type");
      } else if (originator.is<PlaceholderTypeRepr *>()) {
        printFlag("placeholder_type_repr");
      } else {
        assert(false && "unknown originator");
      }
      printFoot();
    }

    void visitBuiltinIntegerType(BuiltinIntegerType *T, StringRef label) {
      printCommon(label, "builtin_integer_type");
      if (T->isFixedWidth())
        printField("bit_width", T->getFixedWidth());
      else
        printFlag("word_sized");
      printFoot();
    }

    void visitBuiltinFloatType(BuiltinFloatType *T, StringRef label) {
      printCommon(label, "builtin_float_type");
      printField("bit_width", T->getBitWidth());
      printFoot();
    }

    TRIVIAL_TYPE_PRINTER(BuiltinIntegerLiteral, builtin_integer_literal)
    TRIVIAL_TYPE_PRINTER(BuiltinJob, builtin_job)
    TRIVIAL_TYPE_PRINTER(BuiltinExecutor, builtin_executor_ref)
    TRIVIAL_TYPE_PRINTER(BuiltinDefaultActorStorage, builtin_default_actor_storage)
    TRIVIAL_TYPE_PRINTER(BuiltinNonDefaultDistributedActorStorage, builtin_non_default_distributed_actor_storage)
    TRIVIAL_TYPE_PRINTER(BuiltinPackIndex, builtin_pack_index)
    TRIVIAL_TYPE_PRINTER(BuiltinRawPointer, builtin_raw_pointer)
    TRIVIAL_TYPE_PRINTER(BuiltinRawUnsafeContinuation, builtin_raw_unsafe_continuation)
    TRIVIAL_TYPE_PRINTER(BuiltinNativeObject, builtin_native_object)
    TRIVIAL_TYPE_PRINTER(BuiltinBridgeObject, builtin_bridge_object)
    TRIVIAL_TYPE_PRINTER(BuiltinUnsafeValueBuffer, builtin_unsafe_value_buffer)
    TRIVIAL_TYPE_PRINTER(SILToken, sil_token)

    void visitBuiltinVectorType(BuiltinVectorType *T, StringRef label) {
      printCommon(label, "builtin_vector_type");
      printField("num_elements", T->getNumElements());
      printRec(T->getElementType());
      printFoot();
    }

    void visitTypeAliasType(TypeAliasType *T, StringRef label) {
      printCommon(label, "type_alias_type");
      printField("decl", T->getDecl()->printRef());
      PrintWithColorRAII(OS, TypeColor) << " underlying=";
      if (auto underlying = T->getSinglyDesugaredType()) {
        PrintWithColorRAII(OS, TypeColor)
          << "'" << underlying->getString() << "'";
      } else {
        PrintWithColorRAII(OS, TypeColor) << "<<<unresolved>>>";
      }
      if (T->getParent())
        printRec(T->getParent(), "parent");

      for (const auto &arg : T->getDirectGenericArgs())
        printRec(arg);
      printFoot();
    }

    void visitPackType(PackType *T, StringRef label) {
      printCommon(label, "pack_type");
      printField("num_elements", T->getNumElements());
      Indent += 2;
      for (Type elt : T->getElementTypes()) {
        printRec(elt);
      }
      Indent -= 2;
      printFoot();
    }

    void visitSILPackType(SILPackType *T, StringRef label) {
      printCommon(label, "sil_pack_type");
      printField("element_is_address", T->isElementAddress());
      printField("num_elements", T->getNumElements());
      Indent += 2;
      for (Type elt : T->getElementTypes()) {
        printRec(elt);
      }
      Indent -= 2;
      printFoot();
    }

    void visitPackExpansionType(PackExpansionType *T, StringRef label) {
      printCommon(label, "pack_expansion_type");
      printRec(T->getPatternType(), "pattern");
      printRec(T->getCountType(), "count");
      printFoot();
    }

    void visitPackElementType(PackElementType *T, StringRef label) {
      printCommon(label, "element_type");
      printField("level", T->getLevel());
      printRec(T->getPackType(), "pack");
      printFoot();
    }

    void visitParenType(ParenType *T, StringRef label) {
      printCommon(label, "paren_type");
      printRec(T->getUnderlyingType());
      printFoot();
    }

    void visitTupleType(TupleType *T, StringRef label) {
      printCommon(label, "tuple_type");
      printField("num_elements", T->getNumElements());
      Indent += 2;
      for (const auto &elt : T->getElements()) {
        OS << "\n";
        printHead("tuple_type_elt", FieldLabelColor);
        if (elt.hasName())
          printField("name", elt.getName().str());
        printRec(elt.getType());
        OS << ")";
      }
      Indent -= 2;
      printFoot();
    }

#define REF_STORAGE(Name, name, ...) \
    void visit##Name##StorageType(Name##StorageType *T, StringRef label) { \
      printCommon(label, #name "_storage_type"); \
      printRec(T->getReferentType()); \
      printFoot(); \
    }
#include "swift/AST/ReferenceStorage.def"

    void visitEnumType(EnumType *T, StringRef label) {
      printCommon(label, "enum_type");
      printField("decl", T->getDecl()->printRef());
      if (T->getParent())
        printRec(T->getParent(), "parent");
      printFoot();
    }

    void visitStructType(StructType *T, StringRef label) {
      printCommon(label, "struct_type");
      printField("decl", T->getDecl()->printRef());
      if (T->getParent())
        printRec(T->getParent(), "parent");
      printFoot();
    }

    void visitClassType(ClassType *T, StringRef label) {
      printCommon(label, "class_type");
      printField("decl", T->getDecl()->printRef());
      if (T->getParent())
        printRec(T->getParent(), "parent");
      printFoot();
    }

    void visitProtocolType(ProtocolType *T, StringRef label) {
      printCommon(label, "protocol_type");
      printField("decl", T->getDecl()->printRef());
      if (T->getParent())
        printRec(T->getParent(), "parent");
      printFoot();
    }

    void visitBuiltinTupleType(BuiltinTupleType *T, StringRef label) {
      printCommon(label, "builtin_tuple_type");
      printField("decl", T->getDecl()->printRef());
      printFoot();
    }

    void visitMetatypeType(MetatypeType *T, StringRef label) {
      printCommon(label, "metatype_type");
      if (T->hasRepresentation())
        OS << " " << getDumpString(T->getRepresentation());
      printRec(T->getInstanceType());
      printFoot();
    }

    void visitExistentialMetatypeType(ExistentialMetatypeType *T,
                                      StringRef label) {
      printCommon(label, "existential_metatype_type");
      if (T->hasRepresentation())
        OS << " " << getDumpString(T->getRepresentation());
      printRec(T->getInstanceType());
      printFoot();
    }

    void visitModuleType(ModuleType *T, StringRef label) {
      printCommon(label, "module_type");
      printField("module", T->getModule()->getName());
      printFoot();
    }

    void visitDynamicSelfType(DynamicSelfType *T, StringRef label) {
      printCommon(label, "dynamic_self_type");
      printRec(T->getSelfType());
      printFoot();
    }
    
    void printArchetypeCommon(ArchetypeType *T,
                              StringRef className,
                              StringRef label) {
      printCommon(label, className);
      printField("address", static_cast<void *>(T));
      printRec(T->getInterfaceType(), "interface_type");
      printFlag(T->requiresClass(), "class");
      if (auto layout = T->getLayoutConstraint()) {
        OS << " layout=";
        layout->print(OS);
      }
      for (auto proto : T->getConformsTo())
        printField("conforms_to", proto->printRef());
      if (auto superclass = T->getSuperclass())
        printRec(superclass, "superclass");

    }
    
    void visitPrimaryArchetypeType(PrimaryArchetypeType *T, StringRef label) {
      printArchetypeCommon(T, "primary_archetype_type", label);
      printField("name", T->getFullName());
      printFoot();
    }
    void visitOpenedArchetypeType(OpenedArchetypeType *T, StringRef label) {
      printArchetypeCommon(T, "opened_archetype_type", label);
      printRec(               T->getGenericEnvironment()->getOpenedExistentialType(), "opened_existential");
      printField("opened_existential_id", T->getOpenedExistentialID());
      printFoot();
    }
    void visitOpaqueTypeArchetypeType(OpaqueTypeArchetypeType *T,
                                      StringRef label) {
      printArchetypeCommon(T, "opaque_type", label);
      printField("decl", T->getDecl()->getNamingDecl()->printRef());
      if (!T->getSubstitutions().empty()) {
        OS << '\n';
        SmallPtrSet<const ProtocolConformance *, 4> Dumped;
        dumpSubstitutionMapRec(T->getSubstitutions(), OS,
                               SubstitutionMap::DumpStyle::Full,
                               Indent + 2, Dumped);
      }
      printFoot();
    }
    void visitPackArchetypeType(PackArchetypeType *T, StringRef label) {
      printArchetypeCommon(T, "pack_archetype_type", label);
      printField("name", T->getFullName());
      printFoot();
    }
    void visitElementArchetypeType(ElementArchetypeType *T, StringRef label) {
      printArchetypeCommon(T, "element_archetype_type", label);
      printField("opened_element_id", T->getOpenedElementID());
      printFoot();
    }

    void visitGenericTypeParamType(GenericTypeParamType *T, StringRef label) {
      printCommon(label, "generic_type_param_type");
      printField("depth", T->getDepth());
      printField("index", T->getIndex());
      if (auto decl = T->getDecl())
        printField("decl", decl->printRef());
      printFlag(T->isParameterPack(), "pack");
      printFoot();
    }

    void visitDependentMemberType(DependentMemberType *T, StringRef label) {
      printCommon(label, "dependent_member_type");
      if (auto assocType = T->getAssocType()) {
        printField("assoc_type", assocType->printRef());
      } else {
        printField("name", T->getName());
      }
      printRec(T->getBase(), "base");
      printFoot();
    }

    void printAnyFunctionParams(ArrayRef<AnyFunctionType::Param> params,
                                StringRef label) {
      printCommon(label, "function_params");
      printField("num_params", params.size());
      Indent += 2;
      for (const auto &param : params) {
        OS << "\n";
        printHead("param", FieldLabelColor);
        if (param.hasLabel())
          printField("name", param.getLabel().str());
        if (param.hasInternalLabel())
          printField("internal_name", param.getInternalLabel().str());
        dumpParameterFlags(param.getParameterFlags());
        printRec(param.getPlainType());
        printFoot();
      }
      Indent -= 2;
      printFoot();
    }

    void printAnyFunctionTypeCommon(AnyFunctionType *T, StringRef label,
                                    StringRef name) {
      printCommon(label, name);

      if (T->hasExtInfo()) {
        SILFunctionType::Representation representation =
            T->getExtInfo().getSILRepresentation();

        if (representation != SILFunctionType::Representation::Thick) {
          printField("representation", getDumpString(representation));
        }
        printFlag(!T->isNoEscape(), "escaping");
        printFlag(T->isSendable(), "Sendable");
        printFlag(T->isAsync(), "async");
        printFlag(T->isThrowing(), "throws");
      }

      if (Type globalActor = T->getGlobalActor()) {
        printField("global_actor", globalActor.getString());
      }

      OS << "\n";
      Indent += 2;
      // [TODO: Improve-Clang-type-printing]
      if (!T->getClangTypeInfo().empty()) {
        std::string s;
        llvm::raw_string_ostream os(s);
        auto &ctx = T->getASTContext().getClangModuleLoader()
          ->getClangASTContext();
        T->getClangTypeInfo().dump(os, ctx);
        printField("clang_type", os.str());
      }

      printAnyFunctionParams(T->getParams(), "input");
      Indent -=2;
      printRec(T->getResult(), "output");
    }

    void visitFunctionType(FunctionType *T, StringRef label) {
      printAnyFunctionTypeCommon(T, label, "function_type");
      printFoot();
    }

    void visitGenericFunctionType(GenericFunctionType *T, StringRef label) {
      printAnyFunctionTypeCommon(T, label, "generic_function_type");
      // FIXME: generic signature dumping needs improvement
      OS << "\n";
      printHead("generic_sig", TypeColor);
      OS << ' ' << QuotedString(T->getGenericSignature()->getAsString());
      printFoot();
    }

    void visitSILFunctionType(SILFunctionType *T, StringRef label) {
      printCommon(label, "sil_function_type");
      printField("type", T->getString());

      for (auto param : T->getParameters()) {
        printRec(param.getInterfaceType(), "input");
      }
      for (auto yield : T->getYields()) {
        printRec(yield.getInterfaceType(), "yield");
      }
      for (auto result : T->getResults()) {
        printRec(result.getInterfaceType(), "result");
      }
      if (auto error  = T->getOptionalErrorResult()) {
        printRec(error->getInterfaceType(), "error");
      }
      OS << '\n';
      T->getPatternSubstitutions().dump(OS, SubstitutionMap::DumpStyle::Full,
                                        Indent+2);
      OS << '\n';
      T->getInvocationSubstitutions().dump(OS, SubstitutionMap::DumpStyle::Full,
                                           Indent+2);
      // [TODO: Improve-Clang-type-printing]
      if (!T->getClangTypeInfo().empty()) {
        std::string s;
        llvm::raw_string_ostream os(s);
        auto &ctx =
            T->getASTContext().getClangModuleLoader()->getClangASTContext();
        T->getClangTypeInfo().dump(os, ctx);
        printField("clang_type", os.str());
      }
      printFoot();
    }

    void visitSILBlockStorageType(SILBlockStorageType *T, StringRef label) {
      printCommon(label, "sil_block_storage_type");
      printRec(T->getCaptureType());
      printFoot();
    }

    void visitSILMoveOnlyWrappedType(SILMoveOnlyWrappedType *T,
                                     StringRef label) {
      printCommon(label, "sil_move_only_type");
      printRec(T->getInnerType());
      printFoot();
    }

    void visitSILBoxType(SILBoxType *T, StringRef label) {
      printCommon(label, "sil_box_type");
      // FIXME: Print the structure of the type.
      printField("type", T->getString());
      printFoot();
    }

    void visitArraySliceType(ArraySliceType *T, StringRef label) {
      printCommon(label, "array_slice_type");
      printRec(T->getBaseType());
      printFoot();
    }

    void visitOptionalType(OptionalType *T, StringRef label) {
      printCommon(label, "optional_type");
      printRec(T->getBaseType());
      printFoot();
    }

    void visitDictionaryType(DictionaryType *T, StringRef label) {
      printCommon(label, "dictionary_type");
      printRec(T->getKeyType(), "key");
      printRec(T->getValueType(), "value");
      printFoot();
    }

    void visitVariadicSequenceType(VariadicSequenceType *T, StringRef label) {
      printCommon(label, "variadic_sequence_type");
      printRec(T->getBaseType());
      printFoot();
    }

    void visitProtocolCompositionType(ProtocolCompositionType *T,
                                      StringRef label) {
      printCommon(label, "protocol_composition_type");
      if (T->hasExplicitAnyObject())
        OS << " any_object";
      for (auto proto : T->getMembers()) {
        printRec(proto);
      }
      printFoot();
    }

    void visitParameterizedProtocolType(ParameterizedProtocolType *T,
                                        StringRef label) {
      printCommon(label, "parameterized_protocol_type");
      printRec(T->getBaseType(), "base");
      for (auto arg : T->getArgs()) {
        printRec(arg);
      }
      printFoot();
    }

    void visitExistentialType(ExistentialType *T,
                              StringRef label) {
      printCommon(label, "existential_type");
      printRec(T->getConstraintType());
      printFoot();
    }

    void visitLValueType(LValueType *T, StringRef label) {
      printCommon(label, "lvalue_type");
      printRec(T->getObjectType());
      printFoot();
    }

    void visitInOutType(InOutType *T, StringRef label) {
      printCommon(label, "inout_type");
      printRec(T->getObjectType());
      printFoot();
    }

    void visitUnboundGenericType(UnboundGenericType *T, StringRef label) {
      printCommon(label, "unbound_generic_type");
      printField("decl", T->getDecl()->printRef());
      if (T->getParent())
        printRec(T->getParent(), "parent");
      printFoot();
    }

    void visitBoundGenericClassType(BoundGenericClassType *T, StringRef label) {
      printCommon(label, "bound_generic_class_type");
      printField("decl", T->getDecl()->printRef());
      if (T->getParent())
        printRec(T->getParent(), "parent");
      for (auto arg : T->getGenericArgs())
        printRec(arg);
      printFoot();
    }

    void visitBoundGenericStructType(BoundGenericStructType *T,
                                     StringRef label) {
      printCommon(label, "bound_generic_struct_type");
      printField("decl", T->getDecl()->printRef());
      if (T->getParent())
        printRec(T->getParent(), "parent");
      for (auto arg : T->getGenericArgs())
        printRec(arg);
      printFoot();
    }

    void visitBoundGenericEnumType(BoundGenericEnumType *T, StringRef label) {
      printCommon(label, "bound_generic_enum_type");
      printField("decl", T->getDecl()->printRef());
      if (T->getParent())
        printRec(T->getParent(), "parent");
      for (auto arg : T->getGenericArgs())
        printRec(arg);
      printFoot();
    }

    void visitTypeVariableType(TypeVariableType *T, StringRef label) {
      printCommon(label, "type_variable_type");
      printField("id", T->getID());
      printFoot();
    }

#undef TRIVIAL_TYPE_PRINTER
  };

  void PrintBase::printRec(Type type, StringRef label) {
    OS << '\n';

    if (type.isNull())
      OS.indent(Indent + 2) << "(<null type>)";
    else {
      PrintType(OS, Indent + 2, GetTypeOfExpr, GetTypeOfTypeRepr,
                GetTypeOfKeyPathComponent).visit(type, label);
    }
  }
} // end anonymous namespace

void Type::dump() const {
  dump(llvm::errs());
}

void Type::dump(raw_ostream &os, unsigned indent) const {
  PrintType(os, indent).visit(*this, "");
  os << "\n";
}

void TypeBase::dump() const {
  // Make sure to print type variables.
  Type(const_cast<TypeBase *>(this)).dump();
}

void TypeBase::dump(raw_ostream &os, unsigned indent) const {
  Type(const_cast<TypeBase *>(this)).dump(os, indent);
}

void GenericSignatureImpl::dump() const {
  GenericSignature(const_cast<GenericSignatureImpl *>(this)).dump();
}

void GenericEnvironment::dump(raw_ostream &os) const {
  os << "Generic environment:\n";
  for (auto gp : getGenericParams()) {
    gp->dump(os);
    mapTypeIntoContext(gp)->dump(os);
  }
  os << "Generic parameters:\n";
  for (auto paramTy : getGenericParams())
    paramTy->dump(os);
}

void GenericEnvironment::dump() const {
  dump(llvm::errs());
}

StringRef swift::getAccessorKindString(AccessorKind value) {
  switch (value) {
#define ACCESSOR(ID)
#define SINGLETON_ACCESSOR(ID, KEYWORD) \
  case AccessorKind::ID: return #KEYWORD;
#include "swift/AST/AccessorKinds.def"
  }

  llvm_unreachable("Unhandled AccessorKind in switch.");
}

void StableSerializationPath::dump() const {
  dump(llvm::errs());
}

static StringRef getExternalPathComponentKindString(
                  StableSerializationPath::ExternalPath::ComponentKind kind) {
  switch (kind) {
#define CASE(ID, STRING) \
  case StableSerializationPath::ExternalPath::ID: return STRING;
  CASE(Record, "record")
  CASE(Enum, "enum")
  CASE(Namespace, "namespace")
  CASE(Typedef, "typedef")
  CASE(TypedefAnonDecl, "anonymous tag")
  CASE(ObjCInterface, "@interface")
  CASE(ObjCProtocol, "@protocol")
#undef CASE
  }
  llvm_unreachable("bad kind");
}

void StableSerializationPath::dump(llvm::raw_ostream &os) const {
  if (isSwiftDecl()) {
    os << "clang decl of:\n";
    getSwiftDecl()->dump(os, 2);
  } else {
    auto &path = getExternalPath();
    using ExternalPath = StableSerializationPath::ExternalPath;
    os << "external path: ";
    size_t index = 0;
    for (auto &entry : path.Path) {
      if (index++) os << " -> ";
      os << getExternalPathComponentKindString(entry.first);
      if (ExternalPath::requiresIdentifier(entry.first))  {
        os << "(" << entry.second << ")";
      }
    }
    os << "\n";
  }
}

void RequirementRepr::dump() const {
  print(llvm::errs());
  llvm::errs() << "\n";
}

void GenericParamList::dump() const {
  print(llvm::errs());
  llvm::errs() << '\n';
}

void LayoutConstraint::dump() const {
  if (!*this) {
    llvm::errs() << "(null)\n";
    return;
  }
  getPointer()->print(llvm::errs());
}

void GenericSignature::dump() const {
  print(llvm::errs());
  llvm::errs() << '\n';
}

void Requirement::dump() const {
  dump(llvm::errs());
  llvm::errs() << '\n';
}
void Requirement::dump(raw_ostream &out) const {
  switch (getKind()) {
  case RequirementKind::SameShape:
    out << "same_shape: ";
    break;
  case RequirementKind::Conformance:
    out << "conforms_to: ";
    break;
  case RequirementKind::Layout:
    out << "layout: ";
    break;
  case RequirementKind::Superclass:
    out << "superclass: ";
    break;
  case RequirementKind::SameType:
    out << "same_type: ";
    break;
  }

  PrintOptions opts;
  opts.ProtocolQualifiedDependentMemberTypes = true;

  getFirstType().print(out, opts);
  out << " ";

  if (getKind() != RequirementKind::Layout && getSecondType())
    getSecondType().print(out, opts);
  else if (getLayoutConstraint())
    out << getLayoutConstraint();
}

void SILParameterInfo::dump() const {
  print(llvm::errs());
  llvm::errs() << '\n';
}

void SILResultInfo::dump() const {
  print(llvm::errs());
  llvm::errs() << '\n';
}
