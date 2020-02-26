#include <cstddef>
#include <stdint.h>

class PrivateMemberLayout {
  uint32_t a;

public:
  uint32_t b;
};

inline size_t sizeOfPrivateMemberLayout() {
  return sizeof(PrivateMemberLayout);
}

inline size_t offsetOfPrivateMemberLayout_b() {
  return offsetof(PrivateMemberLayout, b);
}
