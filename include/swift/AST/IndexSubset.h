//===--- IndexSubset.h - Fixed-size subset of indices ---------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
// This file defines the `IndexSubset` class and support logic.
//
//===----------------------------------------------------------------------===//

#ifndef SWIFT_AST_INDEXSUBSET_H
#define SWIFT_AST_INDEXSUBSET_H

#include "swift/Basic/LLVM.h"
#include "swift/Basic/Range.h"
#include "swift/Basic/STLExtras.h"
#include "llvm/ADT/ArrayRef.h"
#include "llvm/ADT/FoldingSet.h"
#include "llvm/ADT/SmallBitVector.h"
#include "llvm/Support/raw_ostream.h"

namespace swift {

class ASTContext;

/// An efficient index subset data structure, uniqued in `ASTContext`.
/// Stores a bit vector representing set indices and a total capacity.
class IndexSubset : public llvm::FoldingSetNode {
public:
  typedef uint64_t BitWord;

  static constexpr unsigned bitWordSize = sizeof(BitWord);
  static constexpr unsigned numBitsPerBitWord = bitWordSize * 8;

  static std::pair<unsigned, unsigned>
  getBitWordIndexAndOffset(unsigned index) {
    auto bitWordIndex = index / numBitsPerBitWord;
    auto bitWordOffset = index % numBitsPerBitWord;
    return {bitWordIndex, bitWordOffset};
  }

  static unsigned getNumBitWordsNeededForCapacity(unsigned capacity) {
    if (capacity == 0) return 0;
    return capacity / numBitsPerBitWord + 1;
  }

private:
  /// The total capacity of the index subset, which is `1` less than the largest
  /// index.
  unsigned capacity;
  /// The number of bit words in the index subset.
  unsigned numBitWords;

  BitWord *getBitWordsData() {
    return reinterpret_cast<BitWord *>(this + 1);
  }

  const BitWord *getBitWordsData() const {
    return reinterpret_cast<const BitWord *>(this + 1);
  }

  ArrayRef<BitWord> getBitWords() const {
    return {getBitWordsData(), getNumBitWords()};
  }

  BitWord getBitWord(unsigned i) const {
    return getBitWordsData()[i];
  }

  BitWord &getBitWord(unsigned i) {
    return getBitWordsData()[i];
  }

  MutableArrayRef<BitWord> getMutableBitWords() {
    return {const_cast<BitWord *>(getBitWordsData()), getNumBitWords()};
  }

  explicit IndexSubset(const SmallBitVector &indices)
  : capacity((unsigned)indices.size()),
  numBitWords(getNumBitWordsNeededForCapacity(capacity)) {
    std::uninitialized_fill_n(getBitWordsData(), numBitWords, 0);
    for (auto i : indices.set_bits()) {
      unsigned bitWordIndex, offset;
      std::tie(bitWordIndex, offset) = getBitWordIndexAndOffset(i);
      getBitWord(bitWordIndex) |= (1 << offset);
    }
  }

public:
  IndexSubset() = delete;
  IndexSubset(const IndexSubset &) = delete;
  IndexSubset &operator=(const IndexSubset &) = delete;

  // Defined in ASTContext.cpp.
  static IndexSubset *get(ASTContext &ctx, const SmallBitVector &indices);

  static IndexSubset *get(ASTContext &ctx, unsigned capacity,
                          ArrayRef<unsigned> indices) {
    SmallBitVector indicesBitVec(capacity, false);
    for (auto index : indices)
      indicesBitVec.set(index);
    return IndexSubset::get(ctx, indicesBitVec);
  }

  static IndexSubset *getDefault(ASTContext &ctx, unsigned capacity,
                                 bool includeAll = false) {
    return get(ctx, SmallBitVector(capacity, includeAll));
  }

  static IndexSubset *getFromRange(ASTContext &ctx, unsigned capacity,
                                   unsigned start, unsigned end) {
    assert(start < capacity);
    assert(end <= capacity);
    SmallBitVector bitVec(capacity);
    bitVec.set(start, end);
    return get(ctx, bitVec);
  }

  /// Creates an index subset corresponding to the given string generated by
  /// `getString()`. If the string is invalid, returns nullptr.
  static IndexSubset *getFromString(ASTContext &ctx, StringRef string);

  /// Returns the number of bit words used to store the index subset.
  // Note: Use `getCapacity()` to get the total index subset capacity.
  // This is public only for unit testing
  // (in unittests/AST/SILAutoDiffIndices.cpp).
  unsigned getNumBitWords() const {
    return numBitWords;
  }

  /// Returns the capacity of the index subset.
  unsigned getCapacity() const {
    return capacity;
  }

  /// Returns a textual string description of these indices.
  ///
  /// It has the format `[SU]+`, where the total number of characters is equal
  /// to the capacity, and where "S" means that the corresponding index is
  /// contained and "U" means that the corresponding index is not.
  std::string getString() const;

  class iterator;

  iterator begin() const {
    return iterator(this);
  }

  iterator end() const {
    return iterator(this, (int)capacity);
  }

  /// Returns an iterator range of indices in the index subset.
  iterator_range<iterator> getIndices() const {
    return make_range(begin(), end());
  }

  /// Returns the number of indices in the index subset.
  unsigned getNumIndices() const {
    return (unsigned)std::distance(begin(), end());
  }

  SmallBitVector getBitVector() const {
    SmallBitVector indicesBitVec(capacity, false);
    for (auto index : getIndices())
      indicesBitVec.set(index);
    return indicesBitVec;
  }

  bool contains(unsigned index) const {
    unsigned bitWordIndex, offset;
    std::tie(bitWordIndex, offset) = getBitWordIndexAndOffset(index);
    return getBitWord(bitWordIndex) & (1 << offset);
  }

  bool isEmpty() const {
    return llvm::all_of(getBitWords(), [](BitWord bw) { return !(bool)bw; });
  }

  bool equals(IndexSubset *other) const {
    return capacity == other->getCapacity() &&
    getBitWords().equals(other->getBitWords());
  }

  bool isSubsetOf(IndexSubset *other) const;
  bool isSupersetOf(IndexSubset *other) const;

  IndexSubset *adding(unsigned index, ASTContext &ctx) const;
  IndexSubset *extendingCapacity(ASTContext &ctx,
                                 unsigned newCapacity) const;

  void Profile(llvm::FoldingSetNodeID &id) const {
    id.AddInteger(capacity);
    for (auto index : getIndices())
      id.AddInteger(index);
  }

  void print(llvm::raw_ostream &s = llvm::outs()) const {
    s << '{';
    interleave(range(capacity), [this, &s](unsigned i) { s << contains(i); },
               [&s] { s << ", "; });
    s << '}';
  }

  void dump(llvm::raw_ostream &s = llvm::errs()) const {
    s << "(index_subset capacity=" << capacity << " indices=(";
    interleave(getIndices(), [&s](unsigned i) { s << i; },
               [&s] { s << ", "; });
    s << "))";
  }

  int findNext(int startIndex) const;
  int findFirst() const { return findNext(-1); }
  int findPrevious(int endIndex) const;
  int findLast() const { return findPrevious(capacity); }

  class iterator {
  public:
    typedef unsigned value_type;
    typedef unsigned difference_type;
    typedef unsigned * pointer;
    typedef unsigned & reference;
    typedef std::forward_iterator_tag iterator_category;

  private:
    const IndexSubset *parent;
    int current = 0;

    void advance() {
      assert(current != -1 && "Trying to advance past end.");
      current = parent->findNext(current);
    }

  public:
    iterator(const IndexSubset *parent, int current)
    : parent(parent), current(current) {}
    explicit iterator(const IndexSubset *parent)
    : iterator(parent, parent->findFirst()) {}
    iterator(const iterator &) = default;

    iterator operator++(int) {
      auto prev = *this;
      advance();
      return prev;
    }

    iterator &operator++() {
      advance();
      return *this;
    }

    unsigned operator*() const { return current; }

    bool operator==(const iterator &other) const {
      assert(parent == other.parent &&
             "Comparing iterators from different IndexSubsets");
      return current == other.current;
    }

    bool operator!=(const iterator &other) const {
      assert(parent == other.parent &&
             "Comparing iterators from different IndexSubsets");
      return current != other.current;
    }
  };
};

}

#endif // SWIFT_AST_INDEXSUBSET_H
