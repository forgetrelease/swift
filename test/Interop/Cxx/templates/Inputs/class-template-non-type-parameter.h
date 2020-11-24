#ifndef TEST_INTEROP_CXX_TEMPLATES_INPUTS_CLASS_TEMPLATE_NON_TYPE_PARAMETER_H
#define TEST_INTEROP_CXX_TEMPLATES_INPUTS_CLASS_TEMPLATE_NON_TYPE_PARAMETER_H

template<class T = bool, auto Size = 3>
struct MagicArray {
    T t[Size];
};

typedef MagicArray<int, 2> MagicIntPair;

struct IntWrapper {
  int value;
  int getValue() const { return value; }
};

#endif  // TEST_INTEROP_CXX_TEMPLATES_INPUTS_CLASS_TEMPLATE_NON_TYPE_PARAMETER_H
