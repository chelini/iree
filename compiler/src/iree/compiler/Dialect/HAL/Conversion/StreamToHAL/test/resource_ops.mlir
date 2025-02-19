// RUN: iree-opt --split-input-file --iree-hal-conversion %s | FileCheck %s

// CHECK-LABEL: @resourceAlloc
func.func @resourceAlloc(%arg0: index, %arg1: index) -> (!stream.resource<transient>, !stream.resource<transient>) {
  // CHECK: %[[RET0:.+]] = hal.allocator.allocate
  // CHECK-SAME: type("DeviceVisible|DeviceLocal")
  // CHECK-SAME: usage("{{.+}}Transfer{{.+}}Dispatch{{.+}}")
  // CHECK-SAME: : !hal.buffer{%arg0}
  // CHECK-NEXT: %[[RET1:.+]] = hal.allocator.allocate
  // CHECK-SAME: type("DeviceVisible|DeviceLocal")
  // CHECK-SAME: usage("{{.+}}Transfer{{.+}}Dispatch{{.+}}")
  // CHECK-SAME: : !hal.buffer{%arg1}
  %0:2 = stream.resource.alloc uninitialized : !stream.resource<transient>{%arg0}, !stream.resource<transient>{%arg1}
  // CHECK: return %[[RET0]], %[[RET1]]
  return %0#0, %0#1 : !stream.resource<transient>, !stream.resource<transient>
}

// -----

// TODO(#9572): implement stream ordered allocations.

// CHECK-LABEL: @resourceAlloca
func.func @resourceAlloca(%arg0: index, %await_timepoint: !stream.timepoint) -> (!stream.resource<staging>, !stream.timepoint) {
  // CHECK: %[[RET0:.+]] = hal.allocator.allocate
  // CHECK-SAME: type("DeviceVisible|DeviceLocal")
  // CHECK-SAME: usage("{{.+}}Transfer{{.+}}Dispatch{{.+}}")
  // CHECK-SAME: : !hal.buffer{%arg0}
  %0:2 = stream.resource.alloca uninitialized : !stream.resource<staging>{%arg0} => !stream.timepoint
  // CHECK: %[[IMMEDIATE:.+]] = arith.constant 0 : index
  // CHECK: return %[[RET0]], %[[IMMEDIATE]]
  return %0#0, %0#1 : !stream.resource<staging>, !stream.timepoint
}

// -----

// TODO(#9572): implement stream ordered allocations.

// CHECK-LABEL: @resourceAllocaAwait
func.func @resourceAllocaAwait(%arg0: index, %await_timepoint: !stream.timepoint) -> (!stream.resource<staging>, !stream.timepoint) {
  // CHECK: %[[RET0:.+]] = hal.allocator.allocate
  // CHECK-SAME: type("DeviceVisible|DeviceLocal")
  // CHECK-SAME: usage("{{.+}}Transfer{{.+}}Dispatch{{.+}}")
  // CHECK-SAME: : !hal.buffer{%arg0}
  %0:2 = stream.resource.alloca uninitialized await(%await_timepoint) => !stream.resource<staging>{%arg0} => !stream.timepoint
  // CHECK: %[[IMMEDIATE:.+]] = arith.constant 0 : index
  // CHECK: return %[[RET0]], %[[IMMEDIATE]]
  return %0#0, %0#1 : !stream.resource<staging>, !stream.timepoint
}

// -----

// TODO(#9572): implement stream ordered allocations.

// CHECK-LABEL: @resourceDealloca
func.func @resourceDealloca(%arg0: index, %arg1: !stream.resource<staging>, %arg2: !stream.timepoint) -> !stream.timepoint {
  %0 = stream.resource.dealloca %arg1 : !stream.resource<staging>{%arg0} => !stream.timepoint
  // CHECK: %[[IMMEDIATE:.+]] = arith.constant 0 : index
  // CHECK: return %[[IMMEDIATE]]
  return %0 : !stream.timepoint
}

// -----

// TODO(#9572): implement stream ordered allocations.

// CHECK-LABEL: @resourceDeallocaAwait
func.func @resourceDeallocaAwait(%arg0: index, %arg1: !stream.resource<staging>, %arg2: !stream.timepoint) -> !stream.timepoint {
  %0 = stream.resource.dealloca await(%arg2) => %arg1 : !stream.resource<staging>{%arg0} => !stream.timepoint
  // CHECK: %[[IMMEDIATE:.+]] = arith.constant 0 : index
  // CHECK: return %[[IMMEDIATE]]
  return %0 : !stream.timepoint
}

// -----

// CHECK-LABEL: @resourceSize
func.func @resourceSize(%arg0: !stream.resource<transient>) -> index {
  // CHECK: %[[SIZE:.+]] = hal.buffer.length<%arg0 : !hal.buffer> : index
  %0 = stream.resource.size %arg0 : !stream.resource<transient>
  // CHECK: return %[[SIZE]]
  return %0 : index
}

// -----

// CHECK-LABEL: @resourceMap
func.func @resourceMap(%arg0: !util.byte_buffer) -> !stream.resource<staging> {
  %c0 = arith.constant 0 : index
  %c128 = arith.constant 128 : index
  // CHECK: %[[MAPPING:.+]] = hal.allocator.allocate.initialized
  // CHECK-SAME: source(%arg0 : !util.byte_buffer)[%c0, %c128]
  // CHECK-SAME: type("HostVisible|HostCoherent|HostLocal|DeviceVisible")
  // CHECK-SAME: usage("{{.+}}Transfer{{.+}}Mapping{{.+}}") : !hal.buffer
  %mapping = stream.resource.map %arg0[%c0] : !util.byte_buffer -> !stream.resource<staging>{%c128}
  // CHECK: return %[[MAPPING]]
  return %mapping : !stream.resource<staging>
}

// -----

// CHECK-LABEL: @resourceTryMap
func.func @resourceTryMap(%arg0: !util.byte_buffer) -> (i1, !stream.resource<constant>) {
  %c0 = arith.constant 0 : index
  %c128 = arith.constant 128 : index
  // CHECK: %[[DID_MAP:.+]], %[[MAPPING:.+]] = hal.allocator.try_map
  // CHECK-SAME: source(%arg0 : !util.byte_buffer)[%c0, %c128]
  // CHECK-SAME: type("DeviceVisible|DeviceLocal")
  // CHECK-SAME: usage("{{.+}}Transfer{{.+}}Dispatch{{.+}}SharingImmutable") : i1, !hal.
  %did_map, %mapping = stream.resource.try_map %arg0[%c0] : !util.byte_buffer -> i1, !stream.resource<constant>{%c128}
  // CHECK: return %[[DID_MAP]], %[[MAPPING]]
  return %did_map, %mapping : i1, !stream.resource<constant>
}

// -----

// CHECK-LABEL: @resourceLoad
func.func @resourceLoad(%arg0: !stream.resource<staging>, %arg1: index) -> i32 {
  %c4 = arith.constant 4 : index
  // CHECK: %[[RET0:.+]] = hal.buffer.load<%arg0 : !hal.buffer>[%c4] : i32
  %0 = stream.resource.load %arg0[%c4] : !stream.resource<staging>{%arg1} -> i32
  // CHECK: return %[[RET0]]
  return %0 : i32
}

// -----

// CHECK-LABEL: @resourceStore
func.func @resourceStore(%arg0: !stream.resource<staging>, %arg1: index) {
  %c4 = arith.constant 4 : index
  %c123_i32 = arith.constant 123 : i32
  // CHECK: hal.buffer.store<%arg0 : !hal.buffer>[%c4] value(%c123_i32 : i32)
  stream.resource.store %c123_i32, %arg0[%c4] : i32 -> !stream.resource<staging>{%arg1}
  return
}

// -----

// CHECK-LABEL: @resourceSubview
func.func @resourceSubview(%arg0: !stream.resource<transient>, %arg1: index) -> !stream.resource<transient> {
  %c128 = arith.constant 128 : index
  %c256 = arith.constant 256 : index
  // CHECK: %[[RET0:.+]] = hal.buffer.subspan<%arg0 : !hal.buffer>[%c128, %c256] : !hal.buffer
  %0 = stream.resource.subview %arg0[%c128] : !stream.resource<transient>{%arg1} -> !stream.resource<transient>{%c256}
  // CHECK: return %[[RET0]]
  return %0 : !stream.resource<transient>
}
