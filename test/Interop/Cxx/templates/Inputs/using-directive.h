#ifndef TEST_INTEROP_CXX_TEMPLATES_INPUTS_USING_DIRECTIVE_H
#define TEST_INTEROP_CXX_TEMPLATES_INPUTS_USING_DIRECTIVE_H

template<class T>
struct MagicWrapper {
  T t;
  int callGetInt() const {
    return t.getInt() + 5;
  }
};

struct MagicNumber {
  int getInt() const { return 6; }
};

using UsingWrappedMagicNumber = MagicWrapper<MagicNumber>;

#endif // TEST_INTEROP_CXX_TEMPLATES_INPUTS_USING_DIRECTIVE_H
