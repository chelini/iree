// RUN: iree-opt -iree-llvmgpu-reduction-to-gpu -cse %s | FileCheck %s

func.func @simple_reduce() {
  %c0 = arith.constant 0 : index
  %cst = arith.constant dense<0.000000e+00> : vector<1xf32>
  %cst_0 = arith.constant 0.000000e+00 : f32
  %cst_1 = arith.constant dense<3.840000e+02> : vector<1xf32>
  %c32 = arith.constant 32 : index
  %c384 = arith.constant 384 : index
  %0 = hal.interface.binding.subspan set(0) binding(0) type(storage_buffer) offset(%c0) alignment(64) : memref<128x384xf32>
  %1 = hal.interface.binding.subspan set(0) binding(1) type(storage_buffer) offset(%c0) alignment(64) : memref<128xf32>
  %workgroup_id_x = hal.interface.workgroup.id[0] : index
  %2 = gpu.thread_id  x
  %3 = affine.apply affine_map<()[s0, s1] -> (s1 * 2 + s0 floordiv 32)>()[%2, %workgroup_id_x]
  %4 = scf.for %arg0 = %c0 to %c384 step %c32 iter_args(%arg1 = %cst) -> (vector<1xf32>) {
    %6 = vector.transfer_read %0[%3, %arg0], %cst_0 {in_bounds = [true]} : memref<128x384xf32>, vector<32xf32>
    %7 = vector.broadcast %6 : vector<32xf32> to vector<1x32xf32>
    %8 = vector.multi_reduction <add>, %7 [1] : vector<1x32xf32> to vector<1xf32>
    %9 = arith.addf %8, %arg1 : vector<1xf32>
    scf.yield %9 : vector<1xf32>
  }
  %5 = arith.divf %4, %cst_1 : vector<1xf32>
  vector.transfer_write %5, %1[%3] {in_bounds = [true]} : vector<1xf32>, memref<128xf32>
  return
}

// CHECK-LABEL: func.func @simple_reduce() {
//   CHECK-DAG:   %[[C0:.*]] = arith.constant 0 : index
//   CHECK-DAG:   %[[C1:.*]] = arith.constant 1 : i32
//   CHECK-DAG:   %[[C2:.*]] = arith.constant 2 : i32
//   CHECK-DAG:   %[[C4:.*]] = arith.constant 4 : i32
//   CHECK-DAG:   %[[C8:.*]] = arith.constant 8 : i32
//   CHECK-DAG:   %[[C16:.*]] = arith.constant 16 : i32
//   CHECK-DAG:   %[[C32:.*]] = arith.constant 32 : i32
//   CHECK-DAG:   %[[C32I:.*]] = arith.constant 32 : index
//   CHECK-DAG:   %[[TID:.*]] = gpu.thread_id  x
//   CHECK-DAG:   %[[LID:.*]] = arith.remui %[[TID]], %[[C32I]] : index
//   CHECK-DAG:   %[[VCST:.*]] = arith.constant dense<0.000000e+00> : vector<1xf32>
//       CHECK:   %[[F:.*]] = scf.for %{{.*}} = %{{.*}} to %{{.*}} step %{{.*}} iter_args(%[[V0:.*]] = %[[VCST]]) -> (vector<1xf32>) {
//       CHECK:     %[[ID:.*]] = affine.apply
//       CHECK:     %[[V1:.*]] = vector.transfer_read %{{.*}}[%{{.*}}, %[[ID]]], %{{.*}} {in_bounds = [true]} : memref<128x384xf32>, vector<1xf32>
//       CHECK:     %[[S:.*]] = vector.extract %[[V1]][0] : vector<1xf32>
//       CHECK:     %[[S0:.*]], %{{.*}} = gpu.shuffle  xor %[[S]], %[[C1]], %[[C32]] : f32
//       CHECK:     %[[S1:.*]] = arith.addf %[[S]], %[[S0]] : f32
//       CHECK:     %[[S2:.*]], %{{.*}} = gpu.shuffle  xor %[[S1]], %[[C2]], %[[C32]] : f32
//       CHECK:     %[[S3:.*]] = arith.addf %[[S1]], %[[S2]] : f32
//       CHECK:     %[[S4:.*]], %{{.*}} = gpu.shuffle  xor %[[S3]], %[[C4]], %[[C32]] : f32
//       CHECK:     %[[S5:.*]] = arith.addf %[[S3]], %[[S4]] : f32
//       CHECK:     %[[S6:.*]], %{{.*}} = gpu.shuffle  xor %[[S5]], %[[C8]], %[[C32]] : f32
//       CHECK:     %[[S7:.*]] = arith.addf %[[S5]], %[[S6]] : f32
//       CHECK:     %[[S8:.*]], %{{.*}} = gpu.shuffle  xor %[[S7]], %[[C16]], %[[C32]] : f32
//       CHECK:     %[[S9:.*]] = arith.addf %[[S7]], %[[S8]] : f32
//       CHECK:     %[[B:.*]] = vector.broadcast %[[S9]] : f32 to vector<1xf32>
//       CHECK:     %[[ADD:.*]] = arith.addf %[[B]], %[[V0]] : vector<1xf32>
//       CHECK:     scf.yield %[[ADD]] : vector<1xf32>
//       CHECK:   }
//       CHECK:   %[[DIV:.*]] = arith.divf %[[F]], %{{.*}} : vector<1xf32>
//       CHECK:   %[[CMP:.*]] = arith.cmpi eq, %[[LID]], %[[C0]] : index
//       CHECK:   scf.if %[[CMP]] {
//       CHECK:     vector.transfer_write %[[DIV]], {{.*}} : vector<1xf32>, memref<128xf32>
//       CHECK:   }
//       CHECK:   return