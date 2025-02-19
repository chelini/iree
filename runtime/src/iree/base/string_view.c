// Copyright 2019 The IREE Authors
//
// Licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

#include "iree/base/string_view.h"

#include <ctype.h>
#include <errno.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>

#include "iree/base/api.h"

static inline size_t iree_min_host_size(size_t a, size_t b) {
  return a < b ? a : b;
}

IREE_API_EXPORT bool iree_string_view_equal(iree_string_view_t lhs,
                                            iree_string_view_t rhs) {
  if (lhs.size != rhs.size) return false;
  for (iree_host_size_t i = 0; i < lhs.size; ++i) {
    if (lhs.data[i] != rhs.data[i]) return false;
  }
  return true;
}

IREE_API_EXPORT int iree_string_view_compare(iree_string_view_t lhs,
                                             iree_string_view_t rhs) {
  iree_host_size_t min_size = iree_min_host_size(lhs.size, rhs.size);
  int cmp = strncmp(lhs.data, rhs.data, min_size);
  if (cmp != 0) {
    return cmp;
  } else if (lhs.size == rhs.size) {
    return 0;
  }
  return lhs.size < rhs.size ? -1 : 1;
}

IREE_API_EXPORT iree_host_size_t iree_string_view_find_char(
    iree_string_view_t value, char c, iree_host_size_t pos) {
  if (iree_string_view_is_empty(value) || pos >= value.size) {
    return IREE_STRING_VIEW_NPOS;
  }
  const char* result =
      (const char*)(memchr(value.data + pos, c, value.size - pos));
  return result != NULL ? result - value.data : IREE_STRING_VIEW_NPOS;
}

IREE_API_EXPORT iree_host_size_t iree_string_view_find_first_of(
    iree_string_view_t value, iree_string_view_t s, iree_host_size_t pos) {
  if (iree_string_view_is_empty(value) || iree_string_view_is_empty(s)) {
    return IREE_STRING_VIEW_NPOS;
  }
  if (s.size == 1) {
    // Avoid the cost of the lookup table for a single-character search.
    return iree_string_view_find_char(value, s.data[0], pos);
  }
  bool lookup_table[UCHAR_MAX + 1] = {0};
  for (iree_host_size_t i = 0; i < s.size; ++i) {
    lookup_table[(uint8_t)s.data[i]] = true;
  }
  for (iree_host_size_t i = pos; i < value.size; ++i) {
    if (lookup_table[(uint8_t)value.data[i]]) {
      return i;
    }
  }
  return IREE_STRING_VIEW_NPOS;
}

IREE_API_EXPORT iree_host_size_t iree_string_view_find_last_of(
    iree_string_view_t value, iree_string_view_t s, iree_host_size_t pos) {
  if (iree_string_view_is_empty(value) || iree_string_view_is_empty(s)) {
    return IREE_STRING_VIEW_NPOS;
  }
  bool lookup_table[UCHAR_MAX + 1] = {0};
  for (iree_host_size_t i = 0; i < s.size; ++i) {
    lookup_table[(uint8_t)s.data[i]] = true;
  }
  pos = iree_min(pos, value.size) + 1;
  iree_host_size_t i = pos;
  while (i != 0) {
    --i;
    if (lookup_table[(uint8_t)value.data[i]]) {
      return i;
    }
  }
  return IREE_STRING_VIEW_NPOS;
}

IREE_API_EXPORT bool iree_string_view_starts_with(iree_string_view_t value,
                                                  iree_string_view_t prefix) {
  if (!value.data || !prefix.data || !prefix.size || prefix.size > value.size) {
    return false;
  }
  return strncmp(value.data, prefix.data, prefix.size) == 0;
}

IREE_API_EXPORT bool iree_string_view_ends_with(iree_string_view_t value,
                                                iree_string_view_t suffix) {
  if (!value.data || !suffix.data || !suffix.size || suffix.size > value.size) {
    return false;
  }
  return strncmp(value.data + value.size - suffix.size, suffix.data,
                 suffix.size) == 0;
}

IREE_API_EXPORT iree_string_view_t
iree_string_view_remove_prefix(iree_string_view_t value, iree_host_size_t n) {
  if (n >= value.size) {
    return iree_string_view_empty();
  }
  return iree_make_string_view(value.data + n, value.size - n);
}

IREE_API_EXPORT iree_string_view_t
iree_string_view_remove_suffix(iree_string_view_t value, iree_host_size_t n) {
  if (n >= value.size) {
    return iree_string_view_empty();
  }
  return iree_make_string_view(value.data, value.size - n);
}

IREE_API_EXPORT iree_string_view_t iree_string_view_strip_prefix(
    iree_string_view_t value, iree_string_view_t prefix) {
  if (iree_string_view_starts_with(value, prefix)) {
    return iree_string_view_remove_prefix(value, prefix.size);
  }
  return value;
}

IREE_API_EXPORT iree_string_view_t iree_string_view_strip_suffix(
    iree_string_view_t value, iree_string_view_t suffix) {
  if (iree_string_view_ends_with(value, suffix)) {
    return iree_string_view_remove_suffix(value, suffix.size);
  }
  return value;
}

IREE_API_EXPORT bool iree_string_view_consume_prefix(
    iree_string_view_t* value, iree_string_view_t prefix) {
  if (iree_string_view_starts_with(*value, prefix)) {
    *value = iree_string_view_remove_prefix(*value, prefix.size);
    return true;
  }
  return false;
}

IREE_API_EXPORT bool iree_string_view_consume_suffix(
    iree_string_view_t* value, iree_string_view_t suffix) {
  if (iree_string_view_ends_with(*value, suffix)) {
    *value = iree_string_view_remove_suffix(*value, suffix.size);
    return true;
  }
  return false;
}

IREE_API_EXPORT iree_string_view_t
iree_string_view_trim(iree_string_view_t value) {
  if (iree_string_view_is_empty(value)) return value;
  iree_host_size_t start = 0;
  iree_host_size_t end = value.size - 1;
  while (value.size > 0 && start <= end) {
    if (isspace(value.data[start])) {
      start++;
    } else {
      break;
    }
  }
  while (end > start) {
    if (isspace(value.data[end])) {
      --end;
    } else {
      break;
    }
  }
  return iree_make_string_view(value.data + start, end - start + 1);
}

IREE_API_EXPORT iree_string_view_t iree_string_view_substr(
    iree_string_view_t value, iree_host_size_t pos, iree_host_size_t n) {
  pos = iree_min_host_size(pos, value.size);
  n = iree_min_host_size(n, value.size - pos);
  return iree_make_string_view(value.data + pos, n);
}

IREE_API_EXPORT intptr_t iree_string_view_split(iree_string_view_t value,
                                                char split_char,
                                                iree_string_view_t* out_lhs,
                                                iree_string_view_t* out_rhs) {
  *out_lhs = iree_string_view_empty();
  *out_rhs = iree_string_view_empty();
  if (!value.data || !value.size) {
    return -1;
  }
  const void* first_ptr = memchr(value.data, split_char, value.size);
  if (!first_ptr) {
    *out_lhs = value;
    return -1;
  }
  intptr_t offset = (intptr_t)((const char*)(first_ptr)-value.data);
  if (out_lhs) {
    out_lhs->data = value.data;
    out_lhs->size = offset;
  }
  if (out_rhs) {
    out_rhs->data = value.data + offset + 1;
    out_rhs->size = value.size - offset - 1;
  }
  return offset;
}

IREE_API_EXPORT void iree_string_view_replace_char(iree_string_view_t value,
                                                   char old_char,
                                                   char new_char) {
  char* p = (char*)value.data;
  for (iree_host_size_t i = 0; i < value.size; ++i) {
    if (p[i] == old_char) p[i] = new_char;
  }
}

static bool iree_string_view_match_pattern_impl(iree_string_view_t value,
                                                iree_string_view_t pattern) {
  iree_host_size_t next_char_index = iree_string_view_find_first_of(
      pattern, iree_make_cstring_view("*?"), /*pos=*/0);
  if (next_char_index == IREE_STRING_VIEW_NPOS) {
    return iree_string_view_equal(value, pattern);
  } else if (next_char_index > 0) {
    iree_string_view_t value_prefix =
        iree_string_view_substr(value, 0, next_char_index);
    iree_string_view_t pattern_prefix =
        iree_string_view_substr(pattern, 0, next_char_index);
    if (!iree_string_view_equal(value_prefix, pattern_prefix)) {
      return false;
    }
    value =
        iree_string_view_substr(value, next_char_index, IREE_STRING_VIEW_NPOS);
    pattern = iree_string_view_substr(pattern, next_char_index,
                                      IREE_STRING_VIEW_NPOS);
  }
  if (iree_string_view_is_empty(value) && iree_string_view_is_empty(pattern)) {
    return true;
  }
  char pattern_char = pattern.data[0];
  if (pattern_char == '*' && pattern.size > 1 &&
      iree_string_view_is_empty(value)) {
    return false;
  } else if (pattern_char == '*' && pattern.size == 1) {
    return true;
  } else if (pattern_char == '?' || value.data[0] == pattern_char) {
    return iree_string_view_match_pattern_impl(
        iree_string_view_substr(value, 1, IREE_STRING_VIEW_NPOS),
        iree_string_view_substr(pattern, 1, IREE_STRING_VIEW_NPOS));
  } else if (pattern_char == '*') {
    return iree_string_view_match_pattern_impl(
               value,
               iree_string_view_substr(pattern, 1, IREE_STRING_VIEW_NPOS)) ||
           iree_string_view_match_pattern_impl(
               iree_string_view_substr(value, 1, IREE_STRING_VIEW_NPOS),
               pattern);
  }
  return false;
}

IREE_API_EXPORT bool iree_string_view_match_pattern(
    iree_string_view_t value, iree_string_view_t pattern) {
  return iree_string_view_match_pattern_impl(value, pattern);
}

IREE_API_EXPORT iree_host_size_t iree_string_view_append_to_buffer(
    iree_string_view_t source_value, iree_string_view_t* target_value,
    char* buffer) {
  memcpy(buffer, source_value.data, source_value.size);
  target_value->data = buffer;
  target_value->size = source_value.size;
  return source_value.size;
}

// NOTE: these implementations aren't great due to the enforced memcpy we
// perform. These _should_ never be on a hot path, though, so this keeps our
// code size small.

IREE_API_EXPORT bool iree_string_view_atoi_int32(iree_string_view_t value,
                                                 int32_t* out_value) {
  // Copy to scratch memory with a NUL terminator.
  char temp[16] = {0};
  if (value.size >= IREE_ARRAYSIZE(temp)) return false;
  memcpy(temp, value.data, value.size);

  // Attempt to parse.
  errno = 0;
  char* end = NULL;
  long parsed_value = strtol(temp, &end, 0);
  if (temp == end) return false;
  if ((parsed_value == LONG_MIN || parsed_value == LONG_MAX) &&
      errno == ERANGE) {
    return false;
  }
  *out_value = (int32_t)parsed_value;
  return parsed_value != 0 || errno == 0;
}

IREE_API_EXPORT bool iree_string_view_atoi_uint32(iree_string_view_t value,
                                                  uint32_t* out_value) {
  // Copy to scratch memory with a NUL terminator.
  char temp[16] = {0};
  if (value.size >= IREE_ARRAYSIZE(temp)) return false;
  memcpy(temp, value.data, value.size);

  // Attempt to parse.
  errno = 0;
  char* end = NULL;
  unsigned long parsed_value = strtoul(temp, &end, 0);
  if (temp == end) return false;
  if (parsed_value == ULONG_MAX && errno == ERANGE) return false;
  *out_value = (uint32_t)parsed_value;
  return parsed_value != 0 || errno == 0;
}

IREE_API_EXPORT bool iree_string_view_atoi_int64(iree_string_view_t value,
                                                 int64_t* out_value) {
  // Copy to scratch memory with a NUL terminator.
  char temp[32] = {0};
  if (value.size >= IREE_ARRAYSIZE(temp)) return false;
  memcpy(temp, value.data, value.size);

  // Attempt to parse.
  errno = 0;
  char* end = NULL;
  long long parsed_value = strtoll(temp, &end, 0);
  if (temp == end) return false;
  if ((parsed_value == LLONG_MIN || parsed_value == LLONG_MAX) &&
      errno == ERANGE) {
    return false;
  }
  *out_value = (int64_t)parsed_value;
  return parsed_value != 0 || errno == 0;
}

IREE_API_EXPORT bool iree_string_view_atoi_uint64(iree_string_view_t value,
                                                  uint64_t* out_value) {
  // Copy to scratch memory with a NUL terminator.
  char temp[32] = {0};
  if (value.size >= IREE_ARRAYSIZE(temp)) return false;
  memcpy(temp, value.data, value.size);

  // Attempt to parse.
  errno = 0;
  char* end = NULL;
  unsigned long long parsed_value = strtoull(temp, &end, 0);
  if (temp == end) return false;
  if (parsed_value == ULLONG_MAX && errno == ERANGE) return false;
  *out_value = (uint64_t)parsed_value;
  return parsed_value != 0 || errno == 0;
}

IREE_API_EXPORT bool iree_string_view_atof(iree_string_view_t value,
                                           float* out_value) {
  // Copy to scratch memory with a NUL terminator.
  char temp[32] = {0};
  if (value.size >= IREE_ARRAYSIZE(temp)) return false;
  memcpy(temp, value.data, value.size);

  // Attempt to parse.
  errno = 0;
  char* end = NULL;
  *out_value = strtof(temp, &end);
  if (temp == end) return false;
  return *out_value != 0 || errno == 0;
}

IREE_API_EXPORT bool iree_string_view_atod(iree_string_view_t value,
                                           double* out_value) {
  // Copy to scratch memory with a NUL terminator.
  char temp[32] = {0};
  if (value.size >= IREE_ARRAYSIZE(temp)) return false;
  memcpy(temp, value.data, value.size);

  // Attempt to parse.
  errno = 0;
  char* end = NULL;
  *out_value = strtod(temp, &end);
  if (temp == end) return false;
  return *out_value != 0 || errno == 0;
}

static bool iree_string_view_parse_hex_nibble(char c, uint8_t* out_b) {
  if ('0' <= c && c <= '9') {
    *out_b = (uint8_t)(c - '0');
    return true;
  } else if ('a' <= c && c <= 'f') {
    *out_b = (uint8_t)(c - 'a' + 10);
    return true;
  } else if ('A' <= c && c <= 'F') {
    *out_b = (uint8_t)(c - 'A' + 10);
    return true;
  }
  return false;
}

IREE_API_EXPORT bool iree_string_view_parse_hex_bytes(
    iree_string_view_t value, iree_host_size_t buffer_length,
    uint8_t* out_buffer) {
  // Strip leading/trailing whitespace.
  value = iree_string_view_trim(value);

  // Try to consume all bytes.
  for (iree_host_size_t i = 0; i < buffer_length; ++i) {
    // Strip interior whitespace/-'s.
    if (i > 0 && value.size) {
      char c = value.data[0];
      if (c == ' ' || c == '-') {
        value = iree_string_view_remove_prefix(value, 1);
      }
    }

    // Ensure there are two nibbles.
    if (value.size < 2) return false;

    // Hex nibbles to byte; fail if invalid characters.
    uint8_t b0 = 0, b1 = 0;
    if (!iree_string_view_parse_hex_nibble(value.data[0], &b0) ||
        !iree_string_view_parse_hex_nibble(value.data[1], &b1)) {
      return false;
    }
    out_buffer[i] = (b0 << 4) + b1;

    // Eat the nibbles.
    value = iree_string_view_remove_prefix(value, 2);
  }

  // Should have consumed all characters.
  return iree_string_view_is_empty(value);
}
