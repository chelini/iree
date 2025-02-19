// RUN: iree-opt --split-input-file --verify-diagnostics --iree-flow-enable-multi-result-dispatches --pass-pipeline="func.func(iree-flow-dispatch-linalg-on-tensors-pass)" --canonicalize -cse %s | FileCheck %s

func.func @fuse_conv2d_elementwise(%input: tensor<1x225x225x16xf32>, %filter: tensor<3x3x16x32xf32>, %offset: tensor<32xf32>) -> tensor<1x112x112x32xf32> {
  %cst = arith.constant 0.000000e+00 : f32
  %0 = linalg.init_tensor [1, 112, 112, 32] : tensor<1x112x112x32xf32>
  %1 = linalg.fill ins(%cst : f32) outs(%0 : tensor<1x112x112x32xf32>) -> tensor<1x112x112x32xf32>
  %2 = linalg.conv_2d_nhwc_hwcf
         {dilations = dense<1> : tensor<2xi64>, strides = dense<2> : tensor<2xi64>}
         ins(%input, %filter : tensor<1x225x225x16xf32>, tensor<3x3x16x32xf32>)
         outs(%1 : tensor<1x112x112x32xf32>)
         -> tensor<1x112x112x32xf32>
  %3 = linalg.generic {
         indexing_maps = [
           affine_map<(d0, d1, d2, d3) -> (d0, d1, d2, d3)>,
           affine_map<(d0, d1, d2, d3) -> (d3)>,
           affine_map<(d0, d1, d2, d3) -> (d0, d1, d2, d3)>],
         iterator_types = ["parallel", "parallel", "parallel", "parallel"]}
         ins(%2, %offset: tensor<1x112x112x32xf32>, tensor<32xf32>)
         outs(%0 : tensor<1x112x112x32xf32>) {
         ^bb0(%a: f32, %b: f32, %c: f32):
            %sub = arith.subf %a, %b : f32
            linalg.yield %sub : f32
         } -> tensor<1x112x112x32xf32>
  return %3 : tensor<1x112x112x32xf32>
}

// Check that
// * linalg.conv is fused together with linalg.generic;
// * linalg.generic's linalg.fill is pulled into the same group;
// * linalg.conv's linalg.fill is pulled into the same group.

// CHECK-LABEL: func.func @fuse_conv2d_elementwise

//      CHECK: flow.dispatch.workgroups
//      CHECK:   %[[INIT:.+]] = linalg.init_tensor
//      CHECK:   %[[FILL:.+]] = linalg.fill
// CHECK-SAME:     outs(%[[INIT]] :
//      CHECK:   %[[CONV:.+]] = linalg.conv_2d_nhwc_hwcf
// CHECK-SAME:     outs(%[[FILL]] :
//      CHECK:   linalg.generic
// CHECK-SAME:     ins(%[[CONV]], %{{.+}} : tensor<1x112x112x32xf32>, tensor<32xf32>)
// CHECK-SAME:     outs(%[[INIT]] : tensor<1x112x112x32xf32>)

// -----

func.func @fuse_conv2d_with_multiple_uses(%input: tensor<1x225x225x16xf32>, %filter: tensor<3x3x16x32xf32>, %offset: tensor<32xf32>)
  -> (tensor<1x112x112x32xf32>, tensor<1x112x112x32xf32>) {
  %cst = arith.constant 0.000000e+00 : f32
  %0 = linalg.init_tensor [1, 112, 112, 32] : tensor<1x112x112x32xf32>
  %1 = linalg.fill ins(%cst : f32) outs(%0 : tensor<1x112x112x32xf32>) -> tensor<1x112x112x32xf32>
  %2 = linalg.conv_2d_nhwc_hwcf
         {dilations = dense<1> : tensor<2xi64>, strides = dense<2> : tensor<2xi64>}
         ins(%input, %filter : tensor<1x225x225x16xf32>, tensor<3x3x16x32xf32>)
         outs(%1 : tensor<1x112x112x32xf32>)
         -> tensor<1x112x112x32xf32>
  %3 = linalg.generic {
         indexing_maps = [
           affine_map<(d0, d1, d2, d3) -> (d0, d1, d2, d3)>,
           affine_map<(d0, d1, d2, d3) -> (d3)>,
           affine_map<(d0, d1, d2, d3) -> (d0, d1, d2, d3)>],
         iterator_types = ["parallel", "parallel", "parallel", "parallel"]}
         ins(%2, %offset: tensor<1x112x112x32xf32>, tensor<32xf32>)
         outs(%1 : tensor<1x112x112x32xf32>) {
         ^bb0(%a: f32, %b: f32, %c: f32):
            %sub = arith.subf %a, %b : f32
            linalg.yield %sub : f32
         } -> tensor<1x112x112x32xf32>
  return %3, %2 : tensor<1x112x112x32xf32>, tensor<1x112x112x32xf32>
}

// CHECK-LABEL: func.func @fuse_conv2d_with_multiple_uses
//       CHECK:   %[[DISPATCH:.+]]:2 = flow.dispatch.workgroups
//  CHECK-NEXT:       %[[OUT1:[a-zA-Z0-9]+]]: !flow.dispatch.tensor<writeonly:1x112x112x32xf32>
//  CHECK-SAME:       %[[OUT2:.+]]: !flow.dispatch.tensor<writeonly:1x112x112x32xf32>
//       CHECK:     %[[CONV:.+]] = linalg.conv_2d_nhwc_hwcf
//       CHECK:     %[[GENERIC:.+]] = linalg.generic
//   CHECK-DAG:     flow.dispatch.tensor.store %[[GENERIC]], %[[OUT1]]
//   CHECK-DAG:     flow.dispatch.tensor.store %[[CONV]], %[[OUT2]]
//       CHECK:   return %[[DISPATCH]]#0, %[[DISPATCH]]#1

// -----

func.func @dont_fuse_conv2d_with_non_identity_map(%input: tensor<1x225x225x16xf32>, %filter: tensor<3x3x16x32xf32>, %offset: tensor<32xf32>) -> tensor<1x112x112x32xf32> {
  %cst = arith.constant 0.000000e+00 : f32
  %0 = linalg.init_tensor [1, 112, 112, 32] : tensor<1x112x112x32xf32>
  %1 = linalg.fill ins(%cst : f32) outs(%0 : tensor<1x112x112x32xf32>) -> tensor<1x112x112x32xf32>
  %2 = linalg.conv_2d_nhwc_hwcf
         {dilations = dense<1> : tensor<2xi64>, strides = dense<2> : tensor<2xi64>}
         ins(%input, %filter : tensor<1x225x225x16xf32>, tensor<3x3x16x32xf32>)
         outs(%1 : tensor<1x112x112x32xf32>)
         -> tensor<1x112x112x32xf32>
  %3 = linalg.generic {
         indexing_maps = [
           affine_map<(d0, d1, d2, d3) -> (d0, d2, d1, d3)>,
           affine_map<(d0, d1, d2, d3) -> (d3)>,
           affine_map<(d0, d1, d2, d3) -> (d0, d1, d2, d3)>],
         iterator_types = ["parallel", "parallel", "parallel", "parallel"]}
         ins(%2, %offset: tensor<1x112x112x32xf32>, tensor<32xf32>)
         outs(%1 : tensor<1x112x112x32xf32>) {
         ^bb0(%a: f32, %b: f32, %c: f32):
            %sub = arith.subf %a, %b : f32
            linalg.yield %sub : f32
         } -> tensor<1x112x112x32xf32>
  return %3 : tensor<1x112x112x32xf32>
}

// CHECK-LABEL: func.func @dont_fuse_conv2d_with_non_identity_map

// CHECK: flow.dispatch.workgroups
// CHECK:   linalg.conv_2d_nhwc_hwcf

// CHECK: flow.dispatch.workgroups
// CHECK:   linalg.generic
